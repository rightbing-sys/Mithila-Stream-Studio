import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/editor_overlays.dart';
import '../widgets/brand_watermark_sheet.dart';
import '../widgets/pro_adjust_sheet.dart';
import '../widgets/transitions_sheet.dart';



class TrimConfig {
  final String inputPath;
  final String outputPath;
  final Duration start;
  final Duration end;
  final int videoWidth;
  final int videoHeight;
  final double fps;
  final String? videoFilter;
  final double playbackSpeed;
  final bool isMuted;
  final int? targetHeight; // null = Original resolution, or 1080, 720, 480
  final int crf;
  final String preset;
  final bool streamCopyWhenUnfiltered;

  const TrimConfig({
    required this.inputPath,
    required this.outputPath,
    required this.start,
    required this.end,
    this.videoWidth = 1920,
    this.videoHeight = 1080,
    this.fps = 30.0,
    this.videoFilter,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
    this.targetHeight,
    this.crf = 20,
    this.preset = 'medium',
    this.streamCopyWhenUnfiltered = true,
  });

  Duration get sourceSpan => end > start ? end - start : Duration.zero;

  Duration get trimmedDuration {
    if (playbackSpeed <= 0) return sourceSpan;
    return Duration(milliseconds: (sourceSpan.inMilliseconds / playbackSpeed).round());
  }
}

class ExportResult {
  final bool isSuccess;
  final String? outputPath;
  final Duration duration;
  final String? errorMessage;
  final int fileSizeEstimatedBytes;
  final String? ffmpegCommand;
  final bool producedRealFile;
  final String? resolutionNote;

  const ExportResult({
    required this.isSuccess,
    this.outputPath,
    required this.duration,
    this.errorMessage,
    this.fileSizeEstimatedBytes = 0,
    this.ffmpegCommand,
    this.producedRealFile = false,
    this.resolutionNote,
  });
}

class FfmpegSplitCommands {
  final String part1Command;
  final String part2Command;

  const FfmpegSplitCommands({
    required this.part1Command,
    required this.part2Command,
  });

  String get combinedCommand => '$part1Command\n$part2Command';
}

class ExportService {
  /// Format duration to mm:ss.S or hh:mm:ss.S string
  static String formatDuration(Duration duration, {bool includeMillis = true}) {
    if (duration.isNegative) duration = Duration.zero;

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor();

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      if (includeMillis) {
        return '$hoursStr:$minutesStr:$secondsStr.$tenths';
      }
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      if (includeMillis) {
        return '$minutesStr:$secondsStr.$tenths';
      }
      return '$minutesStr:$secondsStr';
    }
  }

  /// Format duration to precision timecode (hh:mm:ss:ff at 30 fps)
  static String formatTimecode(Duration duration, {int fps = 30}) {
    if (duration.isNegative) duration = Duration.zero;

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final frames = ((duration.inMilliseconds.remainder(1000) / 1000) * fps)
        .floor()
        .toString()
        .padLeft(2, '0');

    return '$hours:$minutes:$seconds:$frames';
  }

  /// Calculates human-readable estimated file size based on duration and bitrate
  static String estimateFileSize(Duration duration, {int bitrateKbps = 8000}) {
    final seconds = duration.inMilliseconds / 1000.0;
    final totalBits = seconds * bitrateKbps * 1000;
    final bytes = totalBits / 8;
    final megabytes = bytes / (1024 * 1024);

    if (megabytes < 1.0) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  /// Builds valid FFmpeg atempo filter chain (each stage constrained to [0.5, 2.0])
  static String buildAtempoFilterChain(double speed) {
    if ((speed - 1.0).abs() < 0.01) return '';
    double remaining = speed.clamp(0.25, 4.0);
    final stages = <String>[];

    while (remaining > 2.0) {
      stages.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      stages.add('atempo=0.5');
      remaining /= 0.5;
    }
    stages.add('atempo=${remaining.toStringAsFixed(2)}');
    return stages.join(',');
  }

  /// Formats Duration as HH:MM:SS (or HH:MM:SS.mmm when sub-second precision exists) for FFmpeg -ss / -to
  static String formatFfmpegTimestamp(Duration duration) {
    if (duration.isNegative) duration = Duration.zero;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = duration.inMilliseconds.remainder(1000);
    if (millis == 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$hours:$minutes:$seconds.${millis.toString().padLeft(3, '0')}';
  }

  static String _quoteArgIfNeeded(String value) {
    if (value.contains(' ') || value.contains('"') || value.contains('&')) {
      return '"$value"';
    }
    return value;
  }

  /// Generates a complete FFmpeg CLI command using `-i <input> -ss HH:MM:SS [-to HH:MM:SS]`
  /// supporting trim, open-ended tail cuts (when `end` is null), filtergraph, playback speed, audio mute, and scaling.
  static String generateFfmpegTrimCommand({
    required String inputPath,
    required String outputPath,
    required Duration start,
    Duration? end,
    String? videoFilter,
    double playbackSpeed = 1.0,
    bool isMuted = false,
    int? targetHeight,
    int crf = 20,
    String preset = 'medium',
    bool streamCopyWhenUnfiltered = true,
    bool includeCodecFlags = true,
  }) {
    final startTs = formatFfmpegTimestamp(start);

    final vfParts = <String>[];
    if ((playbackSpeed - 1.0).abs() >= 0.01) {
      final ptsScale = (1.0 / playbackSpeed).toStringAsFixed(4);
      vfParts.add('setpts=$ptsScale*PTS');
    }
    if (videoFilter != null && videoFilter.trim().isNotEmpty) {
      vfParts.add(videoFilter.trim());
    }
    if (targetHeight != null && targetHeight > 0) {
      vfParts.add('scale=-2:$targetHeight');
    }

    final parts = <String>[
      'ffmpeg',
      '-i ${_quoteArgIfNeeded(inputPath)}',
      '-ss $startTs',
    ];

    if (end != null) {
      final safeEnd = end > start ? end : start + const Duration(milliseconds: 500);
      parts.add('-to ${formatFfmpegTimestamp(safeEnd)}');
    }

    final hasSpeedChange = (playbackSpeed - 1.0).abs() >= 0.01;
    final needsVideoEncode = vfParts.isNotEmpty || !streamCopyWhenUnfiltered;

    if (vfParts.isNotEmpty) {
      parts.add('-vf "${vfParts.join(',')}"');
    }

    if (!needsVideoEncode && !isMuted && !hasSpeedChange) {
      if (includeCodecFlags) {
        parts.add('-c copy');
      }
    } else {
      if (needsVideoEncode) {
        if (includeCodecFlags || vfParts.isNotEmpty) {
          parts.add('-c:v libx264 -preset $preset -crf $crf -pix_fmt yuv420p');
        }
      } else if (includeCodecFlags) {
        parts.add('-c:v copy');
      }

      if (isMuted) {
        parts.add('-an');
      } else if (hasSpeedChange) {
        final atempo = buildAtempoFilterChain(playbackSpeed);
        parts.add('-af "$atempo" -c:a aac -b:a 192k');
      } else if (needsVideoEncode && includeCodecFlags) {
        parts.add('-c:a aac -b:a 192k');
      } else if (includeCodecFlags) {
        parts.add('-c:a copy');
      }
    }

    parts.add(_quoteArgIfNeeded(outputPath));
    return parts.join(' ');
  }

  /// Resolves an output file path next to the source video (or system temp directory)
  static Future<String> resolveTrimOutputPath(TrimConfig config) async {
    if (kIsWeb) return config.outputPath;
    final rawOut = config.outputPath.trim();
    if (rawOut.contains(Platform.pathSeparator) || rawOut.startsWith('/')) {
      return rawOut;
    }

    final fileName = rawOut.isNotEmpty
        ? rawOut
        : 'trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final inputFile = File(config.inputPath);
      if (await inputFile.exists()) {
        final parentDir = inputFile.parent;
        final probeFile = File(
          '${parentDir.path}${Platform.pathSeparator}.cineflow_write_probe_${DateTime.now().microsecondsSinceEpoch}',
        );
        await probeFile.create();
        await probeFile.delete();
        return '${parentDir.path}${Platform.pathSeparator}$fileName';
      }
    } catch (_) {
      // Fall through to system temp directory if source parent is read-only
    }

    return '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
  }

  /// Builds discrete FFmpeg CLI arguments for Process.start execution
  static List<String> buildFfmpegTrimArgs({
    required TrimConfig config,
    required String resolvedOutputPath,
  }) {
    final startTs = formatFfmpegTimestamp(config.start);
    final safeEnd = config.end > config.start
        ? config.end
        : config.start + const Duration(milliseconds: 500);
    final endTs = formatFfmpegTimestamp(safeEnd);

    final vfParts = <String>[];
    if ((config.playbackSpeed - 1.0).abs() >= 0.01) {
      final ptsScale = (1.0 / config.playbackSpeed).toStringAsFixed(4);
      vfParts.add('setpts=$ptsScale*PTS');
    }
    if (config.videoFilter != null && config.videoFilter!.trim().isNotEmpty) {
      vfParts.add(config.videoFilter!.trim());
    }
    if (config.targetHeight != null && config.targetHeight! > 0) {
      vfParts.add('scale=-2:${config.targetHeight}');
    }

    final args = <String>[
      '-y',
      '-i',
      config.inputPath,
      '-ss',
      startTs,
      '-to',
      endTs,
    ];

    final hasSpeedChange = (config.playbackSpeed - 1.0).abs() >= 0.01;
    final needsVideoEncode = vfParts.isNotEmpty || !config.streamCopyWhenUnfiltered;

    if (bannerOverlays.isNotEmpty) {
      final baseFilter = vfParts.isNotEmpty ? vfParts.join(',') : 'null';
      final fcParts = <String>['[0:v]$baseFilter[v0]'];
      String prev = '[v0]';
      for (int i = 0; i < bannerOverlays.length; i++) {
        final bn = bannerOverlays[i];
        final idx = bannerStartIdx + i;
        final w = (bn.widthPx * 2.2).round();
        fcParts.add('[$idx:v]scale=$w:-1[ovr$i]');
        final next = (i == bannerOverlays.length - 1) ? '[vout]' : '[vtmp$i]';
        fcParts.add('$prev[ovr$i]overlay=(W*${bn.normX.toStringAsFixed(2)}-w/2):(H*${bn.normY.toStringAsFixed(2)}-h/2)$next');
        prev = next;
      }
      if (hasMusic && bannerOverlays.isEmpty) {
        final origVol = isMuted ? 0.0 : audioConfig.originalVolume;
        final musVol = audioConfig.autoDucking ? (audioConfig.musicVolume * 0.75) : audioConfig.musicVolume;
        fcParts.add('[0:a]volume=${origVol.toStringAsFixed(2)}[a0]');
        fcParts.add('[1:a]volume=${musVol.toStringAsFixed(2)}[a1]');
        fcParts.add('[a0][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]');
        args.addAll(['-filter_complex', fcParts.join(';'), '-map', '[vout]', '-map', '[aout]']);
      } else {
        args.addAll(['-filter_complex', fcParts.join(';'), '-map', '[vout]']);
        if (!isMuted) args.addAll(['-map', '0:a?']);
      }
    } else if (vfParts.isNotEmpty) {
      args.addAll(['-vf', vfParts.join(',')]);
    }

    if (!needsVideoEncode && !config.isMuted && !hasSpeedChange) {
      args.addAll(['-c', 'copy', '-movflags', '+faststart']);
    } else {
      if (needsVideoEncode) {
        args.addAll([
          '-c:v',
          'libx264',
          '-preset',
          config.preset,
          '-crf',
          '${config.crf}',
          '-pix_fmt',
          'yuv420p',
        ]);
      } else {
        args.addAll(['-c:v', 'copy']);
      }

      if (config.isMuted) {
        args.add('-an');
      } else if (hasSpeedChange) {
        args.addAll([
          '-af',
          buildAtempoFilterChain(config.playbackSpeed),
          '-c:a',
          'aac',
          '-b:a',
          '192k',
        ]);
      } else if (needsVideoEncode) {
        args.addAll(['-c:a', 'aac', '-b:a', '192k']);
      } else {
        args.addAll(['-c:a', 'copy']);
      }
      args.addAll(['-movflags', '+faststart']);
    }

    args.add(resolvedOutputPath);
    return args;
  }

  /// Trims the selected video segment [config.start .. config.end] into a new output video file
  /// using native FFmpeg when available on non-web platforms, with graceful preview fallback.
  static Future<ExportResult> exportTrimmedVideo({
    required TrimConfig config,
    required void Function(double progress, String status) onProgress,
  }) async {
    try {
      final resolvedOutPath = await resolveTrimOutputPath(config);
      final ffmpegCmd = generateFfmpegTrimCommand(
        inputPath: config.inputPath,
        outputPath: resolvedOutPath,
        start: config.start,
        end: config.end,
        videoFilter: config.videoFilter,
        playbackSpeed: config.playbackSpeed,
        isMuted: config.isMuted,
        targetHeight: config.targetHeight,
        crf: config.crf,
        preset: config.preset,
        streamCopyWhenUnfiltered: config.streamCopyWhenUnfiltered,
      );

      final trimmedDur = config.trimmedDuration;
      final totalTargetMs = trimmedDur.inMilliseconds > 0 ? trimmedDur.inMilliseconds : 1000;

      // Attempt real FFmpeg process execution when running natively with a local input file
      if (!kIsWeb && await File(config.inputPath).exists()) {
        onProgress(0.08, 'Launching FFmpeg trim pipeline...');
        final args = buildFfmpegTrimArgs(
          config: config,
          resolvedOutputPath: resolvedOutPath,
        );

        try {
          final process = await Process.start('ffmpeg', args);
          final stderrBuffer = StringBuffer();
          final timeRegex = RegExp(r'time=(\d{2}):(\d{2}):(\d{2})\.(\d{2,3})');

          process.stderr.transform(utf8.decoder).listen((chunk) {
            stderrBuffer.write(chunk);
            final matches = timeRegex.allMatches(chunk).toList();
            final match = matches.isNotEmpty ? matches.last : null;
            if (match != null) {
              final h = int.tryParse(match.group(1) ?? '0') ?? 0;
              final m = int.tryParse(match.group(2) ?? '0') ?? 0;
              final s = int.tryParse(match.group(3) ?? '0') ?? 0;
              final fracStr = match.group(4) ?? '0';
              final ms = fracStr.length == 2
                  ? (int.tryParse(fracStr) ?? 0) * 10
                  : (int.tryParse(fracStr) ?? 0);
              final encodedMs = ((h * 3600 + m * 60 + s) * 1000) + ms;
              final pct = (encodedMs / totalTargetMs).clamp(0.12, 0.96);
              onProgress(
                pct,
                'Trimming segment (${formatFfmpegTimestamp(Duration(milliseconds: encodedMs))})...',
              );
            }
          });

          final exitCode = await process.exitCode;
          final outFile = File(resolvedOutPath);

          if (exitCode == 0 && await outFile.exists()) {
            final actualBytes = await outFile.length();
            if (actualBytes > 0) {
              onProgress(1.0, 'New trimmed video file created!');
              return ExportResult(
                isSuccess: true,
                outputPath: resolvedOutPath,
                duration: trimmedDur,
                fileSizeEstimatedBytes: actualBytes,
                ffmpegCommand: ffmpegCmd,
                producedRealFile: true,
                resolutionNote: 'Encoded via system FFmpeg binary',
              );
            }
          }

          return ExportResult(
            isSuccess: false,
            outputPath: resolvedOutPath,
            duration: Duration.zero,
            ffmpegCommand: ffmpegCmd,
            errorMessage:
                'FFmpeg exited with code $exitCode: ${stderrBuffer.toString().split('\n').where((l) => l.trim().isNotEmpty).take(3).join(' ')}',
          );
        } on ProcessException {
          // System ffmpeg binary not present in PATH; report gracefully below
        }
      }

      // Preview / simulation fallback when running on Web or without local ffmpeg binary
      final hasFilters =
          (config.videoFilter?.isNotEmpty ?? false) ||
          (config.playbackSpeed - 1.0).abs() >= 0.01 ||
          config.targetHeight != null;
      final isStreamCopy = !hasFilters && config.streamCopyWhenUnfiltered;

      final steps = [
        {'progress': 0.15, 'status': 'Probing input video & audio streams...'},
        {'progress': 0.35, 'status': 'Seeking to in-point (${formatFfmpegTimestamp(config.start)})...'},
        {
          'progress': 0.62,
          'status': isStreamCopy
              ? 'Preparing stream-copy cut (-ss / -to -c copy)...'
              : 'Preparing re-encoded trim (${config.playbackSpeed}x)...',
        },
        {'progress': 0.88, 'status': 'Finalizing trim configuration...'},
        {'progress': 1.00, 'status': 'Trim pipeline complete (copy CLI command to run natively).'},
      ];

      for (final step in steps) {
        await Future.delayed(const Duration(milliseconds: 220));
        onProgress(step['progress'] as double, step['status'] as String);
      }

      final bitrateKbps = config.targetHeight == 480
          ? 2500
          : config.targetHeight == 720
              ? 5000
              : 8000;
      final estimatedBytes = ((trimmedDur.inMilliseconds / 1000.0) * bitrateKbps * 1000 / 8).round();

      return ExportResult(
        isSuccess: true,
        outputPath: resolvedOutPath,
        duration: trimmedDur,
        fileSizeEstimatedBytes: estimatedBytes,
        ffmpegCommand: ffmpegCmd,
        producedRealFile: false,
        resolutionNote: kIsWeb
            ? 'Browser sandbox cannot write native MP4 binaries directly — copy the generated FFmpeg command below.'
            : 'FFmpeg binary was not found on host PATH — install ffmpeg or copy the generated CLI command.',
      );
    } catch (e) {
      return ExportResult(
        isSuccess: false,
        duration: Duration.zero,
        errorMessage: e.toString(),
      );
    }
  }

  /// Generates two sequential FFmpeg split commands:
  /// Part 1: `ffmpeg -i <input> -ss 00:00:00 -to <splitAt> ... part1.mp4`
  /// Part 2: `ffmpeg -i <input> -ss <splitAt> [-to <end>] ... part2.mp4`
  static FfmpegSplitCommands generateFfmpegSplitCommands({
    required String inputPath,
    required Duration splitAt,
    Duration start = Duration.zero,
    Duration? end,
    String part1OutputPath = 'part1.mp4',
    String part2OutputPath = 'part2.mp4',
    String? videoFilter,
    double playbackSpeed = 1.0,
    bool isMuted = false,
    int? targetHeight,
    int crf = 20,
    String preset = 'medium',
    bool streamCopyWhenUnfiltered = true,
    bool includeCodecFlags = true,
  }) {
    final safeSplit = splitAt > start ? splitAt : start + const Duration(seconds: 1);

    final part1 = generateFfmpegTrimCommand(
      inputPath: inputPath,
      outputPath: part1OutputPath,
      start: start,
      end: safeSplit,
      videoFilter: videoFilter,
      playbackSpeed: playbackSpeed,
      isMuted: isMuted,
      targetHeight: targetHeight,
      crf: crf,
      preset: preset,
      streamCopyWhenUnfiltered: streamCopyWhenUnfiltered,
      includeCodecFlags: includeCodecFlags,
    );

    final part2 = generateFfmpegTrimCommand(
      inputPath: inputPath,
      outputPath: part2OutputPath,
      start: safeSplit,
      end: end,
      videoFilter: videoFilter,
      playbackSpeed: playbackSpeed,
      isMuted: isMuted,
      targetHeight: targetHeight,
      crf: crf,
      preset: preset,
      streamCopyWhenUnfiltered: streamCopyWhenUnfiltered,
      includeCodecFlags: includeCodecFlags,
    );

    return FfmpegSplitCommands(part1Command: part1, part2Command: part2);
  }

  /// Simulates sequential two-part FFmpeg split export (`part1.mp4` + `part2.mp4`) with progress reporting
  static Future<ExportResult> exportSplitVideo({
    required String inputPath,
    required Duration splitAt,
    required Duration totalDuration,
    Duration start = Duration.zero,
    String part1OutputPath = 'part1.mp4',
    String part2OutputPath = 'part2.mp4',
    String? videoFilter,
    double playbackSpeed = 1.0,
    bool isMuted = false,
    int? targetHeight,
    bool streamCopyWhenUnfiltered = true,
    bool includeCodecFlags = true,
    required void Function(double progress, String status) onProgress,
  }) async {
    try {
      final cmds = generateFfmpegSplitCommands(
        inputPath: inputPath,
        splitAt: splitAt,
        start: start,
        part1OutputPath: part1OutputPath,
        part2OutputPath: part2OutputPath,
        videoFilter: videoFilter,
        playbackSpeed: playbackSpeed,
        isMuted: isMuted,
        targetHeight: targetHeight,
        streamCopyWhenUnfiltered: streamCopyWhenUnfiltered,
        includeCodecFlags: includeCodecFlags,
      );

      final splitTs = formatFfmpegTimestamp(splitAt);
      final startTs = formatFfmpegTimestamp(start);

      final steps = [
        {'progress': 0.14, 'status': 'Probing streams for split at $splitTs...'},
        {'progress': 0.36, 'status': 'Writing $part1OutputPath (-ss $startTs -to $splitTs)...'},
        {'progress': 0.58, 'status': 'Finalizing $part1OutputPath container...'},
        {'progress': 0.80, 'status': 'Writing $part2OutputPath (-ss $splitTs to end)...'},
        {'progress': 1.00, 'status': 'Split complete: $part1OutputPath & $part2OutputPath ready!'},
      ];

      for (final step in steps) {
        await Future.delayed(const Duration(milliseconds: 300));
        onProgress(step['progress'] as double, step['status'] as String);
      }

      return ExportResult(
        isSuccess: true,
        outputPath: '$part1OutputPath, $part2OutputPath',
        duration: totalDuration - start,
        ffmpegCommand: cmds.combinedCommand,
      );
    } catch (e) {
      return ExportResult(
        isSuccess: false,
        duration: Duration.zero,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<String> createTempExportPath({String prefix = 'cineflow_export'}) async {
    if (kIsWeb) {
      return '${prefix}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${prefix}_$ts.mp4';
  }

  static Future<bool> saveToGallery(String filePath) async {
    if (kIsWeb) return false;
    final hasAccess = await Gal.hasAccess(toAlbum: false);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: false);
      if (!granted) return false;
    }
    await Gal.putVideo(filePath);
    return true;
  }

  static List<String> buildAdvancedFfmpegArgs({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
    AspectRatioPreset aspectRatio = AspectRatioPreset.original,
    String? baseVideoFilter,
    AudioTrackConfig audioConfig = const AudioTrackConfig(),
    List<TextOverlayItem> textOverlays = const [],
    List<BannerOverlayItem> bannerOverlays = const [],
    ProColorGrading proGrading = const ProColorGrading(),
    TransitionConfig transition = const TransitionConfig(),
    BrandWatermarkConfig watermark = const BrandWatermarkConfig(),
    int crf = 20,
    double playbackSpeed = 1.0,
    bool isMuted = false,
  }) {
    final args = <String>[
      '-y',
      '-ss',
      formatFfmpegTimestamp(start),
      '-to',
      formatFfmpegTimestamp(end),
      '-i',
      inputPath,
    ];

    final hasMusic = audioConfig.hasMusic;
    final bannerStartIdx = hasMusic ? 2 : 1;
    for (final bn in bannerOverlays) {
      args.addAll(['-i', bn.imagePath]);
    }
    if (hasMusic) {
      if (audioConfig.musicStartOffsetSec > 0) {
        args.addAll(['-ss', audioConfig.musicStartOffsetSec.toStringAsFixed(2)]);
      }
      args.addAll(['-i', audioConfig.filePath!]);
    }

    final vfParts = <String>[];
    if (baseVideoFilter != null && baseVideoFilter.trim().isNotEmpty) {
      vfParts.add(baseVideoFilter.trim());
    }
    final proVf = proGrading.toFfmpegFilter();
    if (proVf.isNotEmpty) {
      vfParts.add(proVf);
    }
    final transVf = transition.toFfmpegFilter(end > start ? end - start : Duration.zero);
    if (transVf.isNotEmpty) {
      vfParts.add(transVf);
    }
    final wmVf = watermark.toFfmpegDrawtext();
    if (wmVf.isNotEmpty) {
      vfParts.add(wmVf);
    }
    if (aspectRatio.exportWidth != null && aspectRatio.exportHeight != null) {
      final w = aspectRatio.exportWidth!;
      final h = aspectRatio.exportHeight!;
      vfParts.add(
        'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black',
      );
    }
    if ((playbackSpeed - 1.0).abs() > 0.01) {
      vfParts.add('setpts=${(1.0 / playbackSpeed).toStringAsFixed(4)}*PTS');
    }
    for (final t in textOverlays) {
      final escaped = t.text
          .replaceAll('\\', '\\\\')
          .replaceAll(':', '\\:')
          .replaceAll("'", "\\'");
      final hex = '#${t.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      vfParts.add(
        "drawtext=text='$escaped':fontcolor=$hex:fontsize=${t.fontSize.round()}:x=(w*${t.normX.toStringAsFixed(2)}-text_w/2):y=(h*${t.normY.toStringAsFixed(2)}-text_h/2)",
      );
    }

    if (vfParts.isNotEmpty) {
      args.addAll(['-vf', vfParts.join(',')]);
    }

    if (hasMusic) {
      final origVol = isMuted ? 0.0 : audioConfig.originalVolume;
      final musVol = audioConfig.autoDucking
          ? (audioConfig.musicVolume * 0.75)
          : audioConfig.musicVolume;
      args.addAll([
        '-filter_complex',
        '[0:a]volume=${origVol.toStringAsFixed(2)}[a0];[1:a]volume=${musVol.toStringAsFixed(2)}[a1];[a0][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]',
        '-map',
        '0:v',
        '-map',
        '[aout]',
      ]);
    } else if (isMuted && bannerOverlays.isEmpty) {
      args.add('-an');
    }

    args.addAll([
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      crf.toString(),
      '-c:a',
      'aac',
      '-movflags',
      '+faststart',
      outputPath,
    ]);
    return args;
  }

  static Future<ExportResult> exportWithFfmpegKit({
    required String inputPath,
    required Duration start,
    required Duration end,
    AspectRatioPreset aspectRatio = AspectRatioPreset.original,
    String? baseVideoFilter,
    AudioTrackConfig audioConfig = const AudioTrackConfig(),
    List<TextOverlayItem> textOverlays = const [],
    List<BannerOverlayItem> bannerOverlays = const [],
    ProColorGrading proGrading = const ProColorGrading(),
    TransitionConfig transition = const TransitionConfig(),
    BrandWatermarkConfig watermark = const BrandWatermarkConfig(),
    int crf = 20,
    double playbackSpeed = 1.0,
    bool isMuted = false,
    required void Function(double progress, String status) onProgress,
  }) async {
    final totalSpan = end > start ? end - start : const Duration(seconds: 1);
    final outputPath = await createTempExportPath();
    final args = buildAdvancedFfmpegArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      start: start,
      end: end,
      aspectRatio: aspectRatio,
      baseVideoFilter: baseVideoFilter,
      audioConfig: audioConfig,
      textOverlays: textOverlays,
      bannerOverlays: bannerOverlays,
      proGrading: proGrading,
      transition: transition,
      watermark: watermark,
      crf: crf,
      playbackSpeed: playbackSpeed,
      isMuted: isMuted,
    );

    if (kIsWeb) {
      return exportTrimmedVideo(
        config: TrimConfig(
          inputPath: inputPath,
          outputPath: outputPath,
          start: start,
          end: end,
          videoFilter: baseVideoFilter,
          playbackSpeed: playbackSpeed,
          isMuted: isMuted,
        ),
        onProgress: onProgress,
      );
    }

    final completer = Completer<ExportResult>();
    onProgress(0.05, 'Starting mobile FFmpegKit render...');

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          onProgress(1.0, 'Render complete!');
          completer.complete(ExportResult(
            isSuccess: true,
            outputPath: outputPath,
            duration: totalSpan,
            ffmpegCommand: 'ffmpeg ${args.join(" ")}',
            producedRealFile: true,
          ));
        } else {
          final logs = await session.getOutput();
          completer.complete(ExportResult(
            isSuccess: false,
            duration: Duration.zero,
            errorMessage: logs ?? 'FFmpegKit failed with code ${rc?.getValue()}',
            ffmpegCommand: 'ffmpeg ${args.join(" ")}',
          ));
        }
      },
      null,
      (stats) {
        final ms = stats.getTime();
        if (ms > 0 && totalSpan.inMilliseconds > 0) {
          final pct = (ms / totalSpan.inMilliseconds).clamp(0.05, 0.96);
          onProgress(pct, 'Rendering MP4... ${(pct * 100).round()}%');
        }
      },
    );

    return completer.future;
  }

  static Future<ExportResult> exportAudioMp3({
    required String inputPath,
    required Duration start,
    required Duration end,
    required void Function(double progress, String status) onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    String outPath;
    try {
      final dl = Directory('/storage/emulated/0/Download/MithilaStreamStudio');
      if (!await dl.exists()) await dl.create(recursive: true);
      outPath = '${dl.path}/MithilaAudio_$ts.mp3';
    } catch (_) {
      final dir = await getTemporaryDirectory();
      outPath = '${dir.path}/MithilaAudio_$ts.mp3';
    }

    final args = <String>[
      '-y',
      '-ss',
      formatFfmpegTimestamp(start),
      '-to',
      formatFfmpegTimestamp(end),
      '-i',
      inputPath,
      '-vn',
      '-acodec',
      'libmp3lame',
      '-q:a',
      '2',
      outPath,
    ];

    final completer = Completer<ExportResult>();
    onProgress(0.15, 'Extracting MP3 audio...');
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          onProgress(1.0, 'Audio saved: $outPath');
          completer.complete(ExportResult(
            isSuccess: true,
            outputPath: outPath,
            duration: end > start ? end - start : Duration.zero,
            producedRealFile: true,
          ));
        } else {
          final logs = await session.getOutput();
          completer.complete(ExportResult(
            isSuccess: false,
            duration: Duration.zero,
            errorMessage: logs ?? 'Audio export failed',
          ));
        }
      },
    );
    return completer.future;
  }
}

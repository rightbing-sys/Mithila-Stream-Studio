import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';

import 'package:share_plus/share_plus.dart';
import '../models/editor_overlays.dart';
import '../widgets/admin_panel_sheet.dart';
import '../widgets/ai_studio_sheet.dart';
import '../widgets/brand_watermark_sheet.dart';
import '../widgets/pro_adjust_sheet.dart';
import '../widgets/transitions_sheet.dart';

import '../widgets/music_mixer_sheet.dart';
import '../widgets/text_sticker_sheet.dart';
import '../models/video_filter.dart';
import '../services/export_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/tts_service.dart';
import '../widgets/bottom_toolbar.dart';
import '../widgets/filter_selector_sheet.dart';
import '../widgets/speech_captions_sheet.dart';
import '../widgets/trimmer_timeline.dart';
import '../widgets/voiceover_tts_sheet.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  VideoPlayerController? controller;
  File? selectedVideo;
  String? _videoName;
  String? _videoPath;

  // Trimming bounds
  Duration _totalDuration = Duration.zero;
  Duration _startTrim = Duration.zero;
  Duration _endTrim = Duration.zero;
  Duration _currentPosition = Duration.zero;

  bool _isPlaying = false;
  bool _isTrimming = true;
  bool _loopTrimmedRegion = true;
  bool _isLoading = false;
  bool _isLoopSeeking = false;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  String? _playerError;

  // Visual Filters & Color Adjustment
  VideoFilter _selectedFilter = VideoFilter.allFilters.first;
  double _brightness = 0.0;
  bool _isFiltersOpen = false;

  // Pro & AI Features State
  AspectRatioPreset _aspectRatio = AspectRatioPreset.original;
  AudioTrackConfig _audioConfig = const AudioTrackConfig();
  final List<TextOverlayItem> _textOverlays = [];
  final List<StickerOverlayItem> _stickerOverlays = [];
  final List<BannerOverlayItem> _bannerOverlays = [];
  bool _isRatioOpen = false;
  bool _isMusicOpen = false;
  bool _isTextStickerOpen = false;
  bool _isAiOpen = false;
  ProColorGrading _proGrading = const ProColorGrading();
  TransitionConfig _transitionConfig = const TransitionConfig();
  BrandWatermarkConfig _watermarkConfig = const BrandWatermarkConfig();
  bool _isAdjustOpen = false;
  bool _isTransitionOpen = false;
  bool _isBrandOpen = false;
  AdminConfig _adminConfig = const AdminConfig();



  // Speech-to-Text Captions (speech_to_text: ^7.0.0)
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isCaptionsOpen = false;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _speechStatus = 'Tap Start Mic';
  String? _speechError;
  String _partialSpeechText = '';
  double _soundLevel = 0.0;
  String _selectedSpeechLocale = 'en_US';
  List<LocaleName> _deviceLocales = const [];
  final List<CaptionCue> _captionCues = [];
  Duration _dictationAnchorPosition = Duration.zero;
  String captionText = '';

  // Text-to-Speech Voiceover (flutter_tts: ^4.0.2)
  final FlutterTts tts = FlutterTts();
  final TtsService _ttsService = TtsService();
  final TextEditingController _ttsTextController =
      TextEditingController(text: 'Welcome To Mithila Stream Studio');
  bool _isVoiceoverOpen = false;
  bool _isTtsSpeaking = false;
  String _ttsLanguage = 'en-US';
  double _ttsSpeechRate = 0.5;
  double _ttsPitch = 1.0;
  String _ttsActiveWord = '';
  String? _ttsError;

  Future<void> makeVoice() async {
    await tts.speak(
      'Welcome To Mithila Stream Studio',
    );
  }

  @override
  void dispose() {
    tts.stop();
    _speechService.dispose();
    _ttsService.dispose();
    _ttsTextController.dispose();
    controller?.removeListener(_videoListener);
    controller?.dispose();
    super.dispose();
  }

  void _videoListener() {
    if (controller == null) return;

    final value = controller!.value;
    if (value.hasError) {
      if (mounted && _playerError != value.errorDescription) {
        setState(() {
          _playerError = value.errorDescription ?? 'Video playback error';
          _isPlaying = false;
        });
      }
      return;
    }

    if (!value.isInitialized) return;

    final pos = value.position;
    final playing = value.isPlaying;

    // Loop inside trim bounds if enabled (guarded against duplicate async seeks)
    if (_loopTrimmedRegion && playing && !_isLoopSeeking) {
      if (pos >= _endTrim || pos < _startTrim) {
        _isLoopSeeking = true;
        controller!.seekTo(_startTrim).whenComplete(() {
          _isLoopSeeking = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isPlaying = playing;
      });
    }
  }

  String _guessMimeType(String? fileName) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  Future<void> _pickVideo() => pickVideo();


  Future<void> _recordVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (picked == null) return;
      final file = File(picked.path);
      if (!await file.exists()) return;

      setState(() {
        _isLoading = true;
        _playerError = null;
      });
      await controller?.pause();
      await controller?.dispose();
      final newCtrl = VideoPlayerController.file(file);
      await newCtrl.initialize();
      newCtrl.addListener(_videoListener);
      await newCtrl.setLooping(true);
      if (!mounted) return;
      setState(() {
        controller = newCtrl;
        selectedVideo = file;
        _videoPath = picked.path;
        _videoName = picked.name;
        _totalDuration = newCtrl.value.duration;
        _startTrim = Duration.zero;
        _endTrim = newCtrl.value.duration;
        _currentPosition = Duration.zero;
        _isPlaying = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> pickVideo() async {
    setState(() {
      _isLoading = true;
      _playerError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.single;
        if (kIsWeb) {
          selectedVideo = null;
          setState(() {});
          final bytes = picked.bytes;
          if (bytes == null) {
            throw Exception('Unable to read selected video bytes in browser.');
          }
          final dataUri = Uri.dataFromBytes(
            bytes,
            mimeType: _guessMimeType(picked.name),
          ).toString();
          await _initVideoFromUrl(dataUri, name: picked.name, defaultFullRange: true);
        } else if (picked.path != null) {
          selectedVideo = File(picked.path!);
          _videoName = picked.name;
          setState(() {});
          await loadVideo();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _playerError = 'Failed to load video: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> loadVideo() async {
    if (selectedVideo == null) return;

    controller?.removeListener(_videoListener);
    await controller?.dispose();
    controller = null;

    final nextController = VideoPlayerController.file(
      selectedVideo!,
    );
    controller = nextController;

    await nextController.initialize();
    await nextController.setVolume(_isMuted ? 0.0 : 1.0);
    await nextController.setPlaybackSpeed(_playbackSpeed);
    nextController.addListener(_videoListener);

    final dur = nextController.value.duration;
    final segments = selectedVideo!.uri.pathSegments;
    final fallbackName = segments.isNotEmpty ? segments.last : 'video.mp4';

    if (!mounted) return;
    setState(() {
      _videoPath = selectedVideo!.path;
      _videoName = (_videoName != null && _videoName!.isNotEmpty)
          ? _videoName
          : fallbackName;
      _totalDuration = dur;
      _startTrim = Duration.zero;
      _endTrim = dur;
      _currentPosition = Duration.zero;
      _isTrimming = true;
      _playerError = null;
    });

    await nextController.seekTo(Duration.zero);
  }

  Future<void> _loadDemoVideo() async {
    setState(() {
      selectedVideo = null;
      _isLoading = true;
      _playerError = null;
    });

    try {
      // High performance public sample video (Big Buck Bunny mp4)
      const demoUrl =
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      await _initVideoFromUrl(demoUrl, name: 'Sample_BigBuckBunny.mp4');
    } catch (e) {
      if (mounted) {
        setState(() => _playerError = 'Failed to load sample clip: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sample clip: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _configureInitializedController(
    VideoPlayerController nextController, {
    required String pathOrUrl,
    required String name,
    bool defaultFullRange = true,
  }) async {
    await nextController.initialize();
    await nextController.setVolume(_isMuted ? 0.0 : 1.0);
    await nextController.setPlaybackSpeed(_playbackSpeed);
    nextController.addListener(_videoListener);

    final dur = nextController.value.duration;

    if (!mounted) return;
    setState(() {
      controller = nextController;
      _videoPath = pathOrUrl;
      _videoName = name;
      _totalDuration = dur;
      _startTrim = Duration.zero;
      _endTrim = (!defaultFullRange && dur > const Duration(seconds: 12))
          ? const Duration(seconds: 10)
          : dur;
      _currentPosition = Duration.zero;
      _isTrimming = true;
      _playerError = null;
    });

    await nextController.seekTo(Duration.zero);
  }

  Future<void> _initVideoFromFile(File videoFile, {String? name}) async {
    selectedVideo = videoFile;
    if (name != null) {
      _videoName = name;
    }
    await loadVideo();
  }

  Future<void> _initVideoFromPath(String? path, {String? name}) async {
    if (path == null) return;

    if (kIsWeb) {
      await _initVideoFromUrl(path, name: name, defaultFullRange: true);
      return;
    }

    selectedVideo = File(path);
    if (name != null) {
      _videoName = name;
    }
    await loadVideo();
  }

  Future<void> _initVideoFromUrl(
    String url, {
    String? name,
    bool defaultFullRange = false,
  }) async {
    controller?.removeListener(_videoListener);
    await controller?.dispose();
    controller = null;

    final nextController = VideoPlayerController.networkUrl(Uri.parse(url));

    await _configureInitializedController(
      nextController,
      pathOrUrl: url,
      name: name ?? 'Demo Video',
      defaultFullRange: defaultFullRange,
    );
  }

  Future<void> _toggleMute() async {
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    await controller?.setVolume(nextMuted ? 0.0 : 1.0);
  }

  Future<void> _cyclePlaybackSpeed() async {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackSpeed);
    final nextSpeed = speeds[(idx + 1) % speeds.length];
    setState(() => _playbackSpeed = nextSpeed);
    await controller?.setPlaybackSpeed(nextSpeed);
  }

  void _togglePlayPause() {
    if (controller == null || !controller!.value.isInitialized) return;

    if (controller!.value.isPlaying) {
      controller!.pause();
    } else {
      // If position is past endTrim, wrap to startTrim
      if (_currentPosition >= _endTrim || _currentPosition < _startTrim) {
        controller!.seekTo(_startTrim).then((_) {
          controller!.play();
        });
      } else {
        controller!.play();
      }
    }
  }

  void _seekTo(Duration target) {
    if (controller == null || !controller!.value.isInitialized) return;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _totalDuration ? _totalDuration : target);
    setState(() => _currentPosition = clamped);
    controller!.seekTo(clamped);
  }

  void _adjustStartTrim(Duration delta) {
    var newStart = _startTrim + delta;
    if (newStart < Duration.zero) newStart = Duration.zero;
    if (newStart >= _endTrim - const Duration(milliseconds: 300)) {
      newStart = _endTrim - const Duration(milliseconds: 300);
    }
    setState(() => _startTrim = newStart);
    _seekTo(newStart);
  }

  void _adjustEndTrim(Duration delta) {
    var newEnd = _endTrim + delta;
    if (newEnd > _totalDuration) newEnd = _totalDuration;
    if (newEnd <= _startTrim + const Duration(milliseconds: 300)) {
      newEnd = _startTrim + const Duration(milliseconds: 300);
    }
    setState(() => _endTrim = newEnd);
    _seekTo(newEnd);
  }

  void _setStartAtPlayhead() {
    if (_currentPosition >= _endTrim - const Duration(milliseconds: 300)) return;
    setState(() => _startTrim = _currentPosition);
  }

  void _setEndAtPlayhead() {
    if (_currentPosition <= _startTrim + const Duration(milliseconds: 300)) return;
    setState(() => _endTrim = _currentPosition);
  }

  void _resetTrim() {
    setState(() {
      _startTrim = Duration.zero;
      _endTrim = _totalDuration;
    });
    _seekTo(Duration.zero);
  }


  void _openAdminPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminPanelSheet(
        config: _adminConfig,
        onChanged: (cfg) {
          setState(() {
            _adminConfig = cfg;
            if (cfg.forceWatermark) {
              _watermarkConfig = _watermarkConfig.copyWith(
                enabled: true,
                text: cfg.brandHandle,
              );
            }
          });
        },
        onClearAllEdits: () {
          setState(() {
            _selectedFilter = VideoFilter.allFilters.first;
            _brightness = 0.0;
            _proGrading = const ProColorGrading();
            _transitionConfig = const TransitionConfig();
            _textOverlays.clear();
            _stickerOverlays.clear();
            _audioConfig = const AudioTrackConfig();
          });
        },
      ),
    );
  }

  void _showExportDialog() {
    if (controller == null || !controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please import a video first before exporting')),
      );
      return;
    }

    final sourceSpan = _endTrim - _startTrim;
    final trimmedDuration = Duration(
      milliseconds: (sourceSpan.inMilliseconds / _playbackSpeed).round(),
    );
    final ffmpegFilter = _selectedFilter.getFfmpegFilterString(brightness: _brightness);
    final safeInputName = (!kIsWeb && selectedVideo != null)
        ? selectedVideo!.path
        : (_videoName != null && _videoName!.isNotEmpty)
            ? _videoName!
            : (_videoPath ?? 'input.mp4');
    final outputFileName = 'trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    int? selectedTargetHeight; // null = Original
    // 'copy' -> fast -c copy, 'accurate' -> frame-accurate libx264, 'standard' -> concise -i ... -ss ... -to ... output
    String ffmpegMode = 'copy';
    double exportProgress = 0.0;
    String exportStatus = 'Ready to export';
    bool isExporting = false;
    bool isComplete = false;
    ExportResult? exportResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final estimatedBitrate = selectedTargetHeight == 480
                ? 2500
                : selectedTargetHeight == 720
                    ? 5000
                    : 8000;
            final estimatedSize = ExportService.estimateFileSize(
              trimmedDuration,
              bitrateKbps: estimatedBitrate,
            );
            final currentFfmpegCmd = ExportService.generateFfmpegTrimCommand(
              inputPath: safeInputName,
              outputPath: outputFileName,
              start: _startTrim,
              end: _endTrim,
              videoFilter: ffmpegFilter,
              playbackSpeed: _playbackSpeed,
              isMuted: _isMuted,
              targetHeight: selectedTargetHeight,
              streamCopyWhenUnfiltered: ffmpegMode != 'accurate',
              includeCodecFlags: ffmpegMode != 'standard',
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.movie_creation_outlined, color: Color(0xFF10B981), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Export Trimmed Video (FFmpeg)',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  const SizedBox(height: 8),

                  // Metadata cards
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Source File', _videoName ?? 'Untitled.mp4'),
                        if (!kIsWeb && selectedVideo != null && selectedVideo!.existsSync()) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            'Source Size',
                            '${(selectedVideo!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                            valueColor: Colors.white70,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildInfoRow('Trim Range', '${ExportService.formatDuration(_startTrim)} ➔ ${ExportService.formatDuration(_endTrim)}'),
                        const SizedBox(height: 6),
                        _buildInfoRow('Exported Duration', ExportService.formatDuration(trimmedDuration), valueColor: const Color(0xFF10B981)),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Speed / Audio',
                          '${_playbackSpeed}x · ${_isMuted ? "Muted (-an)" : "Audio On"}',
                          valueColor: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow('Visual Filter', _selectedFilter.name, valueColor: const Color(0xFFF59E0B)),
                        if (_brightness != 0) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow('Brightness', '${_brightness > 0 ? "+" : ""}${_brightness.toInt()}%', valueColor: const Color(0xFF38BDF8)),
                        ],
                        const SizedBox(height: 6),
                        _buildInfoRow('Est. File Size', estimatedSize, valueColor: const Color(0xFFF59E0B)),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Resolution',
                          selectedTargetHeight != null
                              ? '${selectedTargetHeight}p Scaled'
                              : '${controller!.value.size.width.toInt()} x ${controller!.value.size.height.toInt()} (Source)',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Output Resolution Selector for FFmpeg scale filter
                  Row(
                    children: [
                      const Text(
                        'Output Scale:',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      for (final option in <MapEntry<String, int?>>[
                        const MapEntry('Source', null),
                        const MapEntry('4K', 2160),
                        const MapEntry('1080p', 1080),
                        const MapEntry('720p', 720),
                        const MapEntry('480p', 480),
                      ]) ...[
                        ChoiceChip(
                          label: Text(option.key, style: const TextStyle(fontSize: 11)),
                          selected: selectedTargetHeight == option.value,
                          selectedColor: const Color(0xFF38BDF8).withOpacity(0.25),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: selectedTargetHeight == option.value
                                ? const Color(0xFF38BDF8)
                                : Colors.white70,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: isExporting
                              ? null
                              : (_) => setModalState(() => selectedTargetHeight = option.value),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // FFmpeg Trim Mode Selector (-ss ... -to ...)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Text(
                          'FFmpeg Mode:',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final mode in const <MapEntry<String, String>>[
                        MapEntry('Fast (-c copy)', 'copy'),
                        MapEntry('Accurate (H.264)', 'accurate'),
                        MapEntry('Standard CLI', 'standard'),
                      ])
                        ChoiceChip(
                          label: Text(mode.key, style: const TextStyle(fontSize: 11)),
                          selected: ffmpegMode == mode.value,
                          selectedColor: const Color(0xFF10B981).withOpacity(0.25),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: ffmpegMode == mode.value
                                ? const Color(0xFF10B981)
                                : Colors.white70,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: isExporting
                              ? null
                              : (_) => setModalState(() => ffmpegMode = mode.value),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Live FFmpeg CLI Preview (-i input -ss HH:MM:SS -to HH:MM:SS output)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            currentFfmpegCmd,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy FFmpeg command',
                          icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: currentFfmpegCmd));
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('FFmpeg command copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (isExporting || isComplete) ...[
                    Text(
                      exportStatus,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: exportProgress,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(exportProgress * 100).toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (isComplete && exportResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: exportResult!.isSuccess
                            ? const Color(0xFF064E3B)
                            : const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: exportResult!.isSuccess
                              ? const Color(0xFF10B981)
                              : Colors.redAccent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                exportResult!.isSuccess ? Icons.check_circle : Icons.error_outline,
                                color: exportResult!.isSuccess
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  !exportResult!.isSuccess
                                      ? (exportResult!.errorMessage ?? 'FFmpeg export failed.')
                                      : exportResult!.producedRealFile
                                          ? 'Trimmed video written to disk (${(exportResult!.fileSizeEstimatedBytes / (1024 * 1024)).toStringAsFixed(2)} MB).'
                                          : (exportResult!.resolutionNote ??
                                              'FFmpeg trim configuration ready.'),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          if (exportResult!.outputPath != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Output: ${exportResult!.outputPath}',
                              style: const TextStyle(
                                color: Color(0xFFA7F3D0),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          if (!kIsWeb &&
                              exportResult!.producedRealFile &&
                              exportResult!.outputPath != null &&
                              File(exportResult!.outputPath!).existsSync()) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final outPath = exportResult!.outputPath!;
                                  final trimmedFile = File(outPath);
                                  Navigator.of(context).pop();
                                  setState(() {
                                    selectedVideo = trimmedFile;
                                    _videoName = outPath.split(Platform.pathSeparator).last;
                                    _videoPath = outPath;
                                  });
                                  await loadVideo();
                                },
                                icon: const Icon(Icons.play_circle_filled, size: 16),
                                label: const Text('Load Trimmed Video into Editor'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFA7F3D0),
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Show FFmpeg command with Copy action
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('FFmpeg CLI Command', style: TextStyle(color: Colors.white)),
                                content: SelectableText(
                                  currentFfmpegCmd,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                                actions: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: currentFfmpegCmd));
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('FFmpeg command copied to clipboard'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.code, size: 16),
                          label: const Text('FFmpeg Cmd'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade300,
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isExporting
                              ? null
                              : () async {
                                  if (isComplete) {
                                    Navigator.of(context).pop();
                                    return;
                                  }

                                  setModalState(() {
                                    isExporting = true;
                                    exportProgress = 0.0;
                                    exportStatus = 'Starting FFmpeg export...';
                                  });

                                  final config = TrimConfig(
                                    inputPath: safeInputName,
                                    outputPath: outputFileName,
                                    start: _startTrim,
                                    end: _endTrim,
                                    videoWidth: controller!.value.size.width.toInt(),
                                    videoHeight: controller!.value.size.height.toInt(),
                                    videoFilter: ffmpegFilter,
                                    playbackSpeed: _playbackSpeed,
                                    isMuted: _isMuted,
                                    targetHeight: selectedTargetHeight,
                                    streamCopyWhenUnfiltered: ffmpegMode != 'accurate',
                                  );

                                  final result = kIsWeb
                                      ? await ExportService.exportTrimmedVideo(
                                          config: config,
                                          onProgress: (p, status) {
                                            setModalState(() {
                                              exportProgress = p;
                                              exportStatus = status;
                                            });
                                          },
                                        )
                                      : await ExportService.exportWithFfmpegKit(
                                          inputPath: _videoPath ?? '',
                                          start: _startTrim,
                                          end: _endTrim,
                                          aspectRatio: _aspectRatio,
                                          baseVideoFilter: ffmpegFilter,
                                          audioConfig: _audioConfig,
                                          textOverlays: _textOverlays,
                                          bannerOverlays: _bannerOverlays,
                                          targetHeight: selectedTargetHeight,
                                          proGrading: _proGrading,
                                          transition: _transitionConfig,
                                          watermark: _watermarkConfig,
                                          playbackSpeed: _playbackSpeed,
                                          isMuted: _isMuted,
                                          onProgress: (p, status) {
                                            setModalState(() {
                                              exportProgress = p;
                                              exportStatus = status;
                                            });
                                          },
                                        );

                                  setModalState(() {
                                    isExporting = false;
                                    isComplete = true;
                                    exportResult = result;
                                    if (result.isSuccess) {
                                      _adminConfig = _adminConfig.copyWith(totalExports: _adminConfig.totalExports + 1);
                                      if (result.producedRealFile && result.outputPath != null) {
                                        await ExportService.saveToGallery(result.outputPath!);
                                      }
                                    }
                                  });
                                },
                          icon: Icon(isComplete ? Icons.done : Icons.save_alt, size: 18),
                          label: Text(isComplete ? 'Saved!' : 'Save Video (MP4)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isExporting
                          ? null
                          : () async {
                              setModalState(() {
                                isExporting = true;
                                exportProgress = 0.1;
                                exportStatus = 'Saving MP3 Audio...';
                              });
                              final aRes = await ExportService.exportAudioMp3(
                                inputPath: _videoPath ?? '',
                                start: _startTrim,
                                end: _endTrim,
                                onProgress: (p, st) => setModalState(() {
                                  exportProgress = p;
                                  exportStatus = st;
                                }),
                              );
                              setModalState(() {
                                isExporting = false;
                                isComplete = aRes.isSuccess;
                                exportResult = aRes;
                              });
                            },
                      icon: const Icon(Icons.audiotrack, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Save Audio Only (MP3)', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                    ),
                  ),
                  if (isComplete &&
                      exportResult != null &&
                      exportResult!.isSuccess &&
                      exportResult!.producedRealFile &&
                      exportResult!.outputPath != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final ok = await ExportService.saveToGallery(exportResult!.outputPath!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Saved to Phone Gallery!'
                                          : 'Gallery permission denied'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gallery save error: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library, size: 16, color: Color(0xFF38BDF8)),
                            label: const Text('Save to Gallery', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Share.shareXFiles(
                                [XFile(exportResult!.outputPath!)],
                                text: 'Edited with Mithila Stream Studio',
                              );
                            },
                            icon: const Icon(Icons.share, size: 16, color: Color(0xFFF59E0B)),
                            label: const Text('Share Reel', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Direct Share (Video + Music):',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _shareChip('YouTube', Icons.play_circle_fill, Colors.redAccent, exportResult!.outputPath!),
                        _shareChip('Instagram', Icons.camera_alt, Colors.pinkAccent, exportResult!.outputPath!),
                        _shareChip('Facebook', Icons.facebook, Colors.blueAccent, exportResult!.outputPath!),
                        _shareChip('WhatsApp', Icons.chat, Colors.greenAccent, exportResult!.outputPath!),
                        _shareChip('Arattai', Icons.forum, const Color(0xFF38BDF8), exportResult!.outputPath!),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSplitDialog() {
    if (controller == null || !controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please import a video first before splitting')),
      );
      return;
    }

    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is too short to split into two parts')),
      );
      return;
    }

    // Initialize split point at current playhead (clamped inside [500ms, total - 500ms])
    final minSplitMs = 500;
    final maxSplitMs = totalMs - 500;
    int splitMs = _currentPosition.inMilliseconds.clamp(minSplitMs, maxSplitMs);
    if (_currentPosition == Duration.zero) {
      splitMs = (totalMs / 2).round().clamp(minSplitMs, maxSplitMs);
    }

    final ffmpegFilter = _selectedFilter.getFfmpegFilterString(brightness: _brightness);
    final safeInputName = (_videoName != null && _videoName!.isNotEmpty)
        ? _videoName!
        : (_videoPath ?? 'input.mp4');

    String splitMode = 'standard'; // 'standard' | 'copy' | 'accurate'
    double splitProgress = 0.0;
    String splitStatus = 'Ready to split into part1.mp4 & part2.mp4';
    bool isSplitting = false;
    bool isComplete = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final splitDuration = Duration(milliseconds: splitMs);
            final part2Duration = _totalDuration - splitDuration;
            final cmds = ExportService.generateFfmpegSplitCommands(
              inputPath: safeInputName,
              splitAt: splitDuration,
              start: Duration.zero,
              part1OutputPath: 'part1.mp4',
              part2OutputPath: 'part2.mp4',
              videoFilter: ffmpegFilter,
              playbackSpeed: _playbackSpeed,
              isMuted: _isMuted,
              streamCopyWhenUnfiltered: splitMode != 'accurate',
              includeCodecFlags: splitMode != 'standard',
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.call_split, color: Color(0xFF38BDF8), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Split Video (FFmpeg 2-Part)',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  const SizedBox(height: 8),

                  // Part 1 & Part 2 Cards
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Split Point',
                          ExportService.formatFfmpegTimestamp(splitDuration),
                          valueColor: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'part1.mp4',
                          '00:00:00 ➔ ${ExportService.formatFfmpegTimestamp(splitDuration)} (${ExportService.formatDuration(splitDuration)})',
                          valueColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'part2.mp4',
                          '${ExportService.formatFfmpegTimestamp(splitDuration)} ➔ End (${ExportService.formatDuration(part2Duration)})',
                          valueColor: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Interactive Split Point Slider & Quick Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adjust Split Timestamp:',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: isSplitting
                                ? null
                                : () {
                                    setModalState(() {
                                      splitMs = _currentPosition.inMilliseconds.clamp(minSplitMs, maxSplitMs);
                                    });
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Use Playhead', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: isSplitting
                                ? null
                                : () {
                                    setModalState(() {
                                      splitMs = (totalMs / 2).round().clamp(minSplitMs, maxSplitMs);
                                    });
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('50% Mid', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF38BDF8),
                      inactiveTrackColor: const Color(0xFF334155),
                      thumbColor: Colors.white,
                      trackHeight: 4,
                    ),
                    child: Slider(
                      min: minSplitMs.toDouble(),
                      max: maxSplitMs.toDouble(),
                      value: splitMs.toDouble().clamp(minSplitMs.toDouble(), maxSplitMs.toDouble()),
                      onChanged: isSplitting
                          ? null
                          : (val) {
                              setModalState(() => splitMs = val.round());
                            },
                    ),
                  ),

                  // Split Mode Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Text(
                          'FFmpeg Mode:',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final mode in const <MapEntry<String, String>>[
                        MapEntry('Standard CLI', 'standard'),
                        MapEntry('Fast (-c copy)', 'copy'),
                        MapEntry('Accurate (H.264)', 'accurate'),
                      ])
                        ChoiceChip(
                          label: Text(mode.key, style: const TextStyle(fontSize: 11)),
                          selected: splitMode == mode.value,
                          selectedColor: const Color(0xFF38BDF8).withOpacity(0.25),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: splitMode == mode.value
                                ? const Color(0xFF38BDF8)
                                : Colors.white70,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: isSplitting
                              ? null
                              : (_) => setModalState(() => splitMode = mode.value),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Live Two-Command FFmpeg CLI Preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            cmds.combinedCommand,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.45,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy both FFmpeg split commands',
                          icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: cmds.combinedCommand));
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('FFmpeg split commands copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (isSplitting || isComplete) ...[
                    Text(
                      splitStatus,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: splitProgress,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Quick Preview & Execute Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSplitting
                              ? null
                              : () {
                                  setState(() {
                                    _startTrim = Duration.zero;
                                    _endTrim = splitDuration;
                                  });
                                  _seekTo(Duration.zero);
                                  Navigator.of(context).pop();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          child: const Text('Trim Part 1', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSplitting
                              ? null
                              : () {
                                  setState(() {
                                    _startTrim = splitDuration;
                                    _endTrim = _totalDuration;
                                  });
                                  _seekTo(splitDuration);
                                  Navigator.of(context).pop();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF59E0B),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          child: const Text('Trim Part 2', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isSplitting
                              ? null
                              : () async {
                                  if (isComplete) {
                                    Navigator.of(context).pop();
                                    return;
                                  }

                                  setModalState(() {
                                    isSplitting = true;
                                    splitProgress = 0.0;
                                    splitStatus = 'Starting 2-part FFmpeg split...';
                                  });

                                  await ExportService.exportSplitVideo(
                                    inputPath: safeInputName,
                                    splitAt: splitDuration,
                                    totalDuration: _totalDuration,
                                    videoFilter: ffmpegFilter,
                                    playbackSpeed: _playbackSpeed,
                                    isMuted: _isMuted,
                                    streamCopyWhenUnfiltered: splitMode != 'accurate',
                                    includeCodecFlags: splitMode != 'standard',
                                    onProgress: (p, status) {
                                      setModalState(() {
                                        splitProgress = p;
                                        splitStatus = status;
                                      });
                                    },
                                  );

                                  setModalState(() {
                                    isSplitting = false;
                                    isComplete = true;
                                  });
                                },
                          icon: Icon(isComplete ? Icons.done : Icons.call_split, size: 16),
                          label: Text(
                            isComplete ? 'Done' : 'Split 2 Parts',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
        });
      }
      return;
    }

    setState(() {
      _speechError = null;
      _partialSpeechText = '';
    });

    final ready = await _speechService.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _speechStatus = status;
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _soundLevel = 0.0;
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _speechError = 'Speech error: $err';
          _isListening = false;
          _soundLevel = 0.0;
        });
      },
    );

    if (!mounted) return;
    if (!ready) {
      setState(() {
        _isSpeechAvailable = false;
        _speechError = 'Microphone / speech recognition unavailable on this device.';
      });
      return;
    }

    if (_deviceLocales.isEmpty) {
      _deviceLocales = await _speechService.getAvailableLocales();
    }

    final resolvedLocale =
        _speechService.resolveLocaleId(_selectedSpeechLocale, _deviceLocales);

    _dictationAnchorPosition = _currentPosition;

    setState(() {
      _isSpeechAvailable = true;
      _isListening = true;
      _speechStatus = 'listening';
    });

    try {
      await _speechService.startListening(
        localeId: resolvedLocale,
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = level);
          }
        },
        onResult: (words, isFinal, confidence) {
          if (!mounted) return;
          if (isFinal && words.isNotEmpty) {
            final start = _dictationAnchorPosition;
            final estimated = SpeechToTextService.estimateCueDuration(words);
            final maxEnd = _totalDuration > Duration.zero
                ? _totalDuration
                : start + estimated;
            final rawEnd = start + estimated;
            final end = rawEnd > maxEnd && _totalDuration > Duration.zero
                ? maxEnd
                : rawEnd;

            final newCue = CaptionCue(
              id: 'cue_${DateTime.now().microsecondsSinceEpoch}',
              text: words,
              start: start,
              end: end > start ? end : start + const Duration(seconds: 2),
              localeId: _selectedSpeechLocale,
              confidence: confidence,
            );

            setState(() {
              _captionCues.add(newCue);
              _captionCues.sort((a, b) => a.start.compareTo(b.start));
              _partialSpeechText = '';
              _dictationAnchorPosition = newCue.end;
            });
          } else {
            setState(() => _partialSpeechText = words);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechError = 'Unable to start speech recognition: $e';
        });
      }
    }
  }

  Future<void> _showCueEditorDialog({CaptionCue? existing}) async {
    final textController = TextEditingController(text: existing?.text ?? '');
    final savedText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          existing == null ? 'Add Caption Cue' : 'Edit Caption Cue',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Enter subtitle text...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF38BDF8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (savedText == null || savedText.isEmpty || !mounted) return;

    setState(() {
      if (existing != null) {
        final idx = _captionCues.indexWhere((c) => c.id == existing.id);
        if (idx != -1) {
          _captionCues[idx] = existing.copyWith(text: savedText);
        }
      } else {
        final start = _currentPosition;
        final est = SpeechToTextService.estimateCueDuration(savedText);
        final end = start + est;
        _captionCues.add(
          CaptionCue(
            id: 'cue_${DateTime.now().microsecondsSinceEpoch}',
            text: savedText,
            start: start,
            end: end,
            localeId: _selectedSpeechLocale,
          ),
        );
        _captionCues.sort((a, b) => a.start.compareTo(b.start));
      }
    });
  }

  Future<void> _copySrtToClipboard() async {
    final srt = SpeechToTextService.buildSrt(_captionCues);
    if (srt.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: srt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${_captionCues.length} captions as SRT'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> generateSubtitle() async {
    const String subtitle = 'Welcome to Mithila Stream Studio';

    final start = _currentPosition;
    final estimated = SpeechToTextService.estimateCueDuration(subtitle);
    final rawEnd = start + estimated;
    final end = (_totalDuration > Duration.zero && rawEnd > _totalDuration)
        ? _totalDuration
        : rawEnd;

    final cue = CaptionCue(
      id: 'cue_${DateTime.now().microsecondsSinceEpoch}',
      text: subtitle,
      start: start,
      end: end > start ? end : start + const Duration(seconds: 3),
      localeId: _selectedSpeechLocale,
    );

    if (!mounted) return;
    setState(() {
      captionText = subtitle;
      _captionCues.add(cue);
      _captionCues.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  Future<void> _speakTts([String? overrideText, String? overrideLocale]) async {
    final textToSpeak = (overrideText ?? _ttsTextController.text).trim();
    if (textToSpeak.isEmpty) return;

    setState(() {
      _ttsError = null;
      _ttsActiveWord = '';
    });

    await _ttsService.initialize(
      onStart: () {
        if (!mounted) return;
        setState(() => _isTtsSpeaking = true);
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _isTtsSpeaking = false;
          _ttsActiveWord = '';
        });
      },
      onCancel: () {
        if (!mounted) return;
        setState(() {
          _isTtsSpeaking = false;
          _ttsActiveWord = '';
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isTtsSpeaking = false;
          _ttsActiveWord = '';
          _ttsError = 'TTS error: $err';
        });
      },
      onProgress: (word) {
        if (!mounted) return;
        setState(() => _ttsActiveWord = word);
      },
    );

    final targetLang = (overrideLocale ?? _ttsLanguage).replaceAll('_', '-');

    try {
      if (mounted) {
        setState(() => _isTtsSpeaking = true);
      }
      await _ttsService.speak(
        textToSpeak,
        language: targetLang,
        speechRate: _ttsSpeechRate,
        pitch: _ttsPitch,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _ttsError = 'Unable to play TTS voiceover: $e';
        });
      }
    }
  }

  Future<void> _stopTts() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() {
        _isTtsSpeaking = false;
        _ttsActiveWord = '';
      });
    }
  }

  void _syncTtsScriptToCaption() {
    final text = _ttsTextController.text.trim();
    if (text.isEmpty) return;
    final start = _currentPosition;
    final est = SpeechToTextService.estimateCueDuration(text);
    final rawEnd = start + est;
    final end = (_totalDuration > Duration.zero && rawEnd > _totalDuration)
        ? _totalDuration
        : rawEnd;

    setState(() {
      captionText = text;
      _captionCues.add(
        CaptionCue(
          id: 'cue_${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          start: start,
          end: end > start ? end : start + const Duration(seconds: 2),
          localeId: _ttsLanguage.replaceAll('-', '_'),
        ),
      );
      _captionCues.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  CaptionCue? _activeCaptionForPosition() {
    for (final cue in _captionCues) {
      if (_currentPosition >= cue.start && _currentPosition <= cue.end) {
        return cue;
      }
    }
    return null;
  }


  Future<void> _handleBackPressed() async {
    if (_isFiltersOpen || _isCaptionsOpen || _isVoiceoverOpen || _isRatioOpen ||
        _isMusicOpen || _isTextStickerOpen || _isAiOpen || _isAdjustOpen ||
        _isTransitionOpen || _isBrandOpen) {
      setState(() {
        _isFiltersOpen = _isCaptionsOpen = _isVoiceoverOpen = _isRatioOpen =
            _isMusicOpen = _isTextStickerOpen = _isAiOpen = _isAdjustOpen =
                _isTransitionOpen = _isBrandOpen = false;
      });
      return;
    }
    if (controller != null && controller!.value.isInitialized) {
      final goHome = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Home par wapas jayein?', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text('Current video band karke Home screen par jaana hai?', style: TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, Back')),
          ],
        ),
      );
      if (goHome == true) {
        await controller?.pause();
        await controller?.dispose();
        setState(() {
          controller = null;
          _videoPath = null;
          _isPlaying = false;
        });
      }
      return;
    }
    final exitApp = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('App band karein?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Kya aap Mithila Stream Studio se bahar jaana chahte hain?', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rukein')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit')),
        ],
      ),
    );
    if (exitApp == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = controller != null && controller!.value.isInitialized;
    final activeCue = _activeCaptionForPosition();
    final overlayCaptionText = _isListening && _partialSpeechText.isNotEmpty
        ? _partialSpeechText
        : (activeCue?.text.isNotEmpty == true ? activeCue!.text : captionText);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: hasVideo
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _handleBackPressed,
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.movie_filter, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'Mithila Stream Studio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (hasVideo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${controller!.value.size.width.toInt()}x${controller!.value.size.height.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Record Video',
            icon: const Icon(Icons.videocam, color: Color(0xFFF43F5E), size: 22),
            onPressed: _recordVideo,
          ),
          IconButton(
            tooltip: 'Admin Panel',
            icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF38BDF8), size: 22),
            onPressed: _openAdminPanel,
          ),
          if (hasVideo) ...[
            IconButton(
              tooltip: 'Import another video',
              onPressed: pickVideo,
              icon: const Icon(Icons.video_file_outlined, size: 20, color: Color(0xFF38BDF8)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF10B981)),
                label: const Text('Export', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: !hasVideo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'rec_vid',
                  onPressed: _recordVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Record'),
                  backgroundColor: const Color(0xFFF43F5E),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  heroTag: 'imp_vid',
                  onPressed: pickVideo,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Import Video'),
                  backgroundColor: const Color(0xFF38BDF8),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Video Preview Stage
          Container(
            height: 250,
            width: double.infinity,
            color: Colors.black,
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        SizedBox(height: 12),
                        Text('Loading video...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : (controller == null || !controller!.value.isInitialized)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: 0.42,
                            child: Image.asset(
                              'assets/images/banner.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x88090D16), Color(0xEE090D16)],
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: 36,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No Video Selected',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Select a video file or load a sample clip to start trimming.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickVideo,
                                    icon: const Icon(Icons.file_upload, size: 17),
                                    label: const Text('Browse Files'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF38BDF8),
                                      foregroundColor: const Color(0xFF0F172A),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: _loadDemoVideo,
                                    icon: const Icon(Icons.play_circle_outline, size: 17),
                                    label: const Text('Try Demo Clip'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFF38BDF8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                    : Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: ColorFiltered(
                                colorFilter: _selectedFilter.toColorFilter(brightness: _brightness),
                                child: AspectRatio(
                                  aspectRatio: _aspectRatio.ratio ??
                                      ((controller!.value.aspectRatio.isFinite &&
                                              controller!.value.aspectRatio > 0)
                                          ? controller!.value.aspectRatio
                                          : 16 / 9),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Container(
                                            color: Colors.black,
                                            child: Center(
                                              child: AspectRatio(
                                                aspectRatio: (controller!.value.aspectRatio.isFinite &&
                                                        controller!.value.aspectRatio > 0)
                                                    ? controller!.value.aspectRatio
                                                    : 16 / 9,
                                                child: VideoPlayer(controller!),
                                              ),
                                            ),
                                          ),
                                          ..._textOverlays.map((item) => Positioned(
                                                left: (item.normX * constraints.maxWidth - 70)
                                                    .clamp(4.0, constraints.maxWidth - 40),
                                                top: (item.normY * constraints.maxHeight - 20)
                                                    .clamp(4.0, constraints.maxHeight - 30),
                                                child: GestureDetector(
                                                  onPanUpdate: (d) {
                                                    setState(() {
                                                      item.normX = (item.normX + d.delta.dx / constraints.maxWidth).clamp(0.05, 0.95);
                                                      item.normY = (item.normY + d.delta.dy / constraints.maxHeight).clamp(0.05, 0.95);
                                                    });
                                                  },
                                                  onLongPress: () => setState(() => _textOverlays.remove(item)),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: item.hasBackground
                                                        ? BoxDecoration(
                                                            color: item.backgroundColor,
                                                            borderRadius: BorderRadius.circular(8),
                                                          )
                                                        : null,
                                                    child: Text(
                                                      item.text,
                                                      style: TextStyle(
                                                        color: item.color,
                                                        fontSize: item.fontSize,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )),
                                          if (_watermarkConfig.enabled && _watermarkConfig.text.trim().isNotEmpty)
                                            Positioned(
                                              top: (_watermarkConfig.position == WatermarkPosition.topLeft || _watermarkConfig.position == WatermarkPosition.topRight) ? 10 : null,
                                              bottom: (_watermarkConfig.position == WatermarkPosition.bottomLeft || _watermarkConfig.position == WatermarkPosition.bottomRight) ? 10 : null,
                                              left: (_watermarkConfig.position == WatermarkPosition.topLeft || _watermarkConfig.position == WatermarkPosition.bottomLeft) ? 12 : null,
                                              right: (_watermarkConfig.position == WatermarkPosition.topRight || _watermarkConfig.position == WatermarkPosition.bottomRight) ? 12 : null,
                                              child: IgnorePointer(
                                                child: Text(
                                                  _watermarkConfig.text,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(_watermarkConfig.opacity),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ..._bannerOverlays.map((bn) => Positioned(
                                                left: (bn.normX * constraints.maxWidth - bn.widthPx / 2)
                                                    .clamp(4.0, constraints.maxWidth - 40),
                                                top: (bn.normY * constraints.maxHeight - 40)
                                                    .clamp(4.0, constraints.maxHeight - 40),
                                                child: GestureDetector(
                                                  onPanUpdate: (d) {
                                                    setState(() {
                                                      bn.normX = (bn.normX + d.delta.dx / constraints.maxWidth).clamp(0.05, 0.95);
                                                      bn.normY = (bn.normY + d.delta.dy / constraints.maxHeight).clamp(0.05, 0.95);
                                                    });
                                                  },
                                                  onLongPress: () => setState(() => _bannerOverlays.remove(bn)),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.file(
                                                      File(bn.imagePath),
                                                      width: bn.widthPx,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              )),
                                          ..._stickerOverlays.map((st) => Positioned(
                                                left: (st.normX * constraints.maxWidth - st.size / 2)
                                                    .clamp(4.0, constraints.maxWidth - st.size),
                                                top: (st.normY * constraints.maxHeight - st.size / 2)
                                                    .clamp(4.0, constraints.maxHeight - st.size),
                                                child: GestureDetector(
                                                  onPanUpdate: (d) {
                                                    setState(() {
                                                      st.normX = (st.normX + d.delta.dx / constraints.maxWidth).clamp(0.05, 0.95);
                                                      st.normY = (st.normY + d.delta.dy / constraints.maxHeight).clamp(0.05, 0.95);
                                                    });
                                                  },
                                                  onLongPress: () => setState(() => _stickerOverlays.remove(st)),
                                                  child: Text(st.emoji, style: TextStyle(fontSize: st.size)),
                                                ),
                                              )),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (_playerError != null)
                              Positioned(
                                top: 10,
                                left: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade900.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.redAccent),
                                  ),
                                  child: Text(
                                    _playerError!,
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            // Active Filter Badge
                            if (_selectedFilter.type != VideoFilterType.none || _brightness != 0.0)
                              Positioned(
                                top: 10,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_selectedFilter.icon, size: 13, color: const Color(0xFFF59E0B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _brightness != 0.0
                                            ? '${_selectedFilter.name} (${_brightness > 0 ? "+" : ""}${_brightness.toInt()}%)'
                                            : _selectedFilter.name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Active Speech / Caption Overlay
                            if (overlayCaptionText.isNotEmpty)
                              Positioned(
                                bottom: 22,
                                left: 16,
                                right: 16,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.78),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _isListening
                                              ? const Color(0xFFEF4444).withOpacity(0.7)
                                              : Colors.white24,
                                        ),
                                      ),
                                      child: Text(
                                        overlayCaptionText,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // VideoProgressIndicator along bottom edge of preview
                            Positioned(
                              bottom: 4,
                              left: 12,
                              right: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: VideoProgressIndicator(
                                  controller!,
                                  allowScrubbing: true,
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  colors: const VideoProgressColors(
                                    playedColor: Color(0xFF38BDF8),
                                    bufferedColor: Color(0xFF334155),
                                    backgroundColor: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),

          // Dedicated Playback Transport Bar
          Container(
            width: double.infinity,
            color: const Color(0xFF020617),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rewind 5s',
                      icon: const Icon(Icons.replay_5, size: 18, color: Colors.white70),
                      onPressed: hasVideo
                          ? () {
                              final target = _currentPosition - const Duration(seconds: 5);
                              _seekTo(target < Duration.zero ? Duration.zero : target);
                            }
                          : null,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.play_arrow),
                      color: _isPlaying ? Colors.white70 : const Color(0xFF38BDF8),
                      onPressed: () {
                        controller?.play();
                      },
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      tooltip: 'Pause',
                      icon: const Icon(Icons.pause),
                      color: _isPlaying ? const Color(0xFF38BDF8) : Colors.white54,
                      onPressed: () {
                        controller?.pause();
                      },
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      tooltip: 'Forward 5s',
                      icon: const Icon(Icons.forward_5, size: 18, color: Colors.white70),
                      onPressed: hasVideo
                          ? () {
                              final target = _currentPosition + const Duration(seconds: 5);
                              _seekTo(target > _totalDuration ? _totalDuration : target);
                            }
                          : null,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Container(height: 16, width: 1, color: Colors.white24),
                    const SizedBox(width: 8),
                    Text(
                      '${ExportService.formatDuration(_currentPosition)} / ${ExportService.formatDuration(_totalDuration)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _cyclePlaybackSpeed,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        size: 18,
                        color: _isMuted ? Colors.redAccent : Colors.white70,
                      ),
                      onPressed: _toggleMute,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Video Trimming Control Panel
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      border: Border(
                        top: BorderSide(color: Color(0xFF1E293B), width: 1),
                        bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick Trim Action Buttons Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.content_cut, size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Video Trimmer',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                // Loop toggle
                                InkWell(
                                  onTap: () {
                                    setState(() => _loopTrimmedRegion = !_loopTrimmedRegion);
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _loopTrimmedRegion ? const Color(0xFF38BDF8).withOpacity(0.15) : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _loopTrimmedRegion ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.repeat,
                                          size: 13,
                                          color: _loopTrimmedRegion ? const Color(0xFF38BDF8) : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Loop Trim',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _loopTrimmedRegion ? const Color(0xFF38BDF8) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (hasVideo)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: _showSplitDialog,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.call_split, size: 12, color: Color(0xFF38BDF8)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Split',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: hasVideo ? _resetTrim : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Interactive Timeline Scrubber & Trim Handles
                        TrimmerTimeline(
                          totalDuration: _totalDuration,
                          startTrim: _startTrim,
                          endTrim: _endTrim,
                          currentPosition: _currentPosition,
                          onStartTrimChanged: (newStart) {
                            setState(() => _startTrim = newStart);
                          },
                          onEndTrimChanged: (newEnd) {
                            setState(() => _endTrim = newEnd);
                          },
                          onSeek: _seekTo,
                          onDragStart: () {
                            if (_isPlaying) controller?.pause();
                          },
                        ),

                        const SizedBox(height: 10),

                        // Fine-tuning nudge controls
                        if (hasVideo)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // In point nudgers
                              Row(
                                children: [
                                  _buildNudgeBtn('-0.1s', () => _adjustStartTrim(const Duration(milliseconds: -100))),
                                  const SizedBox(width: 4),
                                  _buildNudgeBtn('+0.1s', () => _adjustStartTrim(const Duration(milliseconds: 100))),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _setStartAtPlayhead,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                                      ),
                                      child: const Text(
                                        'Set In [',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Out point nudgers
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _setEndAtPlayhead,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                                      ),
                                      child: const Text(
                                        '] Set Out',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildNudgeBtn('-0.1s', () => _adjustEndTrim(const Duration(milliseconds: -100))),
                                  const SizedBox(width: 4),
                                  _buildNudgeBtn('+0.1s', () => _adjustEndTrim(const Duration(milliseconds: 100))),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Horizontal Frame Timeline Strip
                  Container(
                    height: 120,
                    color: const Color(0xff101826),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 20,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: hasVideo
                              ? () {
                                  final targetMs = (_totalDuration.inMilliseconds * (index / 20)).round();
                                  _seekTo(Duration(milliseconds: targetMs));
                                }
                              : null,
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.all(4),
                            color: Colors.blueGrey,
                            child: Center(
                              child: Text(
                                "$index",
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Speech-to-Text Captions Drawer
                  if (_isCaptionsOpen)
                    SpeechCaptionsSheet(
                      isListening: _isListening,
                      isSpeechAvailable: _isSpeechAvailable,
                      speechStatus: _speechStatus,
                      speechError: _speechError,
                      partialText: _partialSpeechText,
                      soundLevel: _soundLevel,
                      selectedLocaleId: _selectedSpeechLocale,
                      cues: _captionCues,
                      currentPosition: _currentPosition,
                      onToggleListening: _toggleListening,
                      onLocaleChanged: (localeId) {
                        setState(() => _selectedSpeechLocale = localeId);
                      },
                      onAddManualCue: () => _showCueEditorDialog(),
                      onGenerateSubtitle: generateSubtitle,
                      onCueTap: (cue) => _seekTo(cue.start),
                      onSpeakCue: (cue) => _speakTts(cue.text, cue.localeId),
                      onCueEdit: (cue) => _showCueEditorDialog(existing: cue),
                      onCueDelete: (id) {
                        setState(() {
                          _captionCues.removeWhere((c) => c.id == id);
                          if (_captionCues.isEmpty) {
                            captionText = '';
                          }
                        });
                      },
                      onCopySrt: _copySrtToClipboard,
                      onClearCues: () {
                        setState(() {
                          _captionCues.clear();
                          captionText = '';
                        });
                      },
                      onClose: () {
                        setState(() => _isCaptionsOpen = false);
                      },
                    ),

                  // Voiceover Text-to-Speech Drawer (flutter_tts: ^4.0.2)
                  if (_isVoiceoverOpen)
                    VoiceoverTtsSheet(
                      textController: _ttsTextController,
                      isSpeaking: _isTtsSpeaking,
                      selectedLanguage: _ttsLanguage,
                      speechRate: _ttsSpeechRate,
                      pitch: _ttsPitch,
                      activeWord: _ttsActiveWord,
                      ttsError: _ttsError,
                      currentCaptionText: overlayCaptionText,
                      onSpeak: () => _speakTts(),
                      onSpeakWelcome: makeVoice,
                      onStop: _stopTts,
                      onLanguageChanged: (lang) {
                        setState(() => _ttsLanguage = lang);
                      },
                      onRateChanged: (rate) {
                        setState(() => _ttsSpeechRate = rate);
                      },
                      onPitchChanged: (pitchVal) {
                        setState(() => _ttsPitch = pitchVal);
                      },
                      onUseActiveCaption: () {
                        if (overlayCaptionText.isNotEmpty) {
                          _ttsTextController.text = overlayCaptionText;
                        }
                      },
                      onAddToCaptions: _syncTtsScriptToCaption,
                      onClose: () {
                        setState(() => _isVoiceoverOpen = false);
                      },
                    ),

                  // Filter Selector Drawer
                  if (_isFiltersOpen)
                    FilterSelectorSheet(
                      selectedFilter: _selectedFilter,
                      brightness: _brightness,
                      onFilterSelected: (newFilter) {
                        setState(() => _selectedFilter = newFilter);
                      },
                      onBrightnessChanged: (newBrightness) {
                        setState(() => _brightness = newBrightness);
                      },
                      onReset: () {
                        setState(() {
                          _selectedFilter = VideoFilter.allFilters.first;
                          _brightness = 0.0;
                        });
                      },
                      onClose: () {
                        setState(() => _isFiltersOpen = false);
                      },
                    ),
                ],
              ),
            ),
          ),

          if (_isRatioOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AspectRatioPreset.values.map((preset) {
                    final selected = _aspectRatio == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(preset.icon, size: 16, color: selected ? const Color(0xFF090D16) : Colors.white70),
                        label: Text(preset.label),
                        selected: selected,
                        selectedColor: const Color(0xFF38BDF8),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: selected ? const Color(0xFF090D16) : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _aspectRatio = preset),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (_isMusicOpen)
            MusicMixerSheet(
              config: _audioConfig,
              onChanged: (cfg) => setState(() => _audioConfig = cfg),
              onClose: () => setState(() => _isMusicOpen = false),
            ),
          if (_isTextStickerOpen)
            TextStickerSheet(
              textOverlays: _textOverlays,
              stickerOverlays: _stickerOverlays,
              onAddText: (item) => setState(() => _textOverlays.add(item)),
              onAddSticker: (st) => setState(() => _stickerOverlays.add(st)),
              onAddBanner: (bn) => setState(() => _bannerOverlays.add(bn)),
              onClearAll: () => setState(() {
                _textOverlays.clear();
                _stickerOverlays.clear();
                _bannerOverlays.clear();
              }),
              onClose: () => setState(() => _isTextStickerOpen = false),
            ),
          if (_isAiOpen)
            AiStudioSheet(
              totalDuration: _totalDuration,
              onApplyAutoEnhance: () {
                setState(() {
                  _selectedFilter = VideoFilter.allFilters.length > 1
                      ? VideoFilter.allFilters[1]
                      : _selectedFilter;
                  _brightness = 8.0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI Auto-Enhance applied!')),
                );
              },
              onApplySmartReelsTrim: (targetLen) {
                if (_totalDuration > Duration.zero) {
                  setState(() {
                    _startTrim = Duration.zero;
                    _endTrim = _totalDuration < targetLen ? _totalDuration : targetLen;
                    _aspectRatio = AspectRatioPreset.reels9x16;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('9:16 Smart ${targetLen.inSeconds}s Reel cut applied!')),
                  );
                }
              },
              onApplyHookText: (hook) {
                setState(() {
                  _textOverlays.add(TextOverlayItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    text: hook,
                    color: const Color(0xFFFACC15),
                    fontSize: 24,
                  ));
                });
              },
              onOpenCaptions: () => setState(() {
                _isAiOpen = false;
                _isCaptionsOpen = true;
              }),
              onOpenVoiceover: () => setState(() {
                _isAiOpen = false;
                _isVoiceoverOpen = true;
              }),
              onClose: () => setState(() => _isAiOpen = false),
            ),

          if (_isAdjustOpen)
            ProAdjustSheet(
              grading: _proGrading,
              onChanged: (g) => setState(() => _proGrading = g),
              onReset: () => setState(() => _proGrading = const ProColorGrading()),
              onClose: () => setState(() => _isAdjustOpen = false),
            ),
          if (_isTransitionOpen)
            TransitionsSheet(
              config: _transitionConfig,
              onChanged: (c) => setState(() => _transitionConfig = c),
              onClose: () => setState(() => _isTransitionOpen = false),
            ),
          if (_isBrandOpen)
            BrandWatermarkSheet(
              config: _watermarkConfig,
              onChanged: (w) => setState(() => _watermarkConfig = w),
              onClose: () => setState(() => _isBrandOpen = false),
            ),

          // Bottom Toolbar
          BottomToolbar(
            onMediaPressed: pickVideo,
            isTrimMode: _isTrimming,
            isRatioMode: _isRatioOpen,
            isMusicMode: _isMusicOpen,
            isTextStickerMode: _isTextStickerOpen,
            isAiMode: _isAiOpen,
            isAdjustMode: _isAdjustOpen,
            isTransitionMode: _isTransitionOpen,
            isBrandMode: _isBrandOpen,
            isAudioMode: _isVoiceoverOpen,
            isCaptionsMode: _isCaptionsOpen,
            isFiltersMode: _isFiltersOpen,
            onTrimPressed: () {
              setState(() {
                _isTrimming = !_isTrimming;
                if (_isTrimming) {
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onRatioPressed: () {
              setState(() {
                _isRatioOpen = !_isRatioOpen;
                if (_isRatioOpen) {
                  _isTrimming = false;
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onMusicPressed: () {
              setState(() {
                _isMusicOpen = !_isMusicOpen;
                if (_isMusicOpen) {
                  _isTrimming = false;
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onTextStickerPressed: () {
              setState(() {
                _isTextStickerOpen = !_isTextStickerOpen;
                if (_isTextStickerOpen) {
                  _isTrimming = false;
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onAiPressed: () {
              setState(() {
                _isAiOpen = !_isAiOpen;
                if (_isAiOpen) {
                  _isTrimming = false;
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                }
              });
            },
            onAdjustPressed: () {
              setState(() {
                _isAdjustOpen = !_isAdjustOpen;
                if (_isAdjustOpen) {
                  _isTrimming = _isFiltersOpen = _isCaptionsOpen = _isVoiceoverOpen = _isRatioOpen = _isMusicOpen = _isTextStickerOpen = _isAiOpen = _isTransitionOpen = _isBrandOpen = false;
                }
              });
            },
            onTransitionPressed: () {
              setState(() {
                _isTransitionOpen = !_isTransitionOpen;
                if (_isTransitionOpen) {
                  _isTrimming = _isFiltersOpen = _isCaptionsOpen = _isVoiceoverOpen = _isRatioOpen = _isMusicOpen = _isTextStickerOpen = _isAiOpen = _isAdjustOpen = _isBrandOpen = false;
                }
              });
            },
            onBrandPressed: () {
              setState(() {
                _isBrandOpen = !_isBrandOpen;
                if (_isBrandOpen) {
                  _isTrimming = _isFiltersOpen = _isCaptionsOpen = _isVoiceoverOpen = _isRatioOpen = _isMusicOpen = _isTextStickerOpen = _isAiOpen = _isAdjustOpen = _isTransitionOpen = false;
                }
              });
            },
            onAudioPressed: () {
              setState(() {
                _isVoiceoverOpen = !_isVoiceoverOpen;
                if (_isVoiceoverOpen) {
                  _isFiltersOpen = false;
                  _isCaptionsOpen = false;
                  _isTrimming = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onCaptionsPressed: () {
              setState(() {
                _isCaptionsOpen = !_isCaptionsOpen;
                if (_isCaptionsOpen) {
                  _isFiltersOpen = false;
                  _isTrimming = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onFiltersPressed: () {
              setState(() {
                _isFiltersOpen = !_isFiltersOpen;
                if (_isFiltersOpen) {
                  _isTrimming = false;
                  _isCaptionsOpen = false;
                  _isVoiceoverOpen = false;
                  _isRatioOpen = false;
                  _isMusicOpen = false;
                  _isTextStickerOpen = false;
                  _isAiOpen = false;
                }
              });
            },
            onExportPressed: _showExportDialog,
          ),
        ],
      ),
      ),
    );
  }


  Widget _shareChip(String platform, IconData icon, Color color, String filePath) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: color),
      label: Text(platform, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(color: color.withOpacity(0.5)),
      onPressed: () async {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Mithila Stream Studio - $platform',
          text: 'Edited with Mithila Stream Studio #$platform #MithilaStreamStudio',
        );
      },
    );
  }

  Widget _buildNudgeBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ),
    );
  }
}

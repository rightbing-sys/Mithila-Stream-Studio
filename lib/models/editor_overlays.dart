import 'package:flutter/material.dart';

enum AspectRatioPreset {
  original('Original', null, null, null, Icons.crop_free),
  reels9x16('9:16 Reels', 9 / 16, 1080, 1920, Icons.stay_current_portrait),
  youtube16x9('16:9 YouTube', 16 / 9, 1920, 1080, Icons.stay_current_landscape),
  square1x1('1:1 Square', 1.0, 1080, 1080, Icons.crop_square),
  portrait4x5('4:5 Post', 4 / 5, 1080, 1350, Icons.crop_portrait);

  final String label;
  final double? ratio;
  final int? exportWidth;
  final int? exportHeight;
  final IconData icon;

  const AspectRatioPreset(
    this.label,
    this.ratio,
    this.exportWidth,
    this.exportHeight,
    this.icon,
  );
}

class TextOverlayItem {
  final String id;
  String text;
  double normX; // 0.0 - 1.0 relative to preview width
  double normY; // 0.0 - 1.0 relative to preview height
  double fontSize;
  Color color;
  bool hasBackground;
  Color backgroundColor;

  TextOverlayItem({
    required this.id,
    required this.text,
    this.normX = 0.5,
    this.normY = 0.25,
    this.fontSize = 24.0,
    this.color = Colors.white,
    this.hasBackground = true,
    this.backgroundColor = const Color(0xAA000000),
  });
}

class StickerOverlayItem {
  final String id;
  final String emoji;
  double normX;
  double normY;
  double size;

  StickerOverlayItem({
    required this.id,
    required this.emoji,
    this.normX = 0.5,
    this.normY = 0.72,
    this.size = 44.0,
  });
}

class AudioTrackConfig {
  final String? filePath;
  final String? fileName;
  final double originalVolume; // 0.0 to 1.0
  final double musicVolume; // 0.0 to 1.0
  final double musicStartOffsetSec;
  final bool autoDucking;

  const AudioTrackConfig({
    this.filePath,
    this.fileName,
    this.originalVolume = 1.0,
    this.musicVolume = 0.6,
    this.musicStartOffsetSec = 0.0,
    this.autoDucking = true,
  });

  bool get hasMusic => filePath != null && filePath!.isNotEmpty;

  AudioTrackConfig copyWith({
    String? filePath,
    String? fileName,
    double? originalVolume,
    double? musicVolume,
    double? musicStartOffsetSec,
    bool? autoDucking,
    bool clearMusic = false,
  }) {
    return AudioTrackConfig(
      filePath: clearMusic ? null : (filePath ?? this.filePath),
      fileName: clearMusic ? null : (fileName ?? this.fileName),
      originalVolume: originalVolume ?? this.originalVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      musicStartOffsetSec: musicStartOffsetSec ?? this.musicStartOffsetSec,
      autoDucking: autoDucking ?? this.autoDucking,
    );
  }
}

class BannerOverlayItem {
  final String id;
  final String imagePath;
  double normX;
  double normY;
  double widthPx;

  BannerOverlayItem({
    required this.id,
    required this.imagePath,
    this.normX = 0.5,
    this.normY = 0.82,
    this.widthPx = 180.0,
  });
}

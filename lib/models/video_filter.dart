import 'dart:ui';
import 'package:flutter/material.dart';

enum VideoFilterType {
  none,
  grayscale,
  sepia,
  warm,
  cool,
  highContrast,
  vintage,
  invert,
}

class VideoFilter {
  final VideoFilterType type;
  final String name;
  final String description;
  final IconData icon;
  final Color previewColor;

  const VideoFilter({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.previewColor,
  });

  static const List<VideoFilter> allFilters = [
    VideoFilter(
      type: VideoFilterType.none,
      name: 'Original',
      description: 'Standard unfiltered video colors',
      icon: Icons.filter_none,
      previewColor: Color(0xFF64748B),
    ),
    VideoFilter(
      type: VideoFilterType.grayscale,
      name: 'Grayscale',
      description: 'Classic monochrome black and white',
      icon: Icons.contrast,
      previewColor: Color(0xFF94A3B8),
    ),
    VideoFilter(
      type: VideoFilterType.sepia,
      name: 'Sepia',
      description: 'Warm antique nostalgic tint',
      icon: Icons.photo_filter,
      previewColor: Color(0xFFD97706),
    ),
    VideoFilter(
      type: VideoFilterType.warm,
      name: 'Warm Golden',
      description: 'Sun-drenched golden hour glow',
      icon: Icons.wb_sunny_outlined,
      previewColor: Color(0xFFF59E0B),
    ),
    VideoFilter(
      type: VideoFilterType.cool,
      name: 'Cool Blue',
      description: 'Crisp cinematic teal and blue tone',
      icon: Icons.ac_unit,
      previewColor: Color(0xFF06B6D4),
    ),
    VideoFilter(
      type: VideoFilterType.highContrast,
      name: 'High Contrast',
      description: 'Punchy vivid highlights and deep shadows',
      icon: Icons.brightness_medium,
      previewColor: Color(0xFFA855F7),
    ),
    VideoFilter(
      type: VideoFilterType.vintage,
      name: 'Vintage Fade',
      description: 'Faded filmic analog look',
      icon: Icons.camera_roll_outlined,
      previewColor: Color(0xFFEC4899),
    ),
    VideoFilter(
      type: VideoFilterType.invert,
      name: 'Invert',
      description: 'Inverted artistic color spectrum (Negative)',
      icon: Icons.invert_colors,
      previewColor: Color(0xFF10B981),
    ),
  ];

  /// Generates a combined 4x5 ColorFilter matrix taking into account the filter
  /// algorithm and brightness adjustment (-100.0 to 100.0, where 0 is neutral).
  ColorFilter toColorFilter({double brightness = 0.0}) {
    // Brightness offset in color space (-100 to 100)
    final b = brightness;

    switch (type) {
      case VideoFilterType.grayscale:
        return ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, b,
          0.2126, 0.7152, 0.0722, 0, b,
          0.2126, 0.7152, 0.0722, 0, b,
          0,      0,      0,      1, 0,
        ]);

      case VideoFilterType.sepia:
        return ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, b,
          0.349, 0.686, 0.168, 0, b,
          0.272, 0.534, 0.131, 0, b,
          0,     0,     0,     1, 0,
        ]);

      case VideoFilterType.warm:
        return ColorFilter.matrix(<double>[
          1.15, 0,    0,    0, b + 15,
          0,    1.05, 0,    0, b + 5,
          0,    0,    0.85, 0, b - 15,
          0,    0,    0,    1, 0,
        ]);

      case VideoFilterType.cool:
        return ColorFilter.matrix(<double>[
          0.85, 0,    0,    0, b - 10,
          0,    0.95, 0,    0, b,
          0,    0,    1.20, 0, b + 20,
          0,    0,    0,    1, 0,
        ]);

      case VideoFilterType.highContrast:
        const c = 1.35;
        const t = (1.0 - c) / 2.0 * 255.0;
        return ColorFilter.matrix(<double>[
          c, 0, 0, 0, t + b,
          0, c, 0, 0, t + b,
          0, 0, c, 0, t + b,
          0, 0, 0, 1, 0,
        ]);

      case VideoFilterType.vintage:
        return ColorFilter.matrix(<double>[
          0.9,  0.1,  0.1, 0, b + 25,
          0.05, 0.85, 0.1, 0, b + 15,
          0.05, 0.1,  0.8, 0, b + 35,
          0,    0,    0,   1, 0,
        ]);

      case VideoFilterType.invert:
        return ColorFilter.matrix(<double>[
          -1,  0,  0, 0, 255 + b,
           0, -1,  0, 0, 255 + b,
           0,  0, -1, 0, 255 + b,
           0,  0,  0, 1, 0,
        ]);

      case VideoFilterType.none:
      default:
        if (b != 0.0) {
          return ColorFilter.matrix(<double>[
            1, 0, 0, 0, b,
            0, 1, 0, 0, b,
            0, 0, 1, 0, b,
            0, 0, 0, 1, 0,
          ]);
        }
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  /// Returns FFmpeg video filter expression for export
  String getFfmpegFilterString({double brightness = 0.0}) {
    final bFrac = (brightness / 255.0).clamp(-1.0, 1.0);
    final bStr = bFrac.toStringAsFixed(2);

    switch (type) {
      case VideoFilterType.grayscale:
        return brightness != 0 ? 'hue=s=0,eq=brightness=$bStr' : 'hue=s=0';
      case VideoFilterType.sepia:
        return 'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131,eq=brightness=$bStr';
      case VideoFilterType.warm:
        return 'colorbalance=rs=0.15:gs=0.05:bs=-0.15,eq=brightness=$bStr';
      case VideoFilterType.cool:
        return 'colorbalance=rs=-0.1:gs=0:bs=0.2,eq=brightness=$bStr';
      case VideoFilterType.highContrast:
        return 'eq=contrast=1.35:brightness=$bStr';
      case VideoFilterType.vintage:
        return 'curves=vintage,eq=brightness=$bStr';
      case VideoFilterType.invert:
        return 'negate,eq=brightness=$bStr';
      case VideoFilterType.none:
      default:
        return brightness != 0 ? 'eq=brightness=$bStr' : '';
    }
  }
}

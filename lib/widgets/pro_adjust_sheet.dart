import 'package:flutter/material.dart';

class ProColorGrading {
  final double contrast; // 0.5 to 2.0 (default 1.0)
  final double saturation; // 0.0 to 2.0 (default 1.0)
  final double warmth; // -1.0 to 1.0 (default 0.0)
  final double vignette; // 0.0 to 1.0 (default 0.0)

  const ProColorGrading({
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.warmth = 0.0,
    this.vignette = 0.0,
  });

  bool get isDefault =>
      (contrast - 1.0).abs() < 0.01 &&
      (saturation - 1.0).abs() < 0.01 &&
      warmth.abs() < 0.01 &&
      vignette < 0.01;

  ProColorGrading copyWith({
    double? contrast,
    double? saturation,
    double? warmth,
    double? vignette,
  }) {
    return ProColorGrading(
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
      vignette: vignette ?? this.vignette,
    );
  }

  String toFfmpegFilter() {
    final parts = <String>[];
    if ((contrast - 1.0).abs() > 0.01 || (saturation - 1.0).abs() > 0.01) {
      parts.add(
        'eq=contrast=${contrast.toStringAsFixed(2)}:saturation=${saturation.toStringAsFixed(2)}',
      );
    }
    if (warmth.abs() > 0.02) {
      final r = (warmth * 0.15).toStringAsFixed(2);
      final b = (-warmth * 0.15).toStringAsFixed(2);
      parts.add('colorbalance=rs=$r:bs=$b');
    }
    if (vignette > 0.05) {
      parts.add('vignette=angle=${(vignette * 0.8).toStringAsFixed(2)}');
    }
    return parts.join(',');
  }
}

class ProAdjustSheet extends StatelessWidget {
  final ProColorGrading grading;
  final ValueChanged<ProColorGrading> onChanged;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const ProAdjustSheet({
    super.key,
    required this.grading,
    required this.onChanged,
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Pro Color Grading',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: onReset,
                child: const Text('Reset', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          _slider('Contrast', grading.contrast, 0.5, 1.8, (v) => onChanged(grading.copyWith(contrast: v))),
          _slider('Saturation', grading.saturation, 0.0, 2.0, (v) => onChanged(grading.copyWith(saturation: v))),
          _slider('Warmth', grading.warmth, -1.0, 1.0, (v) => onChanged(grading.copyWith(warmth: v))),
          _slider('Vignette', grading.vignette, 0.0, 1.0, (v) => onChanged(grading.copyWith(vignette: v))),
        ],
      ),
    );
  }

  Widget _slider(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 78, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: Color(0xFFF59E0B),
              thumbColor: Color(0xFFF59E0B),
              inactiveTrackColor: Color(0xFF334155),
            ),
            child: Slider(value: val.clamp(min, max), min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            val.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

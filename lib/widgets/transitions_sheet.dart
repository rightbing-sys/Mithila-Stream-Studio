import 'package:flutter/material.dart';

enum TransitionPreset {
  none('None', Icons.block),
  fadeInOut('Fade In & Out', Icons.gradient),
  cinematicFade('Cinematic Intro', Icons.movie_filter),
  quickFlash('Reels Flash', Icons.flash_on);

  final String label;
  final IconData icon;
  const TransitionPreset(this.label, this.icon);
}

class TransitionConfig {
  final TransitionPreset preset;
  final double durationSec;

  const TransitionConfig({
    this.preset = TransitionPreset.none,
    this.durationSec = 0.8,
  });

  TransitionConfig copyWith({TransitionPreset? preset, double? durationSec}) {
    return TransitionConfig(
      preset: preset ?? this.preset,
      durationSec: durationSec ?? this.durationSec,
    );
  }

  String toFfmpegFilter(Duration totalClipDuration) {
    if (preset == TransitionPreset.none) return '';
    final d = durationSec.clamp(0.2, 2.5);
    final totalSec = totalClipDuration.inMilliseconds / 1000.0;
    final outStart = (totalSec - d).clamp(0.0, totalSec);
    if (preset == TransitionPreset.fadeInOut || preset == TransitionPreset.cinematicFade) {
      if (totalSec > d * 2) {
        return 'fade=t=in:st=0:d=${d.toStringAsFixed(2)},fade=t=out:st=${outStart.toStringAsFixed(2)}:d=${d.toStringAsFixed(2)}';
      }
      return 'fade=t=in:st=0:d=${d.toStringAsFixed(2)}';
    }
    if (preset == TransitionPreset.quickFlash) {
      return 'fade=t=in:st=0:d=0.35:color=white';
    }
    return '';
  }
}

class TransitionsSheet extends StatelessWidget {
  final TransitionConfig config;
  final ValueChanged<TransitionConfig> onChanged;
  final VoidCallback onClose;

  const TransitionsSheet({
    super.key,
    required this.config,
    required this.onChanged,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.animation, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Pro Transitions & Intro/Outro',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TransitionPreset.values.map((p) {
                final selected = config.preset == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(p.icon, size: 16, color: selected ? const Color(0xFF090D16) : Colors.white70),
                    label: Text(p.label),
                    selected: selected,
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF090D16) : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (_) => onChanged(config.copyWith(preset: p)),
                  ),
                );
              }).toList(),
            ),
          ),
          if (config.preset != TransitionPreset.none) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Duration', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: config.durationSec,
                    min: 0.3,
                    max: 2.5,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) => onChanged(config.copyWith(durationSec: v)),
                  ),
                ),
                Text('${config.durationSec.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

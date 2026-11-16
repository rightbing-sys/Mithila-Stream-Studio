import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/editor_overlays.dart';

class MusicMixerSheet extends StatelessWidget {
  final AudioTrackConfig config;
  final ValueChanged<AudioTrackConfig> onChanged;
  final VoidCallback onClose;

  const MusicMixerSheet({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClose,
  });

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          onChanged(config.copyWith(
            filePath: file.path,
            fileName: file.name,
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick audio: $e')),
        );
      }
    }
  }

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
              const Icon(Icons.music_note, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Background Music & Audio Mix',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
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
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.audiotrack, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.hasMusic
                              ? config.fileName ?? 'Selected Audio'
                              : 'No background music selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: config.hasMusic ? Colors.white : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (config.hasMusic)
                        GestureDetector(
                          onTap: () => onChanged(config.copyWith(clearMusic: true)),
                          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pickAudioFile(context),
                icon: const Icon(Icons.library_music, size: 16),
                label: Text(config.hasMusic ? 'Change' : 'Add Music'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF090D16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Video Audio',
            value: config.originalVolume,
            valueText: '${(config.originalVolume * 100).round()}%',
            activeColor: const Color(0xFF38BDF8),
            onChanged: (v) => onChanged(config.copyWith(originalVolume: v)),
          ),
          _buildSliderRow(
            label: 'Music Vol',
            value: config.musicVolume,
            valueText: '${(config.musicVolume * 100).round()}%',
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => onChanged(config.copyWith(musicVolume: v)),
          ),
          if (config.hasMusic) ...[
            _buildSliderRow(
              label: 'Start Offset',
              value: config.musicStartOffsetSec.clamp(0.0, 60.0),
              max: 60.0,
              valueText: '${config.musicStartOffsetSec.toStringAsFixed(1)}s',
              activeColor: const Color(0xFFF59E0B),
              onChanged: (v) => onChanged(config.copyWith(musicStartOffsetSec: v)),
            ),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'AI Auto-Ducking (Voiceover/dialogue par music kam kare)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Switch(
                  value: config.autoDucking,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (v) => onChanged(config.copyWith(autoDucking: v)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required String valueText,
    required Color activeColor,
    required ValueChanged<double> onChanged,
    double max = 1.0,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: activeColor,
              thumbColor: activeColor,
              inactiveTrackColor: const Color(0xFF334155),
            ),
            child: Slider(
              value: value.clamp(0.0, max),
              min: 0.0,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

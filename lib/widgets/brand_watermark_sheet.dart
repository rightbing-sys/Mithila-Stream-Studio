import 'package:flutter/material.dart';

enum WatermarkPosition {
  topLeft('Top Left'),
  topRight('Top Right'),
  bottomLeft('Bottom Left'),
  bottomRight('Bottom Right');

  final String label;
  const WatermarkPosition(this.label);
}

class BrandWatermarkConfig {
  final bool enabled;
  final String text;
  final double opacity;
  final WatermarkPosition position;

  const BrandWatermarkConfig({
    this.enabled = false,
    this.text = '@CineFlowStudio',
    this.opacity = 0.75,
    this.position = WatermarkPosition.bottomRight,
  });

  BrandWatermarkConfig copyWith({
    bool? enabled,
    String? text,
    double? opacity,
    WatermarkPosition? position,
  }) {
    return BrandWatermarkConfig(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      opacity: opacity ?? this.opacity,
      position: position ?? this.position,
    );
  }

  String toFfmpegDrawtext() {
    if (!enabled || text.trim().isEmpty) return '';
    final escaped = text
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", "\\'");
    String x = 'w-tw-24';
    String y = 'h-th-24';
    switch (position) {
      case WatermarkPosition.topLeft:
        x = '24';
        y = '24';
        break;
      case WatermarkPosition.topRight:
        x = 'w-tw-24';
        y = '24';
        break;
      case WatermarkPosition.bottomLeft:
        x = '24';
        y = 'h-th-24';
        break;
      case WatermarkPosition.bottomRight:
        x = 'w-tw-24';
        y = 'h-th-24';
        break;
    }
    return "drawtext=text='$escaped':fontcolor=white@${opacity.toStringAsFixed(2)}:fontsize=26:x=$x:y=$y";
  }
}

class BrandWatermarkSheet extends StatefulWidget {
  final BrandWatermarkConfig config;
  final ValueChanged<BrandWatermarkConfig> onChanged;
  final VoidCallback onClose;

  const BrandWatermarkSheet({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<BrandWatermarkSheet> createState() => _BrandWatermarkSheetState();
}

class _BrandWatermarkSheetState extends State<BrandWatermarkSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.config.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Channel Brand / Watermark',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Switch(
                value: widget.config.enabled,
                activeColor: const Color(0xFF10B981),
                onChanged: (v) => widget.onChanged(widget.config.copyWith(enabled: v)),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (v) => widget.onChanged(widget.config.copyWith(text: v, enabled: true)),
            decoration: InputDecoration(
              hintText: '@ChannelName ya Brand handle likhein...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: WatermarkPosition.values.map((pos) {
                final sel = widget.config.position == pos;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(pos.label),
                    selected: sel,
                    selectedColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF090D16) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => widget.onChanged(widget.config.copyWith(position: pos, enabled: true)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

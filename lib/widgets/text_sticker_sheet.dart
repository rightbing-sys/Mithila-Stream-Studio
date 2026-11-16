import 'package:flutter/material.dart';

import '../models/editor_overlays.dart';

class TextStickerSheet extends StatefulWidget {
  final List<TextOverlayItem> textOverlays;
  final List<StickerOverlayItem> stickerOverlays;
  final ValueChanged<TextOverlayItem> onAddText;
  final ValueChanged<StickerOverlayItem> onAddSticker;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const TextStickerSheet({
    super.key,
    required this.textOverlays,
    required this.stickerOverlays,
    required this.onAddText,
    required this.onAddSticker,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  State<TextStickerSheet> createState() => _TextStickerSheetState();
}

class _TextStickerSheetState extends State<TextStickerSheet> {
  final TextEditingController _textController = TextEditingController();
  Color _selectedColor = Colors.white;
  double _fontSize = 24.0;
  bool _hasBackground = true;

  static const List<Color> _palette = [
    Colors.white,
    Color(0xFFFACC15),
    Color(0xFF38BDF8),
    Color(0xFF10B981),
    Color(0xFFF43F5E),
    Color(0xFFF97316),
  ];

  static const List<String> _stickers = [
    '🔥', '❤️', '🎬', '⭐', '💯', '🎵', '😂', '🚀', '✨', '👍', '🔔', '🎉',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onAddText(
      TextOverlayItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        fontSize: _fontSize,
        color: _selectedColor,
        hasBackground: _hasBackground,
      ),
    );
    _textController.clear();
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
              const Icon(Icons.text_fields, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Text & Stickers (Preview par drag karein)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (widget.textOverlays.isNotEmpty || widget.stickerOverlays.isNotEmpty)
                TextButton(
                  onPressed: widget.onClearAll,
                  child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Hindi ya English text likhein...',
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
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF090D16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ..._palette.map((c) => GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == c ? Colors.white : Colors.white24,
                          width: _selectedColor == c ? 2.5 : 1,
                        ),
                      ),
                    ),
                  )),
              const Spacer(),
              FilterChip(
                label: const Text('Box', style: TextStyle(fontSize: 11)),
                selected: _hasBackground,
                selectedColor: const Color(0xFF38BDF8).withOpacity(0.25),
                checkmarkColor: const Color(0xFF38BDF8),
                labelStyle: TextStyle(color: _hasBackground ? Colors.white : Colors.white60),
                backgroundColor: const Color(0xFF1E293B),
                onSelected: (v) => setState(() => _hasBackground = v),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Size', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14,
                  max: 44,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              Text('${_fontSize.round()}pt', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stickers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final emoji = _stickers[i];
                return InkWell(
                  onTap: () => widget.onAddSticker(
                    StickerOverlayItem(
                      id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                      emoji: emoji,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

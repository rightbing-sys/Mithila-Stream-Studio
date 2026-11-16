import 'package:flutter/material.dart';
import '../models/video_filter.dart';

class FilterSelectorSheet extends StatelessWidget {
  final VideoFilter selectedFilter;
  final double brightness;
  final ValueChanged<VideoFilter> onFilterSelected;
  final ValueChanged<double> onBrightnessChanged;
  final VoidCallback onReset;
  final VoidCallback? onClose;

  const FilterSelectorSheet({
    super.key,
    required this.selectedFilter,
    required this.brightness,
    required this.onFilterSelected,
    required this.onBrightnessChanged,
    required this.onReset,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_fix_high, color: Color(0xFFF59E0B), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Visual Filters & Color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      selectedFilter.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (selectedFilter.type != VideoFilterType.none || brightness != 0.0)
                    TextButton(
                      onPressed: onReset,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Horizontal Filter Swatches Carousel
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VideoFilter.allFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = VideoFilter.allFilters[index];
                final isSelected = filter.type == selectedFilter.type;

                return GestureDetector(
                  onTap: () => onFilterSelected(filter),
                  child: Container(
                    width: 68,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF141E33),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.25),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Filter Preview Swatch Icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: filter.previewColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: filter.previewColor.withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            filter.icon,
                            size: 16,
                            color: isSelected ? const Color(0xFFF59E0B) : filter.previewColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          filter.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Brightness Adjustment Slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141E33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          'Brightness Adjustment',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Text(
                      brightness == 0.0
                          ? '0% (Neutral)'
                          : '${brightness > 0 ? "+" : ""}${brightness.toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: brightness != 0.0 ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: const Color(0xFF38BDF8),
                    inactiveTrackColor: const Color(0xFF334155),
                    thumbColor: const Color(0xFF38BDF8),
                    overlayColor: const Color(0xFF38BDF8).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: brightness,
                    min: -50.0,
                    max: 50.0,
                    divisions: 100,
                    onChanged: onBrightnessChanged,
                  ),
                ),
                // Quick presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildBrightnessPreset('Dim (-20)', -20.0),
                    const SizedBox(width: 6),
                    _buildBrightnessPreset('Normal (0)', 0.0),
                    const SizedBox(width: 6),
                    _buildBrightnessPreset('Boost (+20)', 20.0),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessPreset(String label, double val) {
    final isCurrent = brightness == val;
    return InkWell(
      onTap: () => onBrightnessChanged(val),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF38BDF8).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrent ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isCurrent ? const Color(0xFF38BDF8) : Colors.grey,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class BottomToolbar extends StatelessWidget {
  final VoidCallback? onMediaPressed;
  final VoidCallback? onTrimPressed;
  final VoidCallback? onRatioPressed;
  final VoidCallback? onMusicPressed;
  final VoidCallback? onTextStickerPressed;
  final VoidCallback? onAiPressed;
  final VoidCallback? onAdjustPressed;
  final VoidCallback? onTransitionPressed;
  final VoidCallback? onBrandPressed;
  final VoidCallback? onAudioPressed;
  final VoidCallback? onCaptionsPressed;
  final VoidCallback? onFiltersPressed;
  final VoidCallback? onExportPressed;
  final bool isTrimMode;
  final bool isRatioMode;
  final bool isMusicMode;
  final bool isTextStickerMode;
  final bool isAiMode;
  final bool isAdjustMode;
  final bool isTransitionMode;
  final bool isBrandMode;
  final bool isAudioMode;
  final bool isCaptionsMode;
  final bool isFiltersMode;

  const BottomToolbar({
    super.key,
    this.onMediaPressed,
    this.onTrimPressed,
    this.onRatioPressed,
    this.onMusicPressed,
    this.onTextStickerPressed,
    this.onAiPressed,
    this.onAdjustPressed,
    this.onTransitionPressed,
    this.onBrandPressed,
    this.onAudioPressed,
    this.onCaptionsPressed,
    this.onFiltersPressed,
    this.onExportPressed,
    this.isTrimMode = false,
    this.isRatioMode = false,
    this.isMusicMode = false,
    this.isTextStickerMode = false,
    this.isAiMode = false,
    this.isAdjustMode = false,
    this.isTransitionMode = false,
    this.isBrandMode = false,
    this.isAudioMode = false,
    this.isCaptionsMode = false,
    this.isFiltersMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _buildToolItem(icon: Icons.video_library, label: "Media", onTap: onMediaPressed),
            _buildToolItem(icon: Icons.content_cut, label: "Trim", isActive: isTrimMode, onTap: onTrimPressed, color: const Color(0xFF38BDF8)),
            _buildToolItem(icon: Icons.aspect_ratio, label: "Ratio", isActive: isRatioMode, onTap: onRatioPressed, color: const Color(0xFF38BDF8)),
            _buildToolItem(icon: Icons.music_note, label: "Music", isActive: isMusicMode, onTap: onMusicPressed, color: const Color(0xFF10B981)),
            _buildToolItem(icon: Icons.text_fields, label: "Text", isActive: isTextStickerMode, onTap: onTextStickerPressed, color: const Color(0xFFF59E0B)),
            _buildToolItem(icon: Icons.auto_awesome, label: "AI Studio", isActive: isAiMode, onTap: onAiPressed, color: const Color(0xFFA855F7)),
            _buildToolItem(icon: Icons.tune, label: "Adjust", isActive: isAdjustMode, onTap: onAdjustPressed, color: const Color(0xFFF59E0B)),
            _buildToolItem(icon: Icons.animation, label: "Effects", isActive: isTransitionMode, onTap: onTransitionPressed, color: const Color(0xFF38BDF8)),
            _buildToolItem(icon: Icons.verified, label: "Brand", isActive: isBrandMode, onTap: onBrandPressed, color: const Color(0xFF10B981)),
            _buildToolItem(icon: Icons.record_voice_over, label: "Voice", isActive: isAudioMode, onTap: onAudioPressed, color: const Color(0xFF10B981)),
            _buildToolItem(icon: Icons.closed_caption, label: "Captions", isActive: isCaptionsMode, onTap: onCaptionsPressed, color: const Color(0xFF38BDF8)),
            _buildToolItem(icon: Icons.auto_fix_high, label: "Filters", isActive: isFiltersMode, onTap: onFiltersPressed, color: const Color(0xFFF59E0B)),
            _buildToolItem(icon: Icons.file_upload_outlined, label: "Export", onTap: onExportPressed, color: const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    Color? color,
  }) {
    final activeColor = color ?? const Color(0xFF38BDF8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: isActive ? activeColor : Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? activeColor : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

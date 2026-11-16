import 'package:flutter/material.dart';
import '../services/export_service.dart';
import '../services/speech_to_text_service.dart';

class SpeechCaptionsSheet extends StatelessWidget {
  final bool isListening;
  final bool isSpeechAvailable;
  final String speechStatus;
  final String? speechError;
  final String partialText;
  final double soundLevel;
  final String selectedLocaleId;
  final List<CaptionCue> cues;
  final Duration currentPosition;
  final VoidCallback onToggleListening;
  final ValueChanged<String> onLocaleChanged;
  final VoidCallback onAddManualCue;
  final VoidCallback? onGenerateSubtitle;
  final ValueChanged<CaptionCue> onCueTap;
  final ValueChanged<CaptionCue>? onSpeakCue;
  final ValueChanged<CaptionCue> onCueEdit;
  final ValueChanged<String> onCueDelete;
  final VoidCallback onCopySrt;
  final VoidCallback onClearCues;
  final VoidCallback? onClose;

  const SpeechCaptionsSheet({
    super.key,
    required this.isListening,
    required this.isSpeechAvailable,
    required this.speechStatus,
    this.speechError,
    required this.partialText,
    required this.soundLevel,
    required this.selectedLocaleId,
    required this.cues,
    required this.currentPosition,
    required this.onToggleListening,
    required this.onLocaleChanged,
    required this.onAddManualCue,
    this.onGenerateSubtitle,
    required this.onCueTap,
    this.onSpeakCue,
    required this.onCueEdit,
    required this.onCueDelete,
    required this.onCopySrt,
    required this.onClearCues,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = ((soundLevel + 2.0) / 12.0).clamp(0.0, 1.0);

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isListening ? Icons.mic : Icons.closed_caption,
                      color: isListening ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Speech to Text Captions',
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
                      border: Border.all(
                        color: isListening ? const Color(0xFFEF4444) : const Color(0xFF334155),
                      ),
                    ),
                    child: Text(
                      isListening ? 'LIVE' : '${cues.length} cues',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isListening ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (cues.isNotEmpty)
                    TextButton.icon(
                      onPressed: onCopySrt,
                      icon: const Icon(Icons.copy_all, size: 14, color: Color(0xFF10B981)),
                      label: const Text(
                        'Copy SRT',
                        style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (cues.isNotEmpty)
                    TextButton(
                      onPressed: onClearCues,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

          // Language Selector Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SpeechToTextService.supportedLanguages.map((lang) {
                final isSelected = selectedLocaleId == lang.localeId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${lang.label} (${lang.shortCode})'),
                    selected: isSelected,
                    onSelected: isListening ? null : (_) => onLocaleChanged(lang.localeId),
                    selectedColor: const Color(0xFF38BDF8).withOpacity(0.2),
                    backgroundColor: const Color(0xFF141E33),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.shade300,
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Dictation Control Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141E33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isListening
                    ? const Color(0xFFEF4444).withOpacity(0.7)
                    : const Color(0xFF1E293B),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onToggleListening,
                          icon: Icon(
                            isListening ? Icons.stop_circle_outlined : Icons.mic,
                            size: 17,
                          ),
                          label: Text(isListening ? 'Stop Dictation' : 'Start Mic'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isListening ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                            foregroundColor:
                                isListening ? Colors.white : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (onGenerateSubtitle != null)
                          OutlinedButton.icon(
                            onPressed: onGenerateSubtitle,
                            icon: const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF38BDF8)),
                            label: const Text('Auto Subtitle'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: onAddManualCue,
                          icon: const Icon(Icons.add_comment_outlined, size: 15),
                          label: Text('@ ${ExportService.formatDuration(currentPosition)}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isListening
                          ? 'Listening...'
                          : (isSpeechAvailable ? speechStatus : 'Mic Ready'),
                      style: TextStyle(
                        fontSize: 10,
                        color: isListening ? const Color(0xFFEF4444) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                if (isListening) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: normalizedLevel > 0.05 ? normalizedLevel : null,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF1E293B),
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
                if (partialText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Text(
                      partialText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (speechError != null && speechError!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    speechError!,
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Captured Caption Cues List
          if (cues.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141E33),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Text(
                'Tap Start Mic to transcribe voice captions anchored to the playhead, or add a cue manually.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 165),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cues.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final cue = cues[index];
                  final isActive =
                      currentPosition >= cue.start && currentPosition <= cue.end;
                  return InkWell(
                    onTap: () => onCueTap(cue),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1E293B) : const Color(0xFF141E33),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090D16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${ExportService.formatDuration(cue.start)}–${ExportService.formatDuration(cue.end)}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cue.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                          if (onSpeakCue != null)
                            IconButton(
                              tooltip: 'Speak caption (TTS)',
                              icon: const Icon(Icons.volume_up_outlined, size: 15, color: Color(0xFF10B981)),
                              onPressed: () => onSpeakCue!(cue),
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              padding: EdgeInsets.zero,
                            ),
                          IconButton(
                            tooltip: 'Edit caption',
                            icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.grey),
                            onPressed: () => onCueEdit(cue),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            tooltip: 'Delete caption',
                            icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                            onPressed: () => onCueDelete(cue.id),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
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

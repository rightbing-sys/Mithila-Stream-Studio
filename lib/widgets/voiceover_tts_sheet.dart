import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class VoiceoverTtsSheet extends StatelessWidget {
  final TextEditingController textController;
  final bool isSpeaking;
  final String selectedLanguage;
  final double speechRate;
  final double pitch;
  final String activeWord;
  final String? ttsError;
  final String? currentCaptionText;
  final VoidCallback onSpeak;
  final VoidCallback? onSpeakWelcome;
  final VoidCallback onStop;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<double> onPitchChanged;
  final VoidCallback onUseActiveCaption;
  final VoidCallback onAddToCaptions;
  final VoidCallback? onClose;

  const VoiceoverTtsSheet({
    super.key,
    required this.textController,
    required this.isSpeaking,
    required this.selectedLanguage,
    required this.speechRate,
    required this.pitch,
    required this.activeWord,
    this.ttsError,
    this.currentCaptionText,
    required this.onSpeak,
    this.onSpeakWelcome,
    required this.onStop,
    required this.onLanguageChanged,
    required this.onRateChanged,
    required this.onPitchChanged,
    required this.onUseActiveCaption,
    required this.onAddToCaptions,
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
                      isSpeaking ? Icons.graphic_eq : Icons.record_voice_over,
                      color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Voiceover & Text-to-Speech',
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
                        color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF334155),
                      ),
                    ),
                    child: Text(
                      isSpeaking ? 'SPEAKING' : 'TTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
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

          const SizedBox(height: 10),

          // Language Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TtsService.supportedLanguages.map((lang) {
                final isSelected = selectedLanguage == lang.code;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${lang.label} (${lang.shortCode})'),
                    selected: isSelected,
                    onSelected: isSpeaking ? null : (_) => onLanguageChanged(lang.code),
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

          // Script Text Input
          TextField(
            controller: textController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Enter narration script to speak aloud...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF141E33),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Speech Rate & Pitch Sliders
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141E33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 48,
                      child: Text('Speed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: speechRate,
                          min: 0.25,
                          max: 1.0,
                          divisions: 15,
                          activeColor: const Color(0xFF38BDF8),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: onRateChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(speechRate * 2).toStringAsFixed(1)}x',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 48,
                      child: Text('Pitch', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: pitch,
                          min: 0.6,
                          max: 1.6,
                          divisions: 20,
                          activeColor: const Color(0xFF10B981),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: onPitchChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        pitch.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isSpeaking && activeWord.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
              ),
              child: Text(
                'Speaking: "$activeWord"',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
            ),
          ],

          if (ttsError != null && ttsError!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ttsError!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
          ],

          const SizedBox(height: 10),

          // Action Controls
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: isSpeaking ? onStop : onSpeak,
                icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up, size: 16),
                label: Text(isSpeaking ? 'Stop Voiceover' : 'Speak Narration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSpeaking ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                  foregroundColor: isSpeaking ? Colors.white : const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAddToCaptions,
                icon: const Icon(Icons.subtitles_outlined, size: 15),
                label: const Text('Sync as Caption'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
              if (onSpeakWelcome != null && !isSpeaking)
                OutlinedButton.icon(
                  onPressed: onSpeakWelcome,
                  icon: const Icon(Icons.campaign_outlined, size: 15),
                  label: const Text('Welcome Voice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              if (currentCaptionText != null && currentCaptionText!.isNotEmpty)
                OutlinedButton(
                  onPressed: onUseActiveCaption,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Load Caption'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

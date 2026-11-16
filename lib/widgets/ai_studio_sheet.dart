import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AiStudioSheet extends StatefulWidget {
  final Duration totalDuration;
  final VoidCallback onApplyAutoEnhance;
  final ValueChanged<Duration> onApplySmartReelsTrim;
  final ValueChanged<String> onApplyHookText;
  final VoidCallback onOpenCaptions;
  final VoidCallback onOpenVoiceover;
  final VoidCallback onClose;

  const AiStudioSheet({
    super.key,
    required this.totalDuration,
    required this.onApplyAutoEnhance,
    required this.onApplySmartReelsTrim,
    required this.onApplyHookText,
    required this.onOpenCaptions,
    required this.onOpenVoiceover,
    required this.onClose,
  });

  @override
  State<AiStudioSheet> createState() => _AiStudioSheetState();
}

class _AiStudioSheetState extends State<AiStudioSheet> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedResult;

  @override
  void dispose() {
    _topicController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _generateViralIdeas() async {
    final topic = _topicController.text.trim().isEmpty
        ? 'Trending Reels / YouTube Video'
        : _topicController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    setState(() {
      _isGenerating = true;
      _generatedResult = null;
    });

    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
        );
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'Generate 1 short viral hook text (max 6 words), 2 catchy titles (Hindi+English), and 8 trending hashtags for a video about: $topic'
                  }
                ]
              }
            ],
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.toString().isNotEmpty) {
            setState(() {
              _generatedResult = text.toString();
              _isGenerating = false;
            });
            return;
          }
        }
      } catch (_) {
        // Fall back to instant smart template below
      }
    }

    await Future.delayed(const Duration(milliseconds: 350));
    setState(() {
      _generatedResult =
          'Hook: "$topic — ये ज़रूर देखें! 🔥"\n'
          'Title: $topic | Full Story & Best Moments\n'
          'Hashtags: #ReelsIndia #YouTubeShorts #Trending #ViralVideo #CineFlowStudio #HindiReels #CreatorsIndia #ExplorePage';
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'AI Creator Studio',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _aiActionChip(
                  icon: Icons.color_lens,
                  label: 'AI Auto-Enhance',
                  color: const Color(0xFFF59E0B),
                  onTap: widget.onApplyAutoEnhance,
                ),
                _aiActionChip(
                  icon: Icons.flash_on,
                  label: '15s Viral Reel Cut',
                  color: const Color(0xFF38BDF8),
                  onTap: () => widget.onApplySmartReelsTrim(const Duration(seconds: 15)),
                ),
                _aiActionChip(
                  icon: Icons.bolt,
                  label: '30s Shorts Cut',
                  color: const Color(0xFF10B981),
                  onTap: () => widget.onApplySmartReelsTrim(const Duration(seconds: 30)),
                ),
                _aiActionChip(
                  icon: Icons.closed_caption,
                  label: 'AI Auto-Captions',
                  color: const Color(0xFFA855F7),
                  onTap: widget.onOpenCaptions,
                ),
                _aiActionChip(
                  icon: Icons.record_voice_over,
                  label: 'AI Voiceover',
                  color: const Color(0xFFEC4899),
                  onTap: widget.onOpenVoiceover,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Video topic likhein (e.g. Pune Street Food, Music Reel)...',
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Optional: Gemini API Key (khali chhodein for smart offline)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateViralIdeas,
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: Text(_isGenerating ? '...' : 'Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF090D16),
                  ),
                ),
              ],
            ),
            if (_generatedResult != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _generatedResult!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generatedResult!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied title & hashtags!')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copy All', style: TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            final hook = _topicController.text.trim().isEmpty
                                ? 'ये ज़रूर देखें! 🔥'
                                : '${_topicController.text.trim()} 🔥';
                            widget.onApplyHookText(hook);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF090D16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('Add Hook to Video', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aiActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: color),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(color: color.withOpacity(0.5)),
      onPressed: onTap,
    );
  }
}

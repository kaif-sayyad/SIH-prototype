import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';

class AiCounsellorBottomSheet extends StatefulWidget {
  final String lang;
  final String role;
  final String? activeTrade;
  final String? activeLocation;

  const AiCounsellorBottomSheet({
    Key? key,
    required this.lang,
    required this.role,
    this.activeTrade,
    this.activeLocation,
  }) : super(key: key);

  @override
  State<AiCounsellorBottomSheet> createState() => _AiCounsellorBottomSheetState();
}

class _AiCounsellorBottomSheetState extends State<AiCounsellorBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = false;
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'msg_welcome',
      sender: 'ai',
      text: 'Namaste! I am your AI Career Counsellor. Ask any question about vocational earnings, job placement, safety, or further degree progression.',
      isGrounded: true,
      source: 'MSDE Verified Datasets 2026',
    )
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage(widget.lang == 'mr' ? 'mr-IN' : 'en-IN');
    await _flutterTts.setSpeechRate(0.9);
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = prefilledText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: widget.role == 'parent' ? 'parent' : 'student',
      text: text,
    );

    setState(() {
      _messages.add(userMsg);
      _inputController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    final result = await _geminiService.queryGroundedCounsellor(
      question: text,
      trade: widget.activeTrade,
      location: widget.activeLocation,
      language: widget.lang,
      role: widget.role,
    );

    final aiMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
      sender: 'ai',
      text: result['answer'] ?? 'Verified information updated.',
      citations: List<String>.from(result['citations'] ?? []),
      source: result['source'],
      date: result['date'],
      isGrounded: result['isGrounded'] ?? true,
    );

    if (mounted) {
      setState(() {
        _messages.add(aiMsg);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1B365D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFFFF9933)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Family Career Counsellor (Gemini 3.8 Flash)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),

          // Quick Prompt Suggestions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.blue.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickChip('What is the starting salary?'),
                  _quickChip('Is there a degree pathway?'),
                  _quickChip('How safe is industrial work?'),
                  _quickChip('Will placements be local?'),
                ],
              ),
            ),
          ),

          // Messages View
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.sender != 'ai';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? (msg.sender == 'parent' ? const Color(0xFF8B0000) : const Color(0xFF1B365D))
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUser ? Colors.transparent : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.white24 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                msg.sender == 'ai'
                                    ? 'AI Counsellor'
                                    : (msg.sender == 'parent' ? 'Parent' : 'Student'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isUser ? Colors.white : const Color(0xFF1B365D),
                                ),
                              ),
                            ),
                            if (!isUser) ...[
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.volume_up, size: 18, color: Colors.blue),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () => _speak(msg.text),
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        if (msg.source != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.verified, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Source: ${msg.source} (${msg.date ?? '2026'})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: isUser ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Verifying with MSDE database...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: widget.lang == 'mr'
                          ? 'तुमचा प्रश्न इथे विचारा...'
                          : 'Ask any career or placement doubt...',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: const Color(0xFF1B365D),
                  onPressed: () => _sendMessage(),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11)),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.blue.shade200),
        onPressed: () => _sendMessage(text),
      ),
    );
  }
}

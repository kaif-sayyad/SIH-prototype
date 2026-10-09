import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../backend/api/concerns_api.dart';
import '../../constants/app_constants.dart';
import '../../models/user_session.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';

class Step4ConcernsView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step4ConcernsView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step4ConcernsView> createState() => _Step4ConcernsViewState();
}

class _Step4ConcernsViewState extends State<Step4ConcernsView> {
  final GeminiService _geminiService = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();

  String? _expandedConcernId;
  bool _isLoading = false;
  Map<String, String> _aiAnswers = {};

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage(widget.lang == 'mr' ? 'mr-IN' : 'en-IN');
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _loadGroundedAdvice(String concernId, String concernTitle) async {
    if (_aiAnswers.containsKey(concernId)) {
      setState(() => _expandedConcernId = concernId);
      return;
    }

    setState(() {
      _expandedConcernId = concernId;
      _isLoading = true;
    });

    final trade = widget.session.profile.selectedTrade;
    final location = widget.session.profile.location;

    final query = 'Our family has serious concerns regarding $concernTitle for $trade in $location. Give verified evidence addressing this.';
    final res = await _geminiService.queryGroundedCounsellor(
      question: query,
      trade: trade,
      location: location,
      language: widget.lang,
      role: widget.session.role,
    );

    if (mounted) {
      setState(() {
        _aiAnswers[concernId] = res['answer'] ?? 'Verified information loaded.';
        _isLoading = false;
      });
    }
  }

  void _setResolution(String concernId, String status) {
    setState(() {
      widget.session.concernFeedback[concernId] = status;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Feedback recorded: ${status.toUpperCase()}'),
        duration: const Duration(seconds: 1),
      ),
    );

    // Persist family feedback through the backend concern-resolution loop
    // (Yes / Partly / No) with sentiment shift tracking.
    _persistResolution(concernId, status);
  }

  Future<void> _persistResolution(String concernId, String status) async {
    final token = AuthService().currentToken;
    if (token == null) return;
    final feedback = status == 'resolved'
        ? 'yes'
        : (status == 'partly' ? 'partly' : 'no');
    try {
      await ConcernsApi.resolve(
        token: token,
        sessionId: widget.session.sessionId,
        concernCategory: concernId,
        feedback: feedback,
      );
    } catch (_) {
      // Offline - feedback remains in memory
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMr = widget.lang == 'mr';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी ४: पालकांच्या शंका व समाधान' : 'Step 4: Parental Concern Resolution Loop',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'प्रत्येक शंकेवर क्लिक करून सत्यापित पुरावा तपासा आणि समाधान स्थिती (होय / अंशतः / नाही) नोंदवा.'
                : 'Click any parental concern to review evidence-backed counsel. Mark family resolution (Yes / Partly / No) to monitor sentiment shifts.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // List of 8 core concerns
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppConstants.concerns.length,
            itemBuilder: (context, index) {
              final c = AppConstants.concerns[index];
              final id = c['id']!;
              final title = isMr ? c['title_mr']! : c['title_en']!;
              final icon = c['icon']!;
              final desc = c['desc']!;
              final feedback = widget.session.concernFeedback[id];
              final isExpanded = _expandedConcernId == id;

              Color statusColor = Colors.grey;
              String statusLabel = 'Not Reviewed';
              if (feedback == 'resolved') {
                statusColor = Colors.green;
                statusLabel = 'Resolved ✓';
              } else if (feedback == 'partly') {
                statusColor = Colors.orange;
                statusLabel = 'Partly Resolved';
              } else if (feedback == 'unresolved') {
                statusColor = Colors.red;
                statusLabel = 'Unresolved (Needs Counsellor)';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isExpanded ? const Color(0xFF1B365D) : Colors.grey.shade300,
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _loadGroundedAdvice(id, title),
                        child: Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),

                      if (isExpanded) ...[
                        const Divider(height: 20),
                        if (_isLoading && !_aiAnswers.containsKey(id))
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_aiAnswers.containsKey(id)) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Verified Grounded Counsel (Gemini 3.8 Flash):',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up, size: 20, color: Colors.blue),
                                      onPressed: () => _speak(_aiAnswers[id]!),
                                      tooltip: 'Read Aloud',
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _aiAnswers[id]!,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            isMr ? 'ही माहिती वाचून कुटुंब समाधानी आहे का?' : 'Has this verified answer resolved family hesitation?',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              _feedbackBtn(id, 'resolved', 'Yes, Resolved', Colors.green, Icons.check_circle),
                              const SizedBox(width: 8),
                              _feedbackBtn(id, 'partly', 'Partly Resolved', Colors.orange, Icons.help_outline),
                              const SizedBox(width: 8),
                              _feedbackBtn(id, 'unresolved', 'Still Concerned', Colors.red, Icons.cancel_outlined),
                            ],
                          )
                        ]
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: widget.onBack,
                child: Text(isMr ? 'मागे' : 'Back'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B365D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: widget.onNext,
                icon: const Icon(Icons.arrow_forward),
                label: Text(isMr ? 'करिअर मार्ग व तुलना पहा' : 'View Multi-Year Career Pathway'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _feedbackBtn(String concernId, String type, String label, Color color, IconData icon) {
    final isSelected = widget.session.concernFeedback[concernId] == type;

    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? color : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 10)),
        onPressed: () => _setResolution(concernId, type),
      ),
    );
  }
}

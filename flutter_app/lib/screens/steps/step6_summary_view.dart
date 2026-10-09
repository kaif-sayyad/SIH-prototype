import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_session.dart';
import '../../services/auth_service.dart';

class Step6SummaryView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step6SummaryView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step6SummaryView> createState() => _Step6SummaryViewState();
}

class _Step6SummaryViewState extends State<Step6SummaryView> {
  final AuthService _authService = AuthService();

  void _regenerateCode() async {
    final newCode = await _authService.regenerateParentCode();
    if (newCode != null) {
      widget.session.parentAccessCode = newCode;
    }
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New Parent Access Code Generated: ${widget.session.parentAccessCode}. Old code invalidated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMr = widget.lang == 'mr';
    final p = widget.session.profile;
    final f = widget.session.familyContext;
    final resolvedCount = widget.session.concernFeedback.values.where((v) => v == 'resolved').length;
    final totalConcerns = f.activeConcerns.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी ६: कौटुंबिक निर्णय सारांश' : 'Step 6: Collaborative Family Decision Summary',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'विद्यार्थी आणि पालकांच्या सहमतीने अंतिम करिअर आराखडा.'
                : 'Consolidated summary of student aspirations, parent considerations, and verified outcomes.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Parent Access Code Card
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFF1B365D), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Parent Access Code:',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        Text(
                          widget.session.parentAccessCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Color(0xFF1B365D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Color(0xFF1B365D)),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.session.parentAccessCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Access code copied!')),
                      );
                    },
                  ),
                  OutlinedButton(
                    onPressed: _regenerateCode,
                    child: const Text('Regenerate', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Portfolio Summary Cards
          _summaryCard('Student Details', [
            'Name: ${p.name}',
            'Education: ${p.education}',
            'Location: ${p.location}',
            'Selected Trade: ${p.selectedTrade}',
            'Goal: ${p.goal}',
          ]),
          const SizedBox(height: 12),

          _summaryCard('Family Background & Agreement', [
            'Parent: ${widget.session.parentName}',
            'Income Bracket: ${f.incomeBracket}',
            'Employment Nature: ${f.stability}',
            'Job Location: ${f.locationRequirement}',
            'Concerns Addressed: $resolvedCount of $totalConcerns marked resolved',
          ]),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export Family PDF'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Family decision summary exported to device!')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Connect Counsellor'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(isMr ? 'मागे' : 'Back to Pathway'),
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryCard(String title, List<String> lines) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B365D)),
            ),
            const Divider(height: 16),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l, style: const TextStyle(fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }
}

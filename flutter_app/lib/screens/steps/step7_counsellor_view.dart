import 'package:flutter/material.dart';
import '../../models/user_session.dart';

class Step7CounsellorView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onBack;

  const Step7CounsellorView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step7CounsellorView> createState() => _Step7CounsellorViewState();
}

class _Step7CounsellorViewState extends State<Step7CounsellorView> {
  final _reasonCtrl = TextEditingController(text: 'Need guidance on industrial apprentice safety and local job options in Nagpur district.');
  String _preferredSlot = 'Tomorrow 11:00 AM - 12:00 PM';
  bool _booked = false;

  void _bookEscalation() {
    setState(() => _booked = true);
    widget.session.counsellorNotes.add('Escalation booked by family: ${_reasonCtrl.text.trim()} (Slot: $_preferredSlot)');
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
              const Icon(Icons.support_agent, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी ७: मानवी समुपदेशक मदत' : 'Step 7: Certified Human Counsellor Escalation',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'काही शंका अनुत्तरीत राहिल्यास शासकीय प्रमाणित समुपदेशकांशी प्रत्यक्ष बोला.'
                : 'Whenever AI answers or parental resistance require nuanced mediation, book a certified MSDE career counsellor.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          if (_booked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Counselling Session Confirmed!',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A certified MSDE vocational counsellor has been assigned to ${widget.session.studentName} and family. Confirmation SMS sent to ${widget.session.studentPhone}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text('Scheduled Slot: $_preferredSlot', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isMr ? 'समुपदेशकासाठी विशेष प्रश्न / अडचण' : 'Primary Family Question / Doubts for Counsellor',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _preferredSlot,
              decoration: InputDecoration(
                labelText: isMr ? 'सोयीची वेळ' : 'Preferred Consultation Time Slot',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                'Tomorrow 11:00 AM - 12:00 PM',
                'Tomorrow 03:00 PM - 04:00 PM',
                'Saturday 10:00 AM - 11:00 AM',
                'Direct Walk-in at District ITI Nagpur',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _preferredSlot = v!),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _bookEscalation,
              icon: const Icon(Icons.calendar_month),
              label: Text(isMr ? 'समुपदेशन वेळ आरक्षित करा' : 'Confirm Counsellor Session Request'),
            ),
          ],
          const SizedBox(height: 24),

          OutlinedButton(
            onPressed: widget.onBack,
            child: Text(isMr ? 'मागे सारांशावर जा' : 'Back to Summary'),
          ),
        ],
      ),
    );
  }
}

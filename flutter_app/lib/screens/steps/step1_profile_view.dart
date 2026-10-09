import 'package:flutter/material.dart';
import '../../backend/api/session_api.dart';
import '../../models/user_session.dart';
import '../../services/auth_service.dart';

class Step1ProfileView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;

  const Step1ProfileView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
  }) : super(key: key);

  @override
  State<Step1ProfileView> createState() => _Step1ProfileViewState();
}

class _Step1ProfileViewState extends State<Step1ProfileView> {
  late TextEditingController _nameCtrl;
  late TextEditingController _goalCtrl;
  String _education = '10th Pass';
  String _district = 'Nagpur';
  String _trade = 'Electrician';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.session.profile.name);
    _goalCtrl = TextEditingController(text: widget.session.profile.goal);
    _education = widget.session.profile.education;
    _district = widget.session.profile.location;
    _trade = widget.session.profile.selectedTrade;
  }

  void _save() {
    widget.session.profile.name = _nameCtrl.text.trim();
    widget.session.profile.goal = _goalCtrl.text.trim();
    widget.session.profile.education = _education;
    widget.session.profile.location = _district;
    widget.session.profile.selectedTrade = _trade;

    // Persist student profile to the local backend session store
    _persistProfile();

    widget.onNext();
  }

  Future<void> _persistProfile() async {
    final token = AuthService().currentToken;
    if (token == null) return;
    try {
      await SessionApi.saveSession(
        token,
        sessionId: widget.session.sessionId,
        studentProfile: {
          'sName': widget.session.profile.name,
          'sEdu': widget.session.profile.education,
          'sLoc': widget.session.profile.location,
          'sInterest': widget.session.profile.interest,
          'sInterestTrade': widget.session.profile.selectedTrade,
          'sGoal': widget.session.profile.goal,
        },
        currentStep: 2,
      );
    } catch (_) {
      // Offline - profile remains in memory
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
              const Icon(Icons.person, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी १: विद्यार्थी माहिती' : 'Step 1: Student Career Profile',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'विद्यार्थ्याचे शिक्षण, जिल्हा आणि आवडीचे क्षेत्र निवडा.'
                : 'Define student education background, home district, and intended vocational trade.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Name
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: isMr ? 'विद्यार्थ्याचे नाव' : 'Student Full Name',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          // Education Level
          DropdownButtonFormField<String>(
            value: _education,
            decoration: InputDecoration(
              labelText: isMr ? 'सध्याचे शिक्षण' : 'Current Qualification',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: ['8th Standard', '10th Pass', '12th Pass (Arts/Commerce)', '12th Pass (Science)', 'ITI Ongoing']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _education = v!),
          ),
          const SizedBox(height: 14),

          // District / Location
          DropdownButtonFormField<String>(
            value: _district,
            decoration: InputDecoration(
              labelText: isMr ? 'गृह जिल्हा' : 'Home District (Maharashtra / State)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: ['Nagpur', 'Pune', 'Mumbai', 'Nashik', 'Chhatrapati Sambhajinagar', 'Thane', 'Amravati']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _district = v!),
          ),
          const SizedBox(height: 14),

          // Interested Trade
          DropdownButtonFormField<String>(
            value: _trade,
            decoration: InputDecoration(
              labelText: isMr ? 'आवडीचा व्यावसायिक ट्रेड' : 'Primary Vocational Trade Interest',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              'Electrician',
              'Solar Technician',
              'CNC Operator',
              'Automotive Service Technician',
              'Welder (GMAW & GTAW)',
              'Computer Operator & Programming Assistant (COPA)'
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _trade = v!),
          ),
          const SizedBox(height: 14),

          // Career Goal
          TextField(
            controller: _goalCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: isMr ? 'दीर्घकालीन करिअर ध्येय' : 'Long-term Employment / Career Goal',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Next Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _save,
              icon: const Icon(Icons.arrow_forward),
              label: Text(isMr ? 'जतन करा आणि कुटुंब माहितीवर जा' : 'Save & Continue to Family Context'),
            ),
          ),
        ],
      ),
    );
  }
}

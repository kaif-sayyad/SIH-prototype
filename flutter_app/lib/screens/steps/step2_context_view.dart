import 'package:flutter/material.dart';
import '../../backend/api/session_api.dart';
import '../../constants/app_constants.dart';
import '../../models/user_session.dart';
import '../../services/auth_service.dart';

class Step2ContextView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2ContextView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step2ContextView> createState() => _Step2ContextViewState();
}

class _Step2ContextViewState extends State<Step2ContextView> {
  String _income = '₹10,000 - ₹20,000 / month';
  String _stability = 'Private company employment';
  String _attitude = 'Skill certification is acceptable';
  String _locReq = 'Prefer staying in home district';
  late List<String> _selectedConcerns;

  @override
  void initState() {
    super.initState();
    _income = widget.session.familyContext.incomeBracket;
    _stability = widget.session.familyContext.stability;
    _attitude = widget.session.familyContext.educationAttitude;
    _locReq = widget.session.familyContext.locationRequirement;
    _selectedConcerns = List.from(widget.session.familyContext.activeConcerns);
  }

  void _save() {
    widget.session.familyContext.incomeBracket = _income;
    widget.session.familyContext.stability = _stability;
    widget.session.familyContext.educationAttitude = _attitude;
    widget.session.familyContext.locationRequirement = _locReq;
    widget.session.familyContext.activeConcerns = _selectedConcerns;

    // Persist family context to the local backend session store
    _persistContext();

    widget.onNext();
  }

  Future<void> _persistContext() async {
    final token = AuthService().currentToken;
    if (token == null) return;
    try {
      await SessionApi.saveSession(
        token,
        sessionId: widget.session.sessionId,
        familyContext: {
          'fIncome': _income,
          'fStable': _stability,
          'fEdu': _attitude,
          'fLocReq': _locReq,
          'fConcerns': _selectedConcerns,
        },
        currentStep: 3,
      );
    } catch (_) {
      // Offline - context remains in memory
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
              const Icon(Icons.family_restroom, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी २: कौटुंबिक पार्श्वभूमी' : 'Step 2: Family Context & Constraints',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'कुटुंबाची आर्थिक परिस्थिती आणि प्रमुख काळजीचे मुद्दे नोंदवा.'
                : 'Capture household financial realities, distance boundaries, and core parental concerns.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          DropdownButtonFormField<String>(
            value: _income,
            decoration: InputDecoration(
              labelText: isMr ? 'कुटुंबाचे मासिक उत्पन्न' : 'Household Monthly Income Bracket',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              'Below ₹10,000 / month',
              '₹10,000 - ₹20,000 / month',
              '₹20,000 - ₹35,000 / month',
              'Above ₹35,000 / month',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _income = v!),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _stability,
            decoration: InputDecoration(
              labelText: isMr ? 'पालकांचे नोकरी स्वरूप' : 'Parent Occupation Stability',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              'Daily wage / Agricultural labor',
              'Small business / Self-employed',
              'Private company employment',
              'Government / PSU employee',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _stability = v!),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _locReq,
            decoration: InputDecoration(
              labelText: isMr ? 'कामाचे ठिकाण प्राधान्य' : 'Job Location Requirement',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              'Must stay in home district / city',
              'Willing to move to nearby major industrial cluster',
              'Anywhere in the state',
              'Open to pan-India relocation',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _locReq = v!),
          ),
          const SizedBox(height: 18),

          Text(
            isMr ? 'पालकांच्या प्रमुख चिंता (निवडा):' : 'Key Parental & Family Concerns (Select all that apply):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.concerns.map((c) {
              final id = c['id']!;
              final isSelected = _selectedConcerns.contains(id);
              final title = isMr ? c['title_mr']! : c['title_en']!;
              final icon = c['icon']!;

              return FilterChip(
                avatar: Text(icon),
                label: Text(title, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: Colors.blue.shade100,
                checkmarkColor: const Color(0xFF1B365D),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedConcerns.add(id);
                    } else {
                      _selectedConcerns.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

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
                onPressed: _save,
                icon: const Icon(Icons.arrow_forward),
                label: Text(isMr ? 'परिणाम व शिफारसी पहा' : 'View Verified Outcomes'),
              ),
            ],
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../backend/api/counsellor_api.dart';
import '../services/auth_service.dart';

class CounsellorScreen extends StatefulWidget {
  final VoidCallback onBack;

  const CounsellorScreen({Key? key, required this.onBack}) : super(key: key);

  @override
  State<CounsellorScreen> createState() => _CounsellorScreenState();
}

class _CounsellorScreenState extends State<CounsellorScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  List<Map<String, dynamic>> _escalations = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    final token = _authService.currentToken;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await CounsellorApi.getInbox(token);
      final escalations = (res['escalations'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (mounted) {
        setState(() {
          _escalations = escalations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _resolveCase(Map<String, dynamic> esc) async {
    final token = _authService.currentToken;
    if (token == null) return;
    try {
      await CounsellorApi.updateInbox(
        token: token,
        escalationId: esc['id'] as String? ?? '',
        status: 'resolved',
        counsellorNotes: 'Resolved via counsellor escalation desk',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case marked resolved')),
      );
      _loadInbox();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve case: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.badge, color: Colors.teal, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Certified Counsellor Escalation Desk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                onPressed: _loadInbox,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Exit Desk'),
                onPressed: widget.onBack,
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Family cases requiring personalized intervention and parental mediation.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_escalations.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No open escalations. Families marked "Still Concerned" in Step 4 '
                  'or requesting a human counsellor appear here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                // Illustrative fallback cards for the demo flow
                _escalationCard(
                  context,
                  'Demo Student 1 (Parent: Rajesh Sharma)',
                  'Nagpur • Trade: Electrician',
                  'Parent hesitant regarding workplace electrical safety & starting wage in local manufacturing units.',
                  'Pending Review',
                  Colors.orange,
                ),
              ],
            )
          else
            ..._escalations.map((esc) {
              final status = (esc['status'] as String? ?? 'open');
              final color = status == 'resolved'
                  ? Colors.blue
                  : (status == 'in_progress' ? Colors.green : Colors.orange);
              final statusLabel = status == 'resolved'
                  ? 'Resolved'
                  : (status == 'in_progress' ? 'In Progress' : 'Pending Review');
              return _liveEscalationCard(esc, statusLabel, color);
            }).toList(),

          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Inbox error: $_error',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _liveEscalationCard(Map<String, dynamic> esc, String status, Color statusColor) {
    final studentName = esc['studentName'] as String? ?? 'Student';
    final profile = (esc['studentProfile'] as Map<String, dynamic>?) ?? {};
    final trade = profile['sInterestTrade'] ?? profile['sInterest'] ?? 'Vocational Trade';
    final location = profile['sLoc'] ?? 'Maharashtra';
    final reason = esc['reason'] as String? ?? 'Family requested counsellor assistance.';
    final concerns = (esc['concerns'] as List<dynamic>?) ?? [];
    final concernList = concerns.map((c) => (c is Map) ? (c['category'] as String? ?? '') : '').where((s) => s.isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$location • Trade: $trade', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Concern: $reason', style: const TextStyle(fontSize: 12)),
            if (concernList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Concern categories: $concernList',
                    style: const TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling family via MSDE Dialler...')),
                    );
                  },
                  child: const Text('Initiate Audio Call', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () => _resolveCase(esc),
                  child: const Text('Mark Case Resolved', style: TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _escalationCard(
    BuildContext context,
    String name,
    String meta,
    String doubt,
    String status,
    Color statusColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(meta, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Concern: $doubt', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling family via MSDE Dialler...')),
                    );
                  },
                  child: const Text('Initiate Audio Call', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Counsellor notes logged.')),
                    );
                  },
                  child: const Text('Mark Case Resolved', style: TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

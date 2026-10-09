import 'package:flutter/material.dart';
import '../backend/api/admin_api.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';

class AdminScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AdminScreen({Key? key, required this.onBack}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();
  bool _testingAi = false;
  Map<String, dynamic>? _aiTestResult;

  bool _loadingAnalytics = false;
  Map<String, dynamic>? _analytics;
  String _analyticsError = '';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final token = _authService.currentToken;
    if (token == null) return;
    setState(() {
      _loadingAnalytics = true;
      _analyticsError = '';
    });
    try {
      final res = await AdminApi.getAnalytics(token);
      if (mounted) {
        setState(() {
          _analytics = res['analytics'] as Map<String, dynamic>?;
          _loadingAnalytics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyticsError = '$e';
          _loadingAnalytics = false;
        });
      }
    }
  }

  Future<void> _generateDemoData() async {
    final token = _authService.currentToken;
    if (token == null) return;
    try {
      await AdminApi.demoMode(token);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('8 demo counselling sessions generated')),
      );
      _loadAnalytics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo generation failed: $e')),
      );
    }
  }

  Future<void> _reindexKnowledge() async {
    final token = _authService.currentToken;
    if (token == null) return;
    try {
      final res = await AdminApi.reindex(token);
      final outcomes = res['outcomesResult'] as Map<String, dynamic>?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Knowledge reloaded: ${outcomes?['validRows'] ?? 0} outcome rows, ${res['guideChunks'] ?? 0} guide chunks',
          ),
        ),
      );
      _loadAnalytics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reindex failed: $e')),
      );
    }
  }

  void _runAiTest() async {
    setState(() {
      _testingAi = true;
      _aiTestResult = null;
    });

    final res = await _geminiService.testConnection();
    if (mounted) {
      setState(() {
        _testingAi = false;
        _aiTestResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_analytics?['summary'] as Map<String, dynamic>?);
    final resistance =
        (_analytics?['resistanceByDistrict'] as List<dynamic>?) ?? [];
    final concernPct = (_analytics?['concernPercentages'] as Map<String, dynamic>?) ?? {};
    final knowledgeStats = (_analytics?['knowledgeStats'] as Map<String, dynamic>?) ?? {};
    final validation = (knowledgeStats['validationReport'] as Map<String, dynamic>?);

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
                  Icon(Icons.admin_panel_settings, color: Color(0xFF1B365D), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'MSDE Administrative Analytics & AI Hub',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Exit Admin'),
                onPressed: widget.onBack,
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'State-wide parental sentiment analysis, concern clusters, and AI model health.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Live summary cards
          if (_loadingAnalytics)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (summary != null) ...[
            Row(
              children: [
                _statCard('Families Counselled', '${summary['totalFamilies']}'),
                _statCard('Completed', '${summary['completedSessions']}'),
                _statCard('AI Resolved', '${summary['aiResolved']}'),
                _statCard('Escalations', '${summary['escalatedSessions']}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Resolution Rate: ${summary['resolutionRate']}% • Dataset: ${knowledgeStats['datasetVersion'] ?? "knowledge_v1"} (${validation?['validRows'] ?? "-"}/${validation?['totalRows'] ?? "-"} rows valid)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],

          // Gemini API Status Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.smart_toy, color: Color(0xFFFF9933)),
                      SizedBox(width: 8),
                      Text(
                        'Gemini AI Health & API Configuration',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Model: ${AppConstants.geminiModel}', style: const TextStyle(fontSize: 12)),
                  Text('Embeddings: ${knowledgeStats['embeddingStatus'] ?? "Offline / Keyword Fallback"}', style: const TextStyle(fontSize: 12)),
                  Text('Knowledge Chunks: ${knowledgeStats['chunkCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),

                  if (_aiTestResult != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _aiTestResult!['success'] == true ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _aiTestResult!['success'] == true ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        _aiTestResult!['message'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _aiTestResult!['success'] == true ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B365D),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _testingAi ? null : _runAiTest,
                          icon: _testingAi
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.network_check, size: 16),
                          label: Text(_testingAi ? 'Testing Gemini API...' : 'Test Live Gemini Connection'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reload Knowledge'),
                        onPressed: _reindexKnowledge,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Demo Data'),
                        onPressed: _generateDemoData,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parental Resistance by District (live from backend)
          const Text(
            'Parental Resistance Frequency by District:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
          ),
          const SizedBox(height: 10),
          if (resistance.isEmpty)
            const Text('No session data yet. Generate demo data or counsel a family.',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ...resistance.take(6).map((r) {
              final rate = (r['resistanceRate'] as num?)?.toInt() ?? 0;
              return _districtBar(
                r['district'] as String? ?? 'Unknown',
                rate,
                '${r['totalConcerns']} concerns • ${r['unresolvedCount']} unresolved',
              );
            }).toList(),

          const SizedBox(height: 20),
          const Text(
            'Concern Distribution (State Overview):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
          ),
          const SizedBox(height: 10),
          if (concernPct.isEmpty)
            const Text('No concern data recorded yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            ...concernPct.entries.take(6).map((e) {
              final total = concernPct.values.fold<int>(0, (a, b) => a + ((b as num).toInt()));
              final pct = total > 0 ? ((e.value as num).toInt() / total * 100).round() : 0;
              return _metricTile(e.key, '$pct% of Families (${e.value})', Colors.blue);
            }).toList(),
          const SizedBox(height: 8),

          if (_analyticsError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Analytics error: $_analyticsError',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _districtBar(String district, int pct, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(district, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('$pct% Resistance Index', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct / 100.0,
            backgroundColor: Colors.grey.shade300,
            color: pct > 40 ? Colors.red : Colors.orange,
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _metricTile(String title, String stat, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(stat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.shade800)),
        ],
      ),
    );
  }
}

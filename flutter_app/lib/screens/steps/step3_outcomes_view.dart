import 'package:flutter/material.dart';
import '../../models/trade_outcome.dart';
import '../../models/user_session.dart';
import '../../services/knowledge_service.dart';

class Step3OutcomesView extends StatefulWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step3OutcomesView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step3OutcomesView> createState() => _Step3OutcomesViewState();
}

class _Step3OutcomesViewState extends State<Step3OutcomesView> {
  late String _selectedTrade;
  List<TradeOutcome> _outcomes = [];

  @override
  void initState() {
    super.initState();
    _selectedTrade = widget.session.profile.selectedTrade;
    _outcomes = KnowledgeService.verifiedOutcomes;
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
              const Icon(Icons.analytics, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी ३: सत्यापित ट्रेड निकाल' : 'Step 3: Verified Trade Outcomes & Placements',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'शासकीय सर्वेक्षणावर आधारित खरी आकडेवारी (वेतन, प्लेसमेंट, कालावधी).'
                : 'Government verified empirical metrics: actual starting earnings, placement %, NSQF level and training fees.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Cards list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _outcomes.length,
            itemBuilder: (context, index) {
              final o = _outcomes[index];
              final isChosen = o.trade.toLowerCase() == _selectedTrade.toLowerCase();

              return Card(
                elevation: isChosen ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isChosen ? const Color(0xFFFF9933) : Colors.grey.shade300,
                    width: isChosen ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              o.trade,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isChosen ? const Color(0xFF1B365D) : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade600),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Verified Govt Data',
                                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${o.provider} • ${o.location}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // Metrics row
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metricCol('Placement Rate', '${o.placementRate}%', Colors.green.shade700),
                            _metricCol('Avg Monthly Salary', '₹${o.avgEarnings}', const Color(0xFF1B365D)),
                            _metricCol('NSQF Level', 'Level ${o.nsqfLevel}', Colors.purple.shade700),
                            _metricCol('Duration', '${o.durationMonths} Months', Colors.orange.shade800),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Roles: ${o.jobRoles}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Source: ${o.source} (${o.dataDate})',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isChosen ? const Color(0xFF1B365D) : Colors.transparent,
                            foregroundColor: isChosen ? Colors.white : const Color(0xFF1B365D),
                          ),
                          onPressed: () {
                            setState(() => _selectedTrade = o.trade);
                            widget.session.profile.selectedTrade = o.trade;
                          },
                          child: Text(isChosen ? 'Selected for Family Plan ✓' : 'Select Trade'),
                        ),
                      )
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
                onPressed: () {
                  widget.session.profile.selectedTrade = _selectedTrade;
                  widget.onNext();
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(isMr ? 'शंका निवारण सत्राकडे जा' : 'Address Family Concerns'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/user_session.dart';

class Step5PathwayView extends StatelessWidget {
  final UserSession session;
  final String lang;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step5PathwayView({
    Key? key,
    required this.session,
    required this.lang,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMr = lang == 'mr';
    final trade = session.profile.selectedTrade;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: Color(0xFF1B365D)),
              const SizedBox(width: 8),
              Text(
                isMr ? 'पायरी ५: बहु-वर्षीय करिअर मार्ग' : 'Step 5: Multi-Year Career Pathway & Academic Mobility',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isMr
                ? 'ITI नंतर उच्च शिक्षणाचे दरवाजे उघडे आहेत (पॉलिटेक्निक डिप्लोमा थेट द्वितीय वर्ष, B.Voc / B.Tech).'
                : 'Debunking the "Dead-End" myth: Full lateral mobility from NSQF Level 4 to Polytechnic Diplomas, B.Voc and B.Tech engineering degrees.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24),

          // Progression Roadmap
          Text(
            '$trade 5-Year Progression Roadmap:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B365D)),
          ),
          const SizedBox(height: 12),

          _roadmapStep(
            'Year 1: ITI Craftsman Training (CTS)',
            'Gain hands-on workshop training, workshop safety, engineering drawing. NSQF Level 4 certification.',
            'Earnings: ₹0 (Govt subsidized fee: ₹9,000)',
            Colors.blue.shade700,
          ),
          _roadmapStep(
            'Year 2: Dual Apprenticeship (NAPS)',
            'On-the-job training in formal manufacturing or utility enterprise with government stipend.',
            'Stipend: ₹10,000 - ₹12,500 / month',
            Colors.teal.shade700,
          ),
          _roadmapStep(
            'Year 3: Lateral Entry to Polytechnic Diploma',
            'Direct lateral admission into 2nd year Diploma (MSBTE/State Tech Board) without repeating 11th/12th.',
            'Earnings / Part-time: ₹18,000 / month',
            Colors.orange.shade800,
          ),
          _roadmapStep(
            'Year 4-5: Senior Technician / B.Voc Degree',
            'Promotion to Maintenance In-charge, Senior Wireman or B.Tech/B.Voc Engineering degree.',
            'Earnings: ₹28,000 - ₹38,000 / month',
            Colors.green.shade700,
          ),

          const SizedBox(height: 20),
          const Text(
            '5-Year Cumulative Financial Comparison:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B365D)),
          ),
          const SizedBox(height: 10),

          // Comparison table
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('Metric', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Vocational Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green))),
                  Padding(padding: EdgeInsets.all(8), child: Text('General Academic (BA/B.Com)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                ],
              ),
              const TableRow(children: [
                Padding(padding: EdgeInsets.all(8), child: Text('Total Educational Cost', style: TextStyle(fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('₹15,000 (Govt)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('₹90,000 - ₹1,50,000', style: TextStyle(fontSize: 11))),
              ]),
              const TableRow(children: [
                Padding(padding: EdgeInsets.all(8), child: Text('Age at First Earnings', style: TextStyle(fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('18 - 19 Years', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
                Padding(padding: EdgeInsets.all(8), child: Text('22 - 24 Years', style: TextStyle(fontSize: 11))),
              ]),
              const TableRow(children: [
                Padding(padding: EdgeInsets.all(8), child: Text('5-Year Net Earnings', style: TextStyle(fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('₹7,50,000+', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
                Padding(padding: EdgeInsets.all(8), child: Text('₹1,20,000 (delayed)', style: TextStyle(fontSize: 11))),
              ]),
            ],
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
                onPressed: widget.onNext,
                icon: const Icon(Icons.arrow_forward),
                label: Text(isMr ? 'कुटुंब सारांश पहा' : 'View Family Decision Summary'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _roadmapStep(String title, String desc, String earnings, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(earnings, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

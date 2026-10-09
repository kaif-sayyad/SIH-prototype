import 'dart:convert';
import 'dart:math';

import '../database_service.dart';
import '../gemini_service.dart';
import '../rag/retrieval_service.dart';
import '../rag/verification_service.dart';

/// Port of backend lib/agent/tools.ts — agentic counsellor tools.

class StudentProfile {
  final String? sName;
  final String? sEdu;
  final String? sLoc;
  final String? sInterest;
  final dynamic sMonths;
  final String? sGoal;

  const StudentProfile({
    this.sName,
    this.sEdu,
    this.sLoc,
    this.sInterest,
    this.sMonths,
    this.sGoal,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        sName: json['sName'] as String?,
        sEdu: json['sEdu'] as String?,
        sLoc: json['sLoc'] as String?,
        sInterest: json['sInterest'] as String?,
        sMonths: json['sMonths'],
        sGoal: json['sGoal'] as String?,
      );
}

class FamilyContext {
  final String? fIncome;
  final String? fStable;
  final String? fEdu;
  final String? fLocReq;
  final List<String>? fConcerns;

  const FamilyContext({
    this.fIncome,
    this.fStable,
    this.fEdu,
    this.fLocReq,
    this.fConcerns,
  });

  factory FamilyContext.fromJson(Map<String, dynamic> json) => FamilyContext(
        fIncome: json['fIncome'] as String?,
        fStable: json['fStable'] as String?,
        fEdu: json['fEdu'] as String?,
        fLocReq: json['fLocReq'] as String?,
        fConcerns: (json['fConcerns'] as List<dynamic>?)?.cast<String>(),
      );
}

class RecommendedTrade {
  final String trade;
  final double score;
  final double placement;
  final double avgEarnings;
  final int nsqf;
  final int duration;
  final double cost;
  final bool verified;

  const RecommendedTrade({
    required this.trade,
    required this.score,
    required this.placement,
    required this.avgEarnings,
    required this.nsqf,
    required this.duration,
    required this.cost,
    required this.verified,
  });
}

class ToolsService {
  /// Classify concern text into categories (port of classifyConcern)
  static Future<Map<String, dynamic>> classifyConcern(String text) async {
    const categories = ['income', 'job', 'social', 'growth', 'safety', 'edu', 'cost', 'localjobs'];

    final prompt = 'Classify the parent/student concern text into one or more categories: ${categories.join(', ')}.\n'
        'Text: "$text"\n'
        'Return JSON: {"categories": ["category_name"], "confidence": 0.0 to 1.0}';

    final res = await GeminiServiceBackend().generateJSON(prompt, text);
    if (res != null && res['categories'] is List) {
      final cats = (res['categories'] as List).map((e) => e.toString()).where(categories.contains).toList();
      if (cats.isNotEmpty) {
        return {
          'categories': cats,
          'confidence': (res['confidence'] as num?)?.toDouble() ?? 0.85,
        };
      }
    }

    // Keyword fallback
    final lower = text.toLowerCase();
    final matched = <String>[];
    if (RegExp(r'salary|earn|income|money|पगार|कमाई').hasMatch(lower)) matched.add('income');
    if (RegExp(r'job|placement|employ|नोकरी').hasMatch(lower)) matched.add('job');
    if (RegExp(r'respect|society|relative|status|समाज').hasMatch(lower)) matched.add('social');
    if (RegExp(r'growth|promot|future|प्रगती').hasMatch(lower)) matched.add('growth');
    if (RegExp(r'safe|danger|accident|सुरक्षा').hasMatch(lower)) matched.add('safety');
    if (RegExp(r'degree|diploma|study|higher|education|शिक्षण').hasMatch(lower)) matched.add('edu');
    if (RegExp(r'fee|cost|afford|खर्च').hasMatch(lower)) matched.add('cost');
    if (RegExp(r'near|local|nearby|जवळ').hasMatch(lower)) matched.add('localjobs');

    return {
      'categories': matched.isNotEmpty ? matched : ['job'],
      'confidence': matched.isNotEmpty ? 0.9 : 0.5,
    };
  }

  static Future<GroundedResponse> toolRetrieveEvidence(
    String trade,
    String location,
    String topic,
    String question,
  ) async {
    final retrieved = await RetrievalService.retrieveEvidence(question, profileTrade: trade, profileLocation: location);
    final chunks = (retrieved['chunks'] as List).cast<RetrievedChunk>();
    return await VerificationService.runRAGPipeline(question, chunks, sessionId: null, trade: trade, location: location);
  }

  /// Recommend top-3 trades based on profile (port of recommendTrades)
  static Future<List<RecommendedTrade>> recommendTrades(Map<String, dynamic> profile) async {
    final res = await DatabaseService().query(
      'SELECT trade, location, placement_rate, avg_earnings, nsqf_level, duration_months, training_cost, min_education, source, data_date FROM outcomes',
    );

    if (res.rows.isEmpty) {
      return const [
        RecommendedTrade(trade: 'Electrician', score: 90, placement: 80, avgEarnings: 20000, nsqf: 4, duration: 12, cost: 9000, verified: true),
        RecommendedTrade(trade: 'Solar Technician', score: 85, placement: 82, avgEarnings: 19500, nsqf: 4, duration: 6, cost: 12000, verified: true),
        RecommendedTrade(trade: 'CNC Operator', score: 80, placement: 83, avgEarnings: 22500, nsqf: 4, duration: 9, cost: 18000, verified: true),
      ];
    }

    final sLoc = profile['sLoc'] as String?;
    final sMonths = profile['sMonths'];

    final tradeScoresMap = <String, RecommendedTrade>{};

    for (final r in res.rows) {
      final trade = r['trade'] as String;
      final location = r['location'] as String;
      final sMonthsNum = sMonths == null ? null : num.tryParse(sMonths.toString());
      final isLocMatch = sLoc != null && location.toLowerCase() == sLoc.toLowerCase();
      final isDurMatch = sMonthsNum != null &&
          (r['duration_months'] as num?) != null &&
          (r['duration_months'] as num).toDouble() <= sMonthsNum;

      var score = ((r['placement_rate'] as num?)?.toDouble() ?? 50) * 0.4 +
          (((r['avg_earnings'] as num?)?.toDouble() ?? 10000) / 500);
      if (isLocMatch) score += 20;
      if (isDurMatch) score += 10;

      final candidate = RecommendedTrade(
        trade: trade,
        placement: (r['placement_rate'] as num?)?.toDouble() ?? 0,
        avgEarnings: (r['avg_earnings'] as num?)?.toDouble() ?? 0,
        nsqf: (r['nsqf_level'] as num?)?.toInt() ?? 4,
        duration: (r['duration_months'] as num?)?.toInt() ?? 12,
        cost: (r['training_cost'] as num?)?.toDouble() ?? 0,
        verified: isLocMatch,
        score: score,
      );

      final existing = tradeScoresMap[trade];
      if (existing == null || score > existing.score) {
        tradeScoresMap[trade] = candidate;
      }
    }

    final sorted = tradeScoresMap.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(3).toList();
  }

  /// Compare vocational vs academic pathway (port of comparePathways)
  static Future<Map<String, dynamic>> comparePathways(String trade, String location) async {
    final res = await DatabaseService().query(
      'SELECT * FROM outcomes WHERE LOWER(trade) = LOWER(\$1) AND LOWER(location) = LOWER(\$2)',
      [trade, location],
    );

    final row = res.rows.isEmpty ? null : res.rows.first;

    final jobRoles = row?['job_roles'] as List<dynamic>? ?? [];

    return {
      'trade': trade,
      'location': location,
      'vocational': {
        'entry': row?['min_education'] as String? ?? '10th pass',
        'duration': row?['duration_months'] != null ? '${(row!['duration_months'] as num).toInt()} months' : '12 months',
        'initialRole': jobRoles.isNotEmpty ? jobRoles.first.toString() : 'Junior Technician',
        'furtherEdu': row?['further_education'] as String? ?? 'Polytechnic Diploma Lateral Entry',
        'placement': row?['placement_rate'] != null ? '${(row!['placement_rate'] as num)}% placement' : 'Data not available',
      },
      'academic': {
        'entry': '12th pass / Entrance Exam',
        'duration': '3 to 4 years',
        'initialRole': 'Graduate Trainee',
        'furtherEdu': 'Post-Graduation / Master Degree',
        'placement': 'Data not available',
      },
    };
  }

  /// Get career pathway steps for a trade (port of getPathway)
  static Future<Map<String, dynamic>> getPathway(String trade) async {
    final res = await DatabaseService().query(
      'SELECT * FROM outcomes WHERE LOWER(trade) = LOWER(\$1) LIMIT 1',
      [trade],
    );
    final row = res.rows.isEmpty ? null : res.rows.first;

    return {
      'trade': trade,
      'nsqf_level': row?['nsqf_level'] as num? ?? 4,
      'steps': row?['progression'] as List<dynamic>? ??
          ['Training (ITI)', 'Assistant', trade, 'Senior Technician', 'Supervisor'],
      'further_education': row?['further_education'] as String? ??
          'Diploma in Engineering (Lateral Entry), NSQF Level 5',
    };
  }

  /// Update concern status (port of updateConcernStatus)
  static Future<Map<String, dynamic>> updateConcernStatus(
    String sessionId,
    String category,
    String status, {
    Map<String, dynamic> evidenceUsed = const {},
  }) async {
    // Ensure session exists in DB
    await DatabaseService().query(
      'INSERT INTO sessions (id, status, created_at, updated_at) VALUES (\$1, \'active\', NOW(), NOW())',
      [sessionId],
    );

    final existing = await DatabaseService().query(
      'SELECT id FROM concerns WHERE session_id = \$1 AND category = \$2',
      [sessionId, category],
    );

    final resolvedAt = status == 'resolved' ? DateTime.now().toIso8601String() : null;

    if (existing.rowCount > 0) {
      await DatabaseService().query(
        'UPDATE concerns SET status = \$1, resolved_at = \$2, evidence_used = \$3 WHERE session_id = \$4 AND category = \$5',
        [status, resolvedAt, jsonEncode(evidenceUsed), sessionId, category],
      );
    } else {
      await DatabaseService().query(
        'INSERT INTO concerns (id, session_id, category, status, asked_at, resolved_at, evidence_used) VALUES (\$1, \$2, \$3, \$4, NOW(), \$5, \$6)',
        [
          'c_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}',
          sessionId,
          category,
          status,
          resolvedAt,
          jsonEncode(evidenceUsed),
        ],
      );
    }

    return {'success': true, 'sessionId': sessionId, 'category': category, 'status': status};
  }

  /// Create escalation record (port of createEscalation)
  static Future<Map<String, dynamic>> createEscalation(
    String sessionId,
    String reason, {
    List<dynamic> evidenceShown = const [],
  }) async {
    final escId = 'esc_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}';
    await DatabaseService().query(
      'INSERT INTO escalations (id, session_id, reason, status, evidence_shown, created_at, updated_at) VALUES (\$1, \$2, \$3, \'open\', \$4, NOW(), NOW())',
      [escId, sessionId, reason, jsonEncode(evidenceShown)],
    );

    await DatabaseService().query('UPDATE sessions SET status = \'escalated\' WHERE id = \$1', [sessionId]);
    return {'success': true, 'escalationId': escId};
  }

  /// Generate family decision summary (port of generateFamilySummary)
  static Future<Map<String, dynamic>> generateFamilySummary(String sessionId) async {
    final sessRes = await DatabaseService().query('SELECT * FROM sessions WHERE id = \$1', [sessionId]);
    if (sessRes.rowCount == 0) {
      throw Exception('Session $sessionId not found');
    }

    final sess = sessRes.rows.first;
    final concernsRes = await DatabaseService().query('SELECT * FROM concerns WHERE session_id = \$1', [sessionId]);

    final profile = (sess['student_profile'] as Map<String, dynamic>? ?? {});
    final concerns = concernsRes.rows;

    final raised = concerns.map((c) => c['category'].toString()).toList();
    final resolved = concerns.where((c) => c['status'] == 'resolved').map((c) => c['category'].toString()).toList();
    final unresolved = concerns
        .where((c) => c['status'] == 'unresolved' || c['status'] == 'escalated')
        .map((c) => c['category'].toString())
        .toList();

    return {
      'sessionId': sessionId,
      'date': DateTime.now().toIso8601String().split('T').first,
      'student': profile['sName'] ?? 'Student',
      'location': profile['sLoc'] ?? 'Nagpur',
      'interest': profile['sInterest'] ?? 'electrical',
      'goal': profile['sGoal'] ?? 'Steady employment',
      'concernsRaised': raised,
      'concernsResolved': resolved,
      'concernsUnresolved': unresolved,
      'nextStep': unresolved.isNotEmpty || sess['status'] == 'escalated'
          ? 'Human counsellor session recommended to resolve remaining family concerns.'
          : 'Family is aligned to discuss selected vocational pathway at home.',
    };
  }

  static String _randomSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

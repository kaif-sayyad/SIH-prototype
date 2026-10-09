import '../auth_service.dart';
import '../config_service.dart';
import '../database_service.dart';
import '../gemini_service.dart';
import '../rag/ingest_service.dart';

/// Port of backend API routes:
/// - GET  /api/admin/analytics
/// - POST /api/admin/demo-mode
/// - POST /api/admin/test-ai
/// - POST /api/dataset/reindex
/// - POST /api/dataset/upload

class AdminApi {
  static final AuthServiceBackend _auth = AuthServiceBackend();

  static Future<UserRecord> _requireAdmin(String token) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null || auth.role != 'admin') {
      throw const ApiException('Unauthorized: Admin role required', statusCode: 403);
    }
    return UserRecord(id: auth.uid, role: UserRole.admin, createdAt: '');
  }

  /// GET /api/admin/analytics
  static Future<Map<String, dynamic>> getAnalytics(String token, {String? district, String? format}) async {
    await _requireAdmin(token);

    final db = await DatabaseService().getDb();

    var sessions = [...db.sessions];
    var concerns = [...db.concerns];
    var escalations = [...db.escalations];

    if (district != null && district.isNotEmpty) {
      sessions = sessions
          .where((s) => (s.studentProfile['sLoc'] as String?)?.toLowerCase() == district.toLowerCase())
          .toList();
      final sessIds = sessions.map((s) => s.id).toSet();
      concerns = concerns.where((c) => sessIds.contains(c.sessionId)).toList();
      escalations = escalations.where((e) => sessIds.contains(e.sessionId)).toList();
    }

    final totalFamilies = sessions.length;
    final completedSessions =
        sessions.where((s) => s.status == 'completed' || s.currentStep == 7).length;
    final escalatedSessions = escalations.length;
    final aiResolved = (totalFamilies - escalatedSessions).clamp(0, 1 << 31) as int;

    final concernCounts = <String, int>{};
    for (final c in concerns) {
      concernCounts[c.category] = (concernCounts[c.category] ?? 0) + 1;
    }

    final geoCounts = <String, int>{};
    for (final s in sessions) {
      final loc = (s.studentProfile['sLoc'] as String?) ?? 'Unknown';
      geoCounts[loc] = (geoCounts[loc] ?? 0) + 1;
    }

    final districtResistanceMap = <String, Map<String, int>>{};
    for (final c in concerns) {
      final sessMatches = db.sessions.where((s) => s.id == c.sessionId).toList();
      final loc = sessMatches.isNotEmpty
          ? (sessMatches.first.studentProfile['sLoc'] as String? ?? 'Nagpur')
          : 'Nagpur';
      districtResistanceMap.putIfAbsent(loc, () => {'total': 0, 'unresolved': 0});
      districtResistanceMap[loc]!['total'] = districtResistanceMap[loc]!['total']! + 1;
      if (c.status == 'unresolved' || c.status == 'escalated') {
        districtResistanceMap[loc]!['unresolved'] = districtResistanceMap[loc]!['unresolved']! + 1;
      }
    }

    final resistanceByDistrict = districtResistanceMap.entries.map((entry) {
      final total = entry.value['total']!;
      final unresolved = entry.value['unresolved']!;
      return {
        'district': entry.key,
        'totalConcerns': total,
        'unresolvedCount': unresolved,
        'resistanceRate': total > 0 ? ((unresolved / total) * 100).round() : 0,
      };
    }).toList()
      ..sort((a, b) => (b['resistanceRate'] as int).compareTo(a['resistanceRate'] as int));

    final topConcernsByDistrict = <String, Map<String, int>>{};
    for (final c in concerns) {
      final sessMatches = db.sessions.where((s) => s.id == c.sessionId).toList();
      final loc = sessMatches.isNotEmpty
          ? (sessMatches.first.studentProfile['sLoc'] as String? ?? 'Nagpur')
          : 'Nagpur';
      topConcernsByDistrict.putIfAbsent(loc, () => {});
      topConcernsByDistrict[loc]![c.category] = (topConcernsByDistrict[loc]![c.category] ?? 0) + 1;
    }

    final shiftCounts = {'shifted_positive': 0, 'unchanged': 0, 'shifted_negative': 0};
    for (final s in db.sentimentShifts) {
      if (shiftCounts.containsKey(s.shift)) {
        shiftCounts[s.shift] = shiftCounts[s.shift]! + 1;
      }
    }

    final totalConcerns = concerns.length;
    final resolvedConcerns = concerns.where((c) => c.status == 'resolved').length;
    final resolutionRate =
        totalConcerns > 0 ? ((resolvedConcerns / totalConcerns) * 100).round() : 0;

    final funnel = {
      'registered': db.users.where((u) => u.role == UserRole.family).length,
      'profileComplete': sessions.where((s) => s.studentProfile['sName'] != null).length,
      'parentJoined': sessions
          .where((s) => s.messages.any((m) => m.sender == 'parent'))
          .length,
      'counsellingDone': sessions.where((s) => (s.currentStep ?? 1) >= 4).length,
      'summaryGenerated': sessions.where((s) => (s.currentStep ?? 1) >= 7).length,
      'escalated': escalations.length,
    };

    final knowledgeStats = {
      'filesLoaded': ['outcomes.csv', 'academic_path.csv', 'guides/faq.md'],
      'chunkCount': db.outcomeChunks.length,
      'embeddingStatus': (await ConfigService.hasValidGeminiKey())
          ? 'Active (Gemini Flash)'
          : 'Offline / Keyword Fallback',
      'datasetVersion': db.datasets.isEmpty ? 'knowledge_v1' : db.datasets.first.version,
      'validationReport': db.datasets.isEmpty
          ? {'totalRows': 18, 'validRows': 18, 'rejectedRows': 0}
          : {
              'totalRows': db.datasets.first.totalRows,
              'validRows': db.datasets.first.validRows,
              'rejectedRows': db.datasets.first.rejectedRows,
            },
    };

    final analyticsData = {
      'summary': {
        'totalFamilies': totalFamilies,
        'completedSessions': completedSessions,
        'escalatedSessions': escalatedSessions,
        'aiResolved': aiResolved,
        'resolutionRate': resolutionRate,
      },
      'concernPercentages': concernCounts,
      'geographicAnalysis': geoCounts,
      'resistanceByDistrict': resistanceByDistrict,
      'topConcernsByDistrict': topConcernsByDistrict,
      'sentimentShift': shiftCounts,
      'funnel': funnel,
      'dataCoverageGaps': db.coverageGaps.map((g) => g.toJson()).toList(),
      'knowledgeStats': knowledgeStats,
    };

    if (format == 'csv') {
      final csvLines = [
        'Metric,Value',
        'Total Families Counselled,$totalFamilies',
        'Completed Sessions,$completedSessions',
        'AI Resolved Sessions,$aiResolved',
        'Human Escalations,$escalatedSessions',
        'Concern Resolution Rate,$resolutionRate%',
        '',
        'District,Total Concerns,Unresolved Concerns,Resistance Rate (%)',
        ...resistanceByDistrict
            .map((r) => '${r['district']},${r['totalConcerns']},${r['unresolvedCount']},${r['resistanceRate']}%'),
      ];
      return {'success': true, 'csv': csvLines.join('\n')};
    }

    return {
      'success': true,
      'analytics': analyticsData,
    };
  }

  /// POST /api/admin/demo-mode — generate 8 sample demo counselling sessions
  static Future<Map<String, dynamic>> demoMode(String token) async {
    await _requireAdmin(token);

    final db = await DatabaseService().getDb();

    const sampleDistricts = ['Nagpur', 'Pune', 'Mumbai'];
    const sampleTrades = ['Electrician', 'Solar Technician', 'CNC Operator', 'Plumber', 'Welder'];
    const sampleConcerns = ['income', 'job', 'social', 'growth', 'safety', 'edu', 'cost', 'localjobs'];

    final now = DateTime.now().toIso8601String();
    final ts = DateTime.now().millisecondsSinceEpoch;

    for (var i = 1; i <= 8; i++) {
      final studentId = 'usr_demo_${ts}_$i';
      final sessionId = 'sess_demo_${ts}_$i';
      final loc = sampleDistricts[i % sampleDistricts.length];
      final trade = sampleTrades[i % sampleTrades.length];

      db.users.add(UserRecord(
        id: studentId,
        name: 'Demo Student $i',
        phone: '987654321$i',
        role: UserRole.family,
        parentAccessCode: 'SP-DEMO-${1000 + i}',
        createdAt: now,
      ));

      final isCompleted = i % 2 == 0;
      final session = SessionRecord(
        id: sessionId,
        userId: studentId,
        studentId: studentId,
        studentProfile: {
          'sName': 'Demo Student $i',
          'sEdu': '10th',
          'sLoc': loc,
          'sInterest': trade.toLowerCase(),
          'sInterestTrade': trade,
        },
        familyContext: {
          'fIncome': '10k_20k',
          'fConcerns': ['income', 'job'],
        },
        status: isCompleted ? 'completed' : (i % 3 == 0 ? 'escalated' : 'active'),
        currentStep: isCompleted ? 7 : 4,
        messages: [
          ChatMessageRecord(
            sender: 'student',
            text: 'What are the job prospects for $trade in $loc?',
            timestamp: now,
          ),
          ChatMessageRecord(
            sender: 'ai',
            text: 'In $loc, $trade training has a high placement rate and average monthly earnings of ₹18,000 to ₹22,000 (Source: MSDE Survey 2026).',
            timestamp: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      db.sessions.add(session);

      final cCat = sampleConcerns[i % sampleConcerns.length];
      final isResolved = i % 3 != 0;

      db.concerns.add(ConcernRecord(
        id: 'c_demo_${sessionId}_$cCat',
        sessionId: sessionId,
        category: cCat,
        status: isResolved ? 'resolved' : 'unresolved',
        askedAt: now,
        resolvedAt: isResolved ? now : null,
      ));

      db.sentimentShifts.add(SentimentShiftRecord(
        id: 'shift_demo_$i',
        sessionId: sessionId,
        concernCategory: cCat,
        district: loc,
        initialSentiment: 'hesitant',
        finalSentiment: isResolved ? 'positive' : 'negative',
        shift: isResolved ? 'shifted_positive' : 'shifted_negative',
        updatedAt: now,
      ));

      if (!isResolved) {
        db.escalations.add(EscalationRecord(
          id: 'esc_demo_$i',
          sessionId: sessionId,
          studentName: 'Demo Student $i',
          reason: 'Unresolved parent concern regarding $cCat in $loc',
          status: 'open',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    await DatabaseService().saveDb();

    return {
      'success': true,
      'message': 'Generated 8 sample demo counselling sessions with analytics data.',
    };
  }

  /// POST /api/admin/test-ai
  static Future<Map<String, dynamic>> testAi(String token) async {
    await _requireAdmin(token);
    return await GeminiServiceBackend().testGeminiConnection();
  }

  /// POST /api/dataset/reindex
  static Future<Map<String, dynamic>> reindex(String token) async {
    await _requireAdmin(token);
    final reloadResult = await IngestService.loadKnowledgeFiles();
    return {
      'success': true,
      'message': 'Knowledge files reloaded successfully.',
      ...reloadResult,
    };
  }

  /// POST /api/dataset/upload
  static Future<Map<String, dynamic>> uploadDataset({
    required String token,
    required String filename,
    required String csvContent,
    String? version,
  }) async {
    await _requireAdmin(token);

    final ver = version ?? 'v_${DateTime.now().millisecondsSinceEpoch}';
    final rows = IngestService.parseCsvRows(csvContent);
    final ingestRes = await IngestService.ingestDataset(ver, filename, rows);

    return {
      'success': true,
      'message': 'Uploaded and ingested ${ingestRes.validRows} valid rows from $filename.',
      'result': {
        'datasetVersion': ingestRes.datasetVersion,
        'totalRows': ingestRes.totalRows,
        'validRows': ingestRes.validRows,
        'rejectedRows': ingestRes.rejectedRows,
        'chunksCreated': ingestRes.chunksCreated,
      },
    };
  }
}

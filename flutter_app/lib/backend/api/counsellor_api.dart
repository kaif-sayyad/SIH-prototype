import '../agent/runner_service.dart';
import '../auth_service.dart';
import '../database_service.dart';

/// Port of backend API routes:
/// - GET  /api/counsellor/inbox
/// - POST /api/counsellor/inbox
/// - POST /api/counsellor/query

class CounsellorApi {
  static final AuthServiceBackend _auth = AuthServiceBackend();

  /// GET /api/counsellor/inbox
  static Future<Map<String, dynamic>> getInbox(String token) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null || (auth.role != 'counsellor' && auth.role != 'admin')) {
      throw const ApiException('Unauthorized: Counsellor or Admin role required', statusCode: 403);
    }

    final db = await DatabaseService().getDb();
    final escalations = db.escalations.map((esc) {
      final sessionMatches = db.sessions.where((s) => s.id == esc.sessionId).toList();
      final session = sessionMatches.isEmpty ? null : sessionMatches.first;
      final studentMatches = session != null
          ? db.users.where((u) => u.id == session.studentId || u.id == session.userId).toList()
          : <UserRecord>[];
      final student = studentMatches.isEmpty ? null : studentMatches.first;
      final concerns = db.concerns.where((c) => c.sessionId == esc.sessionId).toList();

      return {
        ...esc.toJson(),
        'studentName': student?.name ?? session?.studentProfile['sName'] ?? 'Student',
        'studentPhone': student?.phone ?? 'N/A',
        'studentProfile': session?.studentProfile ?? {},
        'familyContext': session?.familyContext ?? {},
        'concerns': concerns.map((c) => c.toJson()).toList(),
        'messages': session?.messages.map((m) => m.toJson()).toList() ?? [],
      };
    }).toList();

    return {
      'success': true,
      'escalations': escalations,
    };
  }

  /// POST /api/counsellor/inbox
  static Future<Map<String, dynamic>> updateInbox({
    required String token,
    required String escalationId,
    required String status,
    String? counsellorNotes,
  }) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null || (auth.role != 'counsellor' && auth.role != 'admin')) {
      throw const ApiException('Unauthorized', statusCode: 403);
    }

    if (escalationId.isEmpty || status.isEmpty) {
      throw const ApiException('escalationId and status are required');
    }

    final db = await DatabaseService().getDb();
    final matches = db.escalations.where((e) => e.id == escalationId).toList();
    if (matches.isEmpty) {
      throw const ApiException('Escalation record not found', statusCode: 404);
    }

    final esc = matches.first;
    esc.status = status;
    esc.counsellorId = auth.uid;
    if (counsellorNotes != null) esc.counsellorNotes = counsellorNotes;
    esc.updatedAt = DateTime.now().toIso8601String();

    if (status == 'resolved') {
      final sessionMatches = db.sessions.where((s) => s.id == esc.sessionId).toList();
      if (sessionMatches.isNotEmpty) {
        sessionMatches.first.status = 'completed';
        sessionMatches.first.updatedAt = DateTime.now().toIso8601String();
      }
    }

    await DatabaseService().saveDb();

    return {
      'success': true,
      'escalation': esc.toJson(),
    };
  }

  /// POST /api/counsellor/query — run the agentic counsellor loop
  static Future<Map<String, dynamic>> query({
    required String token,
    String? sessionId,
    required String userMessage,
    Map<String, dynamic>? profile,
    String language = 'en',
  }) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    if (userMessage.trim().isEmpty) {
      throw const ApiException('userMessage is required');
    }

    final targetSessionId =
        sessionId ?? auth.sessionId ?? (auth.studentId != null ? 'sess_${auth.studentId}' : 'sess_${auth.uid}');

    final agentResp = await AgentRunner.runCounsellorAgent(AgentTurnRequest(
      sessionId: targetSessionId,
      userMessage: userMessage.trim(),
      profile: profile ?? {},
      language: language == 'mr' ? 'mr' : 'en',
    ));

    final db = await DatabaseService().getDb();
    final sessionMatches = db.sessions.where((s) => s.id == targetSessionId).toList();
    if (sessionMatches.isNotEmpty) {
      final session = sessionMatches.first;
      final senderRole = auth.role == 'parent' ? 'parent' : 'student';

      session.messages.add(ChatMessageRecord(
        sender: senderRole,
        text: userMessage.trim(),
        timestamp: DateTime.now().toIso8601String(),
      ));

      session.messages.add(ChatMessageRecord(
        sender: 'ai',
        text: agentResp.answer,
        timestamp: DateTime.now().toIso8601String(),
        citation: agentResp.citations.join('; '),
      ));

      session.updatedAt = DateTime.now().toIso8601String();
      await DatabaseService().saveDb();
    }

    return {
      'success': true,
      ...agentResp.toJson(),
    };
  }
}

import '../auth_service.dart';
import '../database_service.dart';

/// Port of backend API routes:
/// - GET /api/session
/// - POST /api/session

class SessionApi {
  static final AuthServiceBackend _auth = AuthServiceBackend();

  /// GET /api/session
  static Future<Map<String, dynamic>> getSession(String token, {String? sessionIdParam}) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    final db = await DatabaseService().getDb();

    String? targetSessionId = sessionIdParam ?? auth.sessionId;

    if (targetSessionId == null && auth.studentId != null) {
      targetSessionId = 'sess_${auth.studentId}';
    }

    if (targetSessionId == null) {
      throw const ApiException('Session ID required', statusCode: 400);
    }

    SessionRecord? session;
    final matches = db.sessions
        .where((s) => s.id == targetSessionId || s.studentId == auth.studentId || s.userId == auth.uid)
        .toList();
    if (matches.isNotEmpty) {
      session = matches.first;
    }

    if (session == null) {
      session = SessionRecord(
        id: targetSessionId,
        userId: auth.uid,
        studentId: auth.studentId ?? auth.uid,
        studentProfile: {},
        familyContext: {},
        recommendations: [],
        pathway: {},
        status: 'active',
        currentStep: 2,
        messages: [],
      );
      db.sessions.add(session);
      await DatabaseService().saveDb();
    }

    if ((auth.role == 'family' || auth.role == 'parent') && auth.studentId != null) {
      if (session.studentId != auth.studentId && session.userId != auth.studentId) {
        throw const ApiException('Forbidden: Cannot access another student session', statusCode: 403);
      }
    }

    final concerns = db.concerns.where((c) => c.sessionId == session!.id).toList();

    return {
      'success': true,
      'session': session.toJson(),
      'concerns': concerns.map((c) => c.toJson()).toList(),
    };
  }

  /// POST /api/session
  static Future<Map<String, dynamic>> saveSession(
    String token, {
    String? sessionId,
    Map<String, dynamic>? studentProfile,
    Map<String, dynamic>? familyContext,
    int? currentStep,
    List<dynamic>? recommendations,
    Map<String, dynamic>? pathway,
    Map<String, dynamic>? message,
  }) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    final db = await DatabaseService().getDb();
    final targetSessionId =
        sessionId ?? auth.sessionId ?? (auth.studentId != null ? 'sess_${auth.studentId}' : 'sess_${auth.uid}');

    SessionRecord? session;
    final matches = db.sessions
        .where((s) => s.id == targetSessionId || s.studentId == auth.studentId || s.userId == auth.uid)
        .toList();
    if (matches.isNotEmpty) {
      session = matches.first;
    }

    if (session == null) {
      session = SessionRecord(
        id: targetSessionId,
        userId: auth.uid,
        studentId: auth.studentId ?? auth.uid,
        studentProfile: studentProfile ?? {},
        familyContext: familyContext ?? {},
        recommendations: recommendations ?? [],
        pathway: pathway ?? {},
        status: 'active',
        currentStep: currentStep ?? 2,
        messages: [],
      );
      db.sessions.add(session);
    } else {
      if (studentProfile != null) {
        session.studentProfile = {...session.studentProfile, ...studentProfile};
      }
      if (familyContext != null) {
        session.familyContext = {...session.familyContext, ...familyContext};
      }
      if (currentStep != null) session.currentStep = currentStep;
      if (recommendations != null) session.recommendations = recommendations;
      if (pathway != null) session.pathway = pathway;
      session.updatedAt = DateTime.now().toIso8601String();
    }

    if (message != null) {
      session.messages.add(ChatMessageRecord(
        sender: (message['sender'] as String?) ?? (auth.role == 'parent' ? 'parent' : 'student'),
        text: (message['text'] as String?) ?? '',
        timestamp: DateTime.now().toIso8601String(),
        citation: message['citation'] as String?,
      ));
    }

    await DatabaseService().saveDb();

    return {
      'success': true,
      'sessionId': session.id,
      'session': session.toJson(),
    };
  }
}

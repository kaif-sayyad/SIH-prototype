import 'dart:math';

import '../agent/tools_service.dart';
import '../auth_service.dart';
import '../database_service.dart';

/// Port of backend API route:
/// - POST /api/concerns/resolve
///   (Yes / Partly / No family feedback loop with sentiment shift tracking)

class ConcernsApi {
  static final AuthServiceBackend _auth = AuthServiceBackend();

  static Future<Map<String, dynamic>> resolve({
    required String token,
    required String sessionId,
    required String concernCategory,
    required String feedback, // 'yes' | 'partly' | 'no'
  }) async {
    final user = await _auth.verifyAuthToken(token);
    if (user == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    if (sessionId.isEmpty || concernCategory.isEmpty || feedback.isEmpty) {
      throw const ApiException('sessionId, concernCategory, feedback required');
    }

    final db = await DatabaseService().getDb();
    final matches = db.sessions.where((s) => s.id == sessionId).toList();
    final district = matches.isNotEmpty ? (matches.first.studentProfile['sLoc'] as String? ?? 'Nagpur') : 'Nagpur';

    String newStatus; // 'resolved' | 'unresolved' | 'escalated'
    String shift; // 'shifted_positive' | 'unchanged' | 'shifted_negative'

    if (feedback == 'yes') {
      newStatus = 'resolved';
      shift = 'shifted_positive';
    } else if (feedback == 'partly') {
      newStatus = 'unresolved';
      shift = 'unchanged';
    } else {
      newStatus = 'unresolved';
      shift = 'shifted_negative';
      await ToolsService.createEscalation(
        sessionId,
        "Family feedback: Concern '$concernCategory' marked '$feedback' (unresolved).",
      );
    }

    await ToolsService.updateConcernStatus(sessionId, concernCategory, newStatus);

    db.sentimentShifts.add(SentimentShiftRecord(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}',
      sessionId: sessionId,
      concernCategory: concernCategory,
      district: district,
      initialSentiment: feedback == 'yes' ? 'hesitant' : 'negative',
      finalSentiment: feedback == 'yes' ? 'positive' : (feedback == 'partly' ? 'hesitant' : 'negative'),
      shift: shift,
      updatedAt: DateTime.now().toIso8601String(),
    ));
    await DatabaseService().saveDb();

    return {
      'success': true,
      'sessionId': sessionId,
      'concernCategory': concernCategory,
      'status': newStatus,
      'shift': shift,
      'escalated': feedback != 'yes',
    };
  }

  static String _randomSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

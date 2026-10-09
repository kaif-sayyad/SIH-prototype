import '../auth_service.dart';
import '../database_service.dart';

/// Port of backend API routes:
/// - POST /api/auth/register
/// - POST /api/auth/login
/// - GET/POST /api/auth/parent-code

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, {this.statusCode = 400});

  @override
  String toString() => message;
}

class AuthApi {
  static final AuthServiceBackend _auth = AuthServiceBackend();

  /// POST /api/auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    String language = 'en',
    bool consent = true,
  }) async {
    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      throw const ApiException('Name, mobile number, and password are required');
    }
    if (phone.length < 10) {
      throw const ApiException('Valid 10-digit mobile number required');
    }
    if (!consent) {
      throw const ApiException('Consent is required to proceed');
    }

    final result = await _auth.registerStudent(
      name: name,
      phone: phone,
      password: password,
      language: language,
      consent: consent,
    );

    final token = await _auth.createSessionToken(AuthSessionPayload(
      uid: result.user.id,
      role: 'family',
      studentId: result.user.id,
      sessionId: result.session.id,
      name: result.user.name ?? 'Student',
    ));

    return {
      'success': true,
      'token': token,
      'user': {
        'id': result.user.id,
        'name': result.user.name,
        'phone': result.user.phone,
        'role': result.user.role.toString().split('.').last,
        'parentAccessCode': result.user.parentAccessCode,
      },
      'session': result.session.toJson(),
      'parentAccessCode': result.parentAccessCode,
    };
  }

  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login({
    String loginType = 'student',
    String? phone,
    String? password,
    String? parentAccessCode,
    String? parentName,
    String? email,
  }) async {
    if (loginType == 'parent') {
      if (parentAccessCode == null || parentAccessCode.isEmpty || parentName == null || parentName.isEmpty) {
        throw const ApiException('Parent Access Code and Parent Name are required');
      }

      final result = await _auth.loginParent(parentAccessCode, parentName);
      final token = await _auth.createSessionToken(AuthSessionPayload(
        uid: 'parent_${result.user.id}',
        role: 'parent',
        studentId: result.user.id,
        sessionId: result.session.id,
        parentName: parentName,
      ));

      return {
        'success': true,
        'token': token,
        'role': 'parent',
        'student': {
          'id': result.user.id,
          'name': result.user.name,
          'parentAccessCode': result.user.parentAccessCode,
        },
        'session': result.session.toJson(),
      };
    }

    if (loginType == 'admin') {
      final user = await _auth.loginAdmin(email ?? phone ?? '', password ?? '');
      final token = await _auth.createSessionToken(AuthSessionPayload(
        uid: user.id,
        role: 'admin',
      ));
      return {
        'success': true,
        'token': token,
        'role': 'admin',
        'user': user.toJson(),
      };
    }

    if (loginType == 'counsellor') {
      final user = await _auth.loginCounsellor(email ?? phone ?? '', password ?? '');
      final token = await _auth.createSessionToken(AuthSessionPayload(
        uid: user.id,
        role: 'counsellor',
      ));
      return {
        'success': true,
        'token': token,
        'role': 'counsellor',
        'user': user.toJson(),
      };
    }

    if (phone == null || phone.isEmpty || password == null || password.isEmpty) {
      throw const ApiException('Mobile number and password are required');
    }

    final result = await _auth.loginStudent(phone, password);
    final token = await _auth.createSessionToken(AuthSessionPayload(
      uid: result.user.id,
      role: 'family',
      studentId: result.user.id,
      sessionId: result.session.id,
      name: result.user.name ?? 'Student',
    ));

    return {
      'success': true,
      'token': token,
      'role': 'family',
      'user': {
        'id': result.user.id,
        'name': result.user.name,
        'phone': result.user.phone,
        'role': result.user.role.toString().split('.').last,
        'parentAccessCode': result.user.parentAccessCode,
      },
      'session': result.session.toJson(),
    };
  }

  /// GET /api/auth/parent-code
  static Future<Map<String, dynamic>> getParentCode(String token) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null || auth.studentId == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    final db = await DatabaseService().getDb();
    final matches = db.users.where((u) => u.id == auth.studentId).toList();
    if (matches.isEmpty) {
      throw const ApiException('Student not found', statusCode: 404);
    }

    return {
      'success': true,
      'parentAccessCode': matches.first.parentAccessCode,
    };
  }

  /// POST /api/auth/parent-code
  static Future<Map<String, dynamic>> regenerateParentCode(String token) async {
    final auth = await _auth.verifyAuthToken(token);
    if (auth == null || auth.studentId == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }

    final newCode = await _auth.regenerateParentAccessCode(auth.studentId!);
    return {
      'success': true,
      'parentAccessCode': newCode,
      'message': 'New Parent Access Code generated. Old code is immediately invalidated.',
    };
  }
}

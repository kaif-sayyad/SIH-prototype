import 'package:shared_preferences/shared_preferences.dart';
import '../backend/api/auth_api.dart';
import '../backend/auth_service.dart';
import '../backend/database_service.dart';
import '../models/user_session.dart';

/// Flutter facade over the converted backend auth API
/// (backend/api/auth_api.dart + backend/auth_service.dart).
///
/// Keeps the original UI-facing contract (registerStudent / loginStudent /
/// loginParent returning UserSession) while running the full backend
/// registration, parent-access-code, and session-token logic locally.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  static const _tokenKey = 'skillpath_auth_token';

  final AuthServiceBackend _backend = AuthServiceBackend();

  UserSession? _currentSession;
  String? _currentToken;

  UserSession? get currentSession => _currentSession;
  String? get currentToken => _currentToken;

  AuthService._internal();

  Future<void> init() async {
    await DatabaseService().init();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_tokenKey);
      if (_currentToken != null) {
        final payload = await _backend.verifyAuthToken(_currentToken);
        if (payload != null && payload.studentId != null) {
          _currentSession = await _loadSessionForStudent(payload.studentId!,
              role: payload.role, parentName: payload.parentName);
        }
      }
    } catch (_) {
      // No persisted session
    }
  }

  Future<void> _persistToken(String? token) async {
    _currentToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token);
      }
    } catch (_) {
      // SharedPreferences unavailable
    }
  }

  UserSession _mapToUserSession({
    required String sessionId,
    required String? phone,
    required String parentAccessCode,
    required String studentName,
    required String role,
    String? parentName,
    Map<String, dynamic> studentProfile = const {},
    Map<String, dynamic> familyContext = const {},
  }) {
    return UserSession(
      sessionId: sessionId,
      studentPhone: phone ?? '',
      parentAccessCode: parentAccessCode,
      studentName: studentName,
      parentName: parentName ?? 'Parent',
      role: role,
      profile: StudentProfile(
        name: studentProfile['sName'] as String? ?? studentName,
        education: studentProfile['sEdu'] as String? ?? '10th Pass',
        location: studentProfile['sLoc'] as String? ?? 'Nagpur',
        interest: studentProfile['sInterest'] as String? ?? 'Electrical / Technology',
        selectedTrade: studentProfile['sInterestTrade'] as String? ?? 'Electrician',
      ),
      familyContext: FamilyContext(
        incomeBracket: familyContext['fIncome'] as String? ?? '₹10,000 - ₹20,000 / month',
        activeConcerns: (familyContext['fConcerns'] as List<dynamic>?)
                ?.cast<String>() ??
            ['income', 'job'],
      ),
    );
  }

  Future<UserSession?> _loadSessionForStudent(String studentId,
      {String role = 'family', String? parentName}) async {
    final db = await DatabaseService().getDb();
    final userMatches = db.users.where((u) => u.id == studentId).toList();
    if (userMatches.isEmpty) return null;
    final user = userMatches.first;
    final sessionMatches = db.sessions
        .where((s) => s.studentId == user.id || s.userId == user.id)
        .toList();
    final session = sessionMatches.isNotEmpty ? sessionMatches.first : null;
    return _mapToUserSession(
      sessionId: session?.id ?? 'sess_${user.id}',
      phone: user.phone,
      parentAccessCode: user.parentAccessCode ?? '',
      studentName: user.name ?? 'Student',
      role: role,
      parentName: parentName,
      studentProfile: session?.studentProfile ?? {},
      familyContext: session?.familyContext ?? {},
    );
  }

  /// Register a student and generate the Parent Access Code.
  /// Mirrors POST /api/auth/register.
  Future<UserSession> registerStudent({
    required String name,
    required String phone,
    required String password,
  }) async {
    final result = await AuthApi.register(
      name: name,
      phone: phone,
      password: password,
      language: 'en',
      consent: true,
    );

    await _persistToken(result['token'] as String?);

    final user = result['user'] as Map<String, dynamic>;
    final session = result['session'] as Map<String, dynamic>;

    _currentSession = _mapToUserSession(
      sessionId: session['id'] as String,
      phone: user['phone'] as String?,
      parentAccessCode: (user['parentAccessCode'] as String?) ?? '',
      studentName: (user['name'] as String?) ?? 'Student',
      role: 'student',
      studentProfile: (session['student_profile'] as Map<String, dynamic>?) ?? {},
      familyContext: (session['family_context'] as Map<String, dynamic>?) ?? {},
    );
    return _currentSession!;
  }

  /// Student login via mobile + password.
  /// Mirrors POST /api/auth/login (loginType: student).
  Future<UserSession?> loginStudent({
    required String phone,
    required String password,
  }) async {
    final result = await AuthApi.login(
      loginType: 'student',
      phone: phone,
      password: password,
    );

    await _persistToken(result['token'] as String?);

    final user = result['user'] as Map<String, dynamic>;
    final session = result['session'] as Map<String, dynamic>;

    _currentSession = _mapToUserSession(
      sessionId: session['id'] as String,
      phone: user['phone'] as String?,
      parentAccessCode: (user['parentAccessCode'] as String?) ?? '',
      studentName: (user['name'] as String?) ?? 'Student',
      role: 'student',
      studentProfile: (session['student_profile'] as Map<String, dynamic>?) ?? {},
      familyContext: (session['family_context'] as Map<String, dynamic>?) ?? {},
    );
    return _currentSession;
  }

  /// Parent login via Parent Access Code + name.
  /// Mirrors POST /api/auth/login (loginType: parent).
  Future<UserSession?> loginParent({
    required String accessCode,
    required String parentName,
  }) async {
    try {
      final result = await AuthApi.login(
        loginType: 'parent',
        parentAccessCode: accessCode,
        parentName: parentName,
      );

      await _persistToken(result['token'] as String?);

      final student = result['student'] as Map<String, dynamic>;
      final session = result['session'] as Map<String, dynamic>;

      _currentSession = _mapToUserSession(
        sessionId: session['id'] as String,
        phone: null,
        parentAccessCode: (student['parentAccessCode'] as String?) ?? '',
        studentName: (student['name'] as String?) ?? 'Student',
        role: 'parent',
        parentName: parentName,
        studentProfile: (session['student_profile'] as Map<String, dynamic>?) ?? {},
        familyContext: (session['family_context'] as Map<String, dynamic>?) ?? {},
      );
      return _currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Admin login via email + password.
  /// Mirrors POST /api/auth/login (loginType: admin).
  Future<UserSession?> loginAdmin({
    required String email,
    required String password,
  }) async {
    final result = await AuthApi.login(
      loginType: 'admin',
      email: email,
      password: password,
    );
    await _persistToken(result['token'] as String?);
    _currentSession = UserSession(
      sessionId: 'admin_sess',
      studentPhone: '0000000000',
      parentAccessCode: 'ADMIN',
      role: 'admin',
    );
    return _currentSession;
  }

  /// Counsellor login via ID + PIN.
  /// Mirrors POST /api/auth/login (loginType: counsellor).
  Future<UserSession?> loginCounsellor({
    required String counsellorId,
    required String pin,
  }) async {
    final result = await AuthApi.login(
      loginType: 'counsellor',
      email: counsellorId,
      password: pin,
    );
    await _persistToken(result['token'] as String?);
    _currentSession = UserSession(
      sessionId: 'counsellor_sess',
      studentPhone: '0000000000',
      parentAccessCode: 'COUNSELLOR',
      role: 'counsellor',
    );
    return _currentSession;
  }

  /// Regenerate the Parent Access Code (invalidates the old code).
  /// Mirrors POST /api/auth/parent-code.
  Future<String?> regenerateParentCode() async {
    if (_currentToken == null) return null;
    final result = await AuthApi.regenerateParentCode(_currentToken!);
    final newCode = result['parentAccessCode'] as String?;
    if (newCode != null && _currentSession != null) {
      _currentSession!.parentAccessCode = newCode;
      final db = await DatabaseService().getDb();
      final payload = await _backend.verifyAuthToken(_currentToken);
      if (payload?.studentId != null) {
        final matches = db.users.where((u) => u.id == payload!.studentId).toList();
        if (matches.isNotEmpty) {
          matches.first.parentAccessCode = newCode;
        }
      }
      await DatabaseService().saveDb();
    }
    return newCode;
  }

  /// Fetch the current Parent Access Code for the logged-in student.
  Future<String?> fetchParentCode() async {
    if (_currentToken == null) return null;
    try {
      final result = await AuthApi.getParentCode(_currentToken!);
      return result['parentAccessCode'] as String?;
    } catch (_) {
      return null;
    }
  }

  void logout() {
    _currentSession = null;
    _persistToken(null);
  }
}

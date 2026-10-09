import 'dart:convert';
import 'dart:crypto';
import 'dart:math';

import '../database_service.dart';
import 'config_service.dart';

/// Port of backend lib/auth.ts — authentication, password hashing,
/// parent access codes, and signed session tokens.

class AuthSessionPayload {
  final String uid;
  final String role; // 'family' | 'parent' | 'counsellor' | 'admin'
  final String? studentId;
  final String? sessionId;
  final String? parentName;
  final String? name;

  const AuthSessionPayload({
    required this.uid,
    required this.role,
    this.studentId,
    this.sessionId,
    this.parentName,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'role': role,
        'studentId': studentId,
        'sessionId': sessionId,
        'parentName': parentName,
        'name': name,
      };

  factory AuthSessionPayload.fromJson(Map<String, dynamic> json) => AuthSessionPayload(
        uid: json['uid'] as String,
        role: json['role'] as String? ?? 'family',
        studentId: json['studentId'] as String?,
        sessionId: json['sessionId'] as String?,
        parentName: json['parentName'] as String?,
        name: json['name'] as String?,
      );
}

class AuthResult {
  final UserRecord user;
  final SessionRecord session;
  final String? parentAccessCode;

  const AuthResult({required this.user, required this.session, this.parentAccessCode});
}

class AuthServiceBackend {
  Future<String> _sessionSecret() async {
    return (await ConfigService.getConfig()).sessionSecret;
  }

  String hashPassword(String password, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(password));
    return digest.toString();
  }

  Future<String> hashPasswordWithConfig(String password) async {
    return hashPassword(password, await _sessionSecret());
  }

  Future<bool> verifyPassword(String password, String hash) async {
    return await hashPasswordWithConfig(password) == hash;
  }

  /// Generate a 10+ char unique parent access code like SP-7K3M-9QX2
  String generateParentAccessCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'SP-$part1-$part2';
  }

  /// Register student (port of registerStudent)
  Future<AuthResult> registerStudent({
    required String name,
    required String phone,
    required String password,
    String language = 'en',
    bool consent = true,
  }) async {
    final db = await DatabaseService().getDb();

    final existing = db.users.where((u) => u.phone == phone && u.role == UserRole.family).toList();
    if (existing.isNotEmpty) {
      throw Exception('A student account with this mobile number already exists');
    }

    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(4)}';
    final parentAccessCode = generateParentAccessCode();
    final now = DateTime.now().toIso8601String();

    final user = UserRecord(
      id: userId,
      name: name,
      phone: phone,
      role: UserRole.family,
      passwordHash: await hashPasswordWithConfig(password),
      parentAccessCode: parentAccessCode,
      language: language,
      consent: consent,
      consentAt: now,
      createdAt: now,
      failedAttempts: 0,
      lockedUntil: null,
    );

    db.users.add(user);

    // Create shared session
    final sessionId = 'sess_$userId';
    final session = SessionRecord(
      id: sessionId,
      userId: userId,
      studentId: userId,
      studentProfile: {
        'sName': name,
        'sEdu': '10th',
        'sLoc': 'Nagpur',
        'sInterest': 'electrical',
      },
      familyContext: {
        'fIncome': '10k_20k',
        'fConcerns': ['income', 'job'],
      },
      recommendations: [],
      pathway: {},
      status: 'active',
      currentStep: 2,
      messages: [],
      createdAt: now,
      updatedAt: now,
    );

    db.sessions.add(session);
    await DatabaseService().saveDb();

    return AuthResult(user: user, session: session, parentAccessCode: parentAccessCode);
  }

  /// Student Login (port of loginStudent)
  Future<AuthResult> loginStudent(String phone, String password) async {
    final db = await DatabaseService().getDb();
    final matches = db.users.where((u) => u.phone == phone && u.role == UserRole.family).toList();
    if (matches.isEmpty) {
      throw Exception('Invalid mobile number or password');
    }
    final user = matches.first;

    if (user.lockedUntil != null && DateTime.parse(user.lockedUntil!).isAfter(DateTime.now())) {
      throw Exception('Account locked due to multiple failed login attempts. Try again in 15 minutes.');
    }

    if (user.passwordHash == null || !(await verifyPassword(password, user.passwordHash!))) {
      user.failedAttempts = (user.failedAttempts ?? 0) + 1;
      if ((user.failedAttempts ?? 0) >= 5) {
        user.lockedUntil = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();
      }
      await DatabaseService().saveDb();
      throw Exception('Invalid mobile number or password');
    }

    user.failedAttempts = 0;
    user.lockedUntil = null;

    final session = _findOrCreateSessionFor(user);
    await DatabaseService().saveDb();
    return AuthResult(user: user, session: session);
  }

  /// Parent Login via Parent Access Code (port of loginParent)
  Future<AuthResult> loginParent(String parentAccessCode, String parentName) async {
    final db = await DatabaseService().getDb();
    final codeClean = parentAccessCode.trim().toUpperCase();

    final matches = db.users
        .where((u) => u.parentAccessCode == codeClean && u.role == UserRole.family)
        .toList();
    if (matches.isEmpty) {
      throw Exception('Invalid Parent Access Code');
    }
    final student = matches.first;

    if (student.lockedUntil != null &&
        DateTime.parse(student.lockedUntil!).isAfter(DateTime.now())) {
      throw Exception('Access locked due to multiple failed code entries. Try again in 15 minutes.');
    }

    final session = _findOrCreateSessionFor(student);
    await DatabaseService().saveDb();
    return AuthResult(user: student, session: session);
  }

  SessionRecord _findOrCreateSessionFor(UserRecord user) {
    final db = DatabaseService()._db!;
    final matches = db.sessions
        .where((s) => s.studentId == user.id || s.userId == user.id)
        .toList();
    if (matches.isNotEmpty) {
      return matches.first;
    }
    final now = DateTime.now().toIso8601String();
    final session = SessionRecord(
      id: 'sess_${user.id}',
      userId: user.id,
      studentId: user.id,
      studentProfile: {'sName': user.name},
      familyContext: {},
      status: 'active',
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
    db.sessions.add(session);
    return session;
  }

  /// Regenerate parent access code for a student (port of regenerateParentAccessCode)
  Future<String> regenerateParentAccessCode(String studentId) async {
    final db = await DatabaseService().getDb();
    final matches = db.users.where((u) => u.id == studentId).toList();
    if (matches.isEmpty) throw Exception('Student not found');

    final newCode = generateParentAccessCode();
    matches.first.parentAccessCode = newCode;
    await DatabaseService().saveDb();
    return newCode;
  }

  /// Admin Login (port of loginAdmin)
  Future<UserRecord> loginAdmin(String email, String pass) async {
    final cfg = await ConfigService.getConfig();
    if (email == cfg.adminEmail && pass == cfg.adminPassword) {
      return UserRecord(
        id: 'usr_admin',
        email: cfg.adminEmail,
        role: UserRole.admin,
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    throw Exception('Invalid admin email or password');
  }

  /// Counsellor Login (port of loginCounsellor)
  Future<UserRecord> loginCounsellor(String emailOrPhone, String pass) async {
    if (pass == 'counsellor123' || pass == 'admin123') {
      return UserRecord(
        id: 'usr_counsellor_1',
        email: emailOrPhone,
        name: 'Lead Counsellor',
        role: UserRole.counsellor,
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    throw Exception('Invalid counsellor password');
  }

  /// Sign session payload to token string (port of createSessionToken)
  Future<String> createSessionToken(AuthSessionPayload payload) async {
    final secret = await _sessionSecret();
    final raw = jsonEncode(payload.toJson());
    final hmac = Hmac(sha256, utf8.encode(secret));
    final signature = hmac.convert(utf8.encode(raw)).toString();
    return base64Encode(utf8.encode(jsonEncode({'payload': payload.toJson(), 'signature': signature})));
  }

  /// Verify authorization token (port of verifyAuthToken)
  Future<AuthSessionPayload?> verifyAuthToken(String? token) async {
    if (token == null || token.trim().isEmpty) return null;
    final t = token.trim();

    // Demo token fallbacks
    if (t.startsWith('demo-')) {
      final role = t.split('-').length > 1 ? t.split('-')[1] : 'family';
      return AuthSessionPayload(
        uid: t,
        role: role,
        studentId: t,
        sessionId: 'sess_$t',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(t))) as Map<String, dynamic>;
      final payload = AuthSessionPayload.fromJson(Map<String, dynamic>.from(decoded['payload'] as Map<String, dynamic>));
      final signature = decoded['signature'] as String?;
      final secret = await _sessionSecret();
      final hmac = Hmac(sha256, utf8.encode(secret));
      final expectedSig = hmac.convert(utf8.encode(jsonEncode(payload.toJson()))).toString();
      if (signature == expectedSig) {
        return payload;
      }
    } catch (err) {
      // Token verification failed
    }

    return null;
  }

  String _randomSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

/// Port of backend lib/db.ts — local JSON database with all SkillPath records.

enum UserRole { family, parent, counsellor, admin }

class UserRecord {
  final String id;
  final String? phone;
  final String? email;
  final String? name;
  final UserRole role;
  final String? passwordHash;
  final String? parentAccessCode;
  final String? language;
  final bool? consent;
  final String? consentAt;
  final String createdAt;
  int failedAttempts;
  String? lockedUntil;

  UserRecord({
    required this.id,
    this.phone,
    this.email,
    this.name,
    required this.role,
    this.passwordHash,
    this.parentAccessCode,
    this.language,
    this.consent,
    this.consentAt,
    required this.createdAt,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        name: json['name'] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.toString().split('.').last == (json['role'] as String? ?? 'family'),
          orElse: () => UserRole.family,
        ),
        passwordHash: json['password_hash'] as String?,
        parentAccessCode: json['parent_access_code'] as String?,
        language: json['language'] as String?,
        consent: json['consent'] as bool?,
        consentAt: json['consent_at'] as String?,
        createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        failedAttempts: (json['failed_attempts'] as num?)?.toInt() ?? 0,
        lockedUntil: json['locked_until'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'name': name,
        'role': role.toString().split('.').last,
        'password_hash': passwordHash,
        'parent_access_code': parentAccessCode,
        'language': language,
        'consent': consent,
        'consent_at': consentAt,
        'created_at': createdAt,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntil,
      };
}

class ChatMessageRecord {
  final String sender; // 'student' | 'parent' | 'ai' | 'counsellor'
  final String text;
  final String timestamp;
  final String? citation;

  ChatMessageRecord({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.citation,
  });

  factory ChatMessageRecord.fromJson(Map<String, dynamic> json) => ChatMessageRecord(
        sender: json['sender'] as String? ?? 'student',
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
        citation: json['citation'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'timestamp': timestamp,
        'citation': citation,
      };
}

class SessionRecord {
  final String id;
  final String? userId;
  final String? studentId;
  Map<String, dynamic> studentProfile;
  Map<String, dynamic> familyContext;
  List<dynamic> recommendations;
  Map<String, dynamic> pathway;
  String status; // 'active' | 'completed' | 'escalated'
  int? currentStep;
  List<ChatMessageRecord> messages;
  final String createdAt;
  String updatedAt;

  SessionRecord({
    required this.id,
    this.userId,
    this.studentId,
    Map<String, dynamic>? studentProfile,
    Map<String, dynamic>? familyContext,
    List<dynamic>? recommendations,
    Map<String, dynamic>? pathway,
    this.status = 'active',
    this.currentStep,
    List<ChatMessageRecord>? messages,
    String? createdAt,
    String? updatedAt,
  })  : studentProfile = studentProfile ?? {},
        familyContext = familyContext ?? {},
        recommendations = recommendations ?? [],
        pathway = pathway ?? {},
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        studentId: json['student_id'] as String?,
        studentProfile: (json['student_profile'] as Map<String, dynamic>?) ?? {},
        familyContext: (json['family_context'] as Map<String, dynamic>?) ?? {},
        recommendations: (json['recommendations'] as List<dynamic>?) ?? [],
        pathway: (json['pathway'] as Map<String, dynamic>?) ?? {},
        status: json['status'] as String? ?? 'active',
        currentStep: (json['current_step'] as num?)?.toInt(),
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => ChatMessageRecord.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'student_id': studentId,
        'student_profile': studentProfile,
        'family_context': familyContext,
        'recommendations': recommendations,
        'pathway': pathway,
        'status': status,
        'current_step': currentStep,
        'messages': messages.map((m) => m.toJson()).toList(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class ConcernRecord {
  final String id;
  final String sessionId;
  final String category;
  String status; // 'raised' | 'answered' | 'resolved' | 'unresolved' | 'escalated'
  String? sentiment;
  double? sentimentIntensity;
  final String askedAt;
  String? resolvedAt;
  Map<String, dynamic> evidenceUsed;

  ConcernRecord({
    required this.id,
    required this.sessionId,
    required this.category,
    this.status = 'raised',
    this.sentiment,
    this.sentimentIntensity,
    required this.askedAt,
    this.resolvedAt,
    Map<String, dynamic>? evidenceUsed,
  }) : evidenceUsed = evidenceUsed ?? {};

  factory ConcernRecord.fromJson(Map<String, dynamic> json) => ConcernRecord(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        category: json['category'] as String,
        status: json['status'] as String? ?? 'raised',
        sentiment: json['sentiment'] as String?,
        sentimentIntensity: (json['sentiment_intensity'] as num?)?.toDouble(),
        askedAt: json['asked_at'] as String? ?? DateTime.now().toIso8601String(),
        resolvedAt: json['resolved_at'] as String?,
        evidenceUsed: (json['evidence_used'] as Map<String, dynamic>?) ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'category': category,
        'status': status,
        'sentiment': sentiment,
        'sentiment_intensity': sentimentIntensity,
        'asked_at': askedAt,
        'resolved_at': resolvedAt,
        'evidence_used': evidenceUsed,
      };
}

class SentimentShiftRecord {
  final String id;
  final String sessionId;
  final String concernCategory;
  final String? district;
  final String initialSentiment;
  final String finalSentiment;
  final String shift; // 'shifted_positive' | 'unchanged' | 'shifted_negative'
  final String updatedAt;

  SentimentShiftRecord({
    required this.id,
    required this.sessionId,
    required this.concernCategory,
    this.district,
    required this.initialSentiment,
    required this.finalSentiment,
    required this.shift,
    required this.updatedAt,
  });

  factory SentimentShiftRecord.fromJson(Map<String, dynamic> json) => SentimentShiftRecord(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        concernCategory: json['concern_category'] as String,
        district: json['district'] as String?,
        initialSentiment: json['initial_sentiment'] as String? ?? 'neutral',
        finalSentiment: json['final_sentiment'] as String? ?? 'neutral',
        shift: json['shift'] as String? ?? 'unchanged',
        updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'concern_category': concernCategory,
        'district': district,
        'initial_sentiment': initialSentiment,
        'final_sentiment': finalSentiment,
        'shift': shift,
        'updated_at': updatedAt,
      };
}

class OutcomeRecord {
  final String id;
  final String trade;
  final String location;
  final String? provider;
  final double? placementRate;
  final double? avgEarnings;
  final double? earningsMin;
  final double? earningsMax;
  final int? nsqfLevel;
  final int? durationMonths;
  final double? trainingCost;
  final String? minEducation;
  final List<String> jobRoles;
  final List<String> progression;
  final String? furtherEducation;
  final String? source;
  final String? dataDate;
  final String? datasetVersion;
  final String? createdAt;

  OutcomeRecord({
    required this.id,
    required this.trade,
    required this.location,
    this.provider,
    this.placementRate,
    this.avgEarnings,
    this.earningsMin,
    this.earningsMax,
    this.nsqfLevel,
    this.durationMonths,
    this.trainingCost,
    this.minEducation,
    List<String>? jobRoles,
    List<String>? progression,
    this.furtherEducation,
    this.source,
    this.dataDate,
    this.datasetVersion,
    this.createdAt,
  })  : jobRoles = jobRoles ?? [],
        progression = progression ?? [];

  factory OutcomeRecord.fromJson(Map<String, dynamic> json) => OutcomeRecord(
        id: json['id'] as String,
        trade: json['trade'] as String,
        location: json['location'] as String,
        provider: json['provider'] as String?,
        placementRate: (json['placement_rate'] as num?)?.toDouble(),
        avgEarnings: (json['avg_earnings'] as num?)?.toDouble(),
        earningsMin: (json['earnings_min'] as num?)?.toDouble(),
        earningsMax: (json['earnings_max'] as num?)?.toDouble(),
        nsqfLevel: (json['nsqf_level'] as num?)?.toInt(),
        durationMonths: (json['duration_months'] as num?)?.toInt(),
        trainingCost: (json['training_cost'] as num?)?.toDouble(),
        minEducation: json['min_education'] as String?,
        jobRoles: (json['job_roles'] as List<dynamic>?)?.cast<String>() ?? [],
        progression: (json['progression'] as List<dynamic>?)?.cast<String>() ?? [],
        furtherEducation: json['further_education'] as String?,
        source: json['source'] as String?,
        dataDate: json['data_date'] as String?,
        datasetVersion: json['dataset_version'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'trade': trade,
        'location': location,
        'provider': provider,
        'placement_rate': placementRate,
        'avg_earnings': avgEarnings,
        'earnings_min': earningsMin,
        'earnings_max': earningsMax,
        'nsqf_level': nsqfLevel,
        'duration_months': durationMonths,
        'training_cost': trainingCost,
        'min_education': minEducation,
        'job_roles': jobRoles,
        'progression': progression,
        'further_education': furtherEducation,
        'source': source,
        'data_date': dataDate,
        'dataset_version': datasetVersion,
        'created_at': createdAt,
      };
}

class ChunkRecord {
  final String id;
  final String outcomeId;
  final String topic;
  final String text;
  final String trade;
  final String location;
  final String source;
  final String dataDate;
  final List<double>? embedding;
  final String? filePath;

  ChunkRecord({
    required this.id,
    required this.outcomeId,
    required this.topic,
    required this.text,
    required this.trade,
    required this.location,
    required this.source,
    required this.dataDate,
    this.embedding,
    this.filePath,
  });

  factory ChunkRecord.fromJson(Map<String, dynamic> json) => ChunkRecord(
        id: json['id'] as String,
        outcomeId: json['outcome_id'] as String,
        topic: json['topic'] as String,
        text: json['text'] as String,
        trade: json['trade'] as String,
        location: json['location'] as String,
        source: json['source'] as String,
        dataDate: json['data_date'] as String,
        embedding: (json['embedding'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
        filePath: json['file_path'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'outcome_id': outcomeId,
        'topic': topic,
        'text': text,
        'trade': trade,
        'location': location,
        'source': source,
        'data_date': dataDate,
        'embedding': embedding,
        'file_path': filePath,
      };
}

class EscalationRecord {
  final String id;
  final String sessionId;
  final String? studentName;
  final String reason;
  String status; // 'open' | 'in_progress' | 'resolved'
  String? counsellorId;
  String? counsellorNotes;
  List<dynamic> evidenceShown;
  final String? preferredContactTime;
  final String? preferredLanguage;
  final String createdAt;
  String updatedAt;

  EscalationRecord({
    required this.id,
    required this.sessionId,
    this.studentName,
    required this.reason,
    this.status = 'open',
    this.counsellorId,
    this.counsellorNotes,
    List<dynamic>? evidenceShown,
    this.preferredContactTime,
    this.preferredLanguage,
    String? createdAt,
    String? updatedAt,
  })  : evidenceShown = evidenceShown ?? [],
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  factory EscalationRecord.fromJson(Map<String, dynamic> json) => EscalationRecord(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        studentName: json['student_name'] as String?,
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        counsellorId: json['counsellor_id'] as String?,
        counsellorNotes: json['counsellor_notes'] as String?,
        evidenceShown: (json['evidence_shown'] as List<dynamic>?) ?? [],
        preferredContactTime: json['preferred_contact_time'] as String?,
        preferredLanguage: json['preferred_language'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'student_name': studentName,
        'reason': reason,
        'status': status,
        'counsellor_id': counsellorId,
        'counsellor_notes': counsellorNotes,
        'evidence_shown': evidenceShown,
        'preferred_contact_time': preferredContactTime,
        'preferred_language': preferredLanguage,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class DatasetRecord {
  final String id;
  final String version;
  final String filename;
  final int totalRows;
  int validRows;
  int rejectedRows;
  final String uploadedAt;

  DatasetRecord({
    required this.id,
    required this.version,
    required this.filename,
    this.totalRows = 0,
    this.validRows = 0,
    this.rejectedRows = 0,
    String? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now().toIso8601String();

  factory DatasetRecord.fromJson(Map<String, dynamic> json) => DatasetRecord(
        id: json['id'] as String,
        version: json['version'] as String,
        filename: json['filename'] as String? ?? '',
        totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
        validRows: (json['valid_rows'] as num?)?.toInt() ?? 0,
        rejectedRows: (json['rejected_rows'] as num?)?.toInt() ?? 0,
        uploadedAt: json['uploaded_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'filename': filename,
        'total_rows': totalRows,
        'valid_rows': validRows,
        'rejected_rows': rejectedRows,
        'uploaded_at': uploadedAt,
      };
}

class CoverageGapRecord {
  final String id;
  final String? trade;
  final String? location;
  final String question;
  final String createdAt;

  CoverageGapRecord({
    required this.id,
    this.trade,
    this.location,
    required this.question,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory CoverageGapRecord.fromJson(Map<String, dynamic> json) => CoverageGapRecord(
        id: json['id'] as String,
        trade: json['trade'] as String?,
        location: json['location'] as String?,
        question: json['question'] as String? ?? '',
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'trade': trade,
        'location': location,
        'question': question,
        'created_at': createdAt,
      };
}

class EngagementRecord {
  final String id;
  final String sessionId;
  final int step;
  final int? timeSpentSeconds;
  final bool? parentJoined;
  final bool? voiceUsed;
  final String? language;
  final bool? completed;
  final String createdAt;

  EngagementRecord({
    required this.id,
    required this.sessionId,
    required this.step,
    this.timeSpentSeconds,
    this.parentJoined,
    this.voiceUsed,
    this.language,
    this.completed,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory EngagementRecord.fromJson(Map<String, dynamic> json) => EngagementRecord(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        step: (json['step'] as num?)?.toInt() ?? 0,
        timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt(),
        parentJoined: json['parent_joined'] as bool?,
        voiceUsed: json['voice_used'] as bool?,
        language: json['language'] as String?,
        completed: json['completed'] as bool?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'step': step,
        'time_spent_seconds': timeSpentSeconds,
        'parent_joined': parentJoined,
        'voice_used': voiceUsed,
        'language': language,
        'completed': completed,
        'created_at': createdAt,
      };
}

class DbSchema {
  List<UserRecord> users;
  List<SessionRecord> sessions;
  List<ConcernRecord> concerns;
  List<SentimentShiftRecord> sentimentShifts;
  List<OutcomeRecord> outcomes;
  List<ChunkRecord> outcomeChunks;
  List<EscalationRecord> escalations;
  List<DatasetRecord> datasets;
  List<CoverageGapRecord> coverageGaps;
  List<EngagementRecord> engagement;

  DbSchema({
    List<UserRecord>? users,
    List<SessionRecord>? sessions,
    List<ConcernRecord>? concerns,
    List<SentimentShiftRecord>? sentimentShifts,
    List<OutcomeRecord>? outcomes,
    List<ChunkRecord>? outcomeChunks,
    List<EscalationRecord>? escalations,
    List<DatasetRecord>? datasets,
    List<CoverageGapRecord>? coverageGaps,
    List<EngagementRecord>? engagement,
  })  : users = users ?? [],
        sessions = sessions ?? [],
        concerns = concerns ?? [],
        sentimentShifts = sentimentShifts ?? [],
        outcomes = outcomes ?? [],
        outcomeChunks = outcomeChunks ?? [],
        escalations = escalations ?? [],
        datasets = datasets ?? [],
        coverageGaps = coverageGaps ?? [],
        engagement = engagement ?? [];

  factory DbSchema.fromJson(Map<String, dynamic> json) => DbSchema(
        users: (json['users'] as List<dynamic>?)
                ?.map((u) => UserRecord.fromJson(u as Map<String, dynamic>))
                .toList() ??
            [],
        sessions: (json['sessions'] as List<dynamic>?)
                ?.map((s) => SessionRecord.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        concerns: (json['concerns'] as List<dynamic>?)
                ?.map((c) => ConcernRecord.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        sentimentShifts: (json['sentiment_shifts'] as List<dynamic>?)
                ?.map((s) => SentimentShiftRecord.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        outcomes: (json['outcomes'] as List<dynamic>?)
                ?.map((o) => OutcomeRecord.fromJson(o as Map<String, dynamic>))
                .toList() ??
            [],
        outcomeChunks: (json['outcome_chunks'] as List<dynamic>?)
                ?.map((c) => ChunkRecord.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        escalations: (json['escalations'] as List<dynamic>?)
                ?.map((e) => EscalationRecord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        datasets: (json['datasets'] as List<dynamic>?)
                ?.map((d) => DatasetRecord.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
        coverageGaps: (json['coverage_gaps'] as List<dynamic>?)
                ?.map((g) => CoverageGapRecord.fromJson(g as Map<String, dynamic>))
                .toList() ??
            [],
        engagement: (json['engagement'] as List<dynamic>?)
                ?.map((e) => EngagementRecord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'users': users.map((u) => u.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'concerns': concerns.map((c) => c.toJson()).toList(),
        'sentiment_shifts': sentimentShifts.map((s) => s.toJson()).toList(),
        'outcomes': outcomes.map((o) => o.toJson()).toList(),
        'outcome_chunks': outcomeChunks.map((c) => c.toJson()).toList(),
        'escalations': escalations.map((e) => e.toJson()).toList(),
        'datasets': datasets.map((d) => d.toJson()).toList(),
        'coverage_gaps': coverageGaps.map((g) => g.toJson()).toList(),
        'engagement': engagement.map((e) => e.toJson()).toList(),
      };
}

class QueryResult<T> {
  final List<T> rows;
  final int rowCount;

  const QueryResult({required this.rows, required this.rowCount});
}

/// Vector search result with cosine distance.
class VectorSearchResult {
  final String id;
  final String outcomeId;
  final String topic;
  final String text;
  final String trade;
  final String location;
  final String source;
  final String dataDate;
  final double distance;

  const VectorSearchResult({
    required this.id,
    required this.outcomeId,
    required this.topic,
    required this.text,
    required this.trade,
    required this.location,
    required this.source,
    required this.dataDate,
    required this.distance,
  });
}

/// Port of backend lib/db.ts — local JSON database service with SQL-like
/// query wrapper and cosine vector search over outcome chunks.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DbSchema? _db;
  File? _dbFile;
  bool _initStarted = false;
  Future<void>? _initFuture;

  DatabaseService._internal();

  Future<void> init() {
    _initFuture ??= _initInternal();
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_initStarted) return;
    _initStarted = true;
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory('${dir.path}/db');
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    _dbFile = File('${dbDir.path}/db.json');
    _db = _loadFromFile();
  }

  DbSchema _loadFromFile() {
    try {
      if (_dbFile != null && _dbFile!.existsSync()) {
        final content = _dbFile!.readAsStringSync();
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        return DbSchema.fromJson(parsed);
      }
    } catch (err) {
      // Corrupt DB -> start fresh
    }
    return DbSchema();
  }

  Future<DbSchema> getDb() async {
    await init();
    _db ??= DbSchema();
    return _db!;
  }

  Future<void> saveDb() async {
    await init();
    if (_db == null || _dbFile == null) return;
    _dbFile!.writeAsStringSync(jsonEncode(_db!.toJson()), flush: true);
  }

  /// Universal SQL Query compatibility wrapper (port of lib/db.ts query()).
  Future<QueryResult<Map<String, dynamic>>> query(String sql, [List<dynamic> params = const []]) async {
    final db = await getDb();
    final sqlTrimmed = sql.trim().toUpperCase();

    // Pad short parameter lists so positional $N access never overflows
    if ((sqlTrimmed.startsWith('INSERT') || sqlTrimmed.startsWith('UPDATE')) &&
        params.length < 16) {
      params = [
        ...params,
        ...List<dynamic>.filled(16 - params.length, null),
      ];
    }

    // 1. SELECT queries
    if (sqlTrimmed.startsWith('SELECT')) {
      if (sqlTrimmed.contains('FROM USERS')) {
        List<UserRecord> filtered = [...db.users];
        if (sql.contains('WHERE id = \$1')) {
          filtered = filtered.where((u) => u.id == params[0]).toList();
        } else if (sql.contains('WHERE phone = \$1')) {
          filtered = filtered.where((u) => u.phone == params[0]).toList();
        } else if (sql.contains('parent_access_code = \$1')) {
          filtered = filtered.where((u) => u.parentAccessCode == params[0]).toList();
        } else if (sql.contains('email = \$1')) {
          filtered = filtered.where((u) => u.email == params[0]).toList();
        }
        return QueryResult(
          rows: filtered.map((u) => u.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM SESSIONS')) {
        List<SessionRecord> filtered = [...db.sessions];
        if (sql.contains('WHERE id = \$1')) {
          filtered = filtered.where((s) => s.id == params[0]).toList();
        } else if (sql.contains('WHERE user_id = \$1')) {
          filtered = filtered.where((s) => s.userId == params[0]).toList();
        }
        return QueryResult(
          rows: filtered.map((s) => s.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM CONCERNS')) {
        List<ConcernRecord> filtered = [...db.concerns];
        if (sql.contains('session_id = \$1 AND category = \$2')) {
          filtered = filtered
              .where((c) => c.sessionId == params[0] && c.category == params[1])
              .toList();
        } else if (sql.contains('session_id = \$1')) {
          filtered = filtered.where((c) => c.sessionId == params[0]).toList();
        }
        return QueryResult(
          rows: filtered.map((c) => c.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM OUTCOMES')) {
        List<OutcomeRecord> filtered = [...db.outcomes];
        if (sql.contains('LOWER(trade) = LOWER(\$1) AND LOWER(location) = LOWER(\$2)')) {
          filtered = filtered
              .where((o) =>
                  o.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  o.location.toLowerCase() == String(params[1]).toLowerCase())
              .toList();
        } else if (sql.contains('LOWER(trade) = LOWER(\$1)')) {
          filtered = filtered
              .where((o) => o.trade.toLowerCase() == String(params[0]).toLowerCase())
              .toList();
        }
        return QueryResult(
          rows: filtered.map((o) => o.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM OUTCOME_CHUNKS')) {
        List<ChunkRecord> filtered = [...db.outcomeChunks];
        if (sql.contains('LOWER(trade) = LOWER(\$1) AND LOWER(location) = LOWER(\$2) AND LOWER(topic) = LOWER(\$3)')) {
          filtered = filtered
              .where((c) =>
                  c.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  c.location.toLowerCase() == String(params[1]).toLowerCase() &&
                  c.topic.toLowerCase() == String(params[2]).toLowerCase())
              .toList();
        } else if (sql.contains('LOWER(trade) = LOWER(\$1) AND LOWER(location) = LOWER(\$2)')) {
          filtered = filtered
              .where((c) =>
                  c.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  c.location.toLowerCase() == String(params[1]).toLowerCase())
              .toList();
        } else if (sql.contains('LOWER(trade) = LOWER(\$1) AND LOWER(topic) = LOWER(\$2)')) {
          filtered = filtered
              .where((c) =>
                  c.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  c.topic.toLowerCase() == String(params[1]).toLowerCase())
              .toList();
        } else if (sql.contains('LOWER(trade) = LOWER(\$1)')) {
          filtered = filtered
              .where((c) => c.trade.toLowerCase() == String(params[0]).toLowerCase())
              .toList();
        }
        return QueryResult(
          rows: filtered.map((c) => c.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM ESCALATIONS')) {
        List<EscalationRecord> filtered = [...db.escalations];
        if (sql.contains('WHERE id = \$1')) {
          filtered = filtered.where((e) => e.id == params[0]).toList();
        } else if (sql.contains('WHERE session_id = \$1')) {
          filtered = filtered.where((e) => e.sessionId == params[0]).toList();
        }
        return QueryResult(
          rows: filtered.map((e) => e.toJson()).toList(),
          rowCount: filtered.length,
        );
      }

      if (sqlTrimmed.contains('FROM DATASETS')) {
        return QueryResult(
          rows: db.datasets.map((d) => d.toJson()).toList(),
          rowCount: db.datasets.length,
        );
      }

      if (sqlTrimmed.contains('FROM COVERAGE_GAPS')) {
        return QueryResult(
          rows: db.coverageGaps.map((g) => g.toJson()).toList(),
          rowCount: db.coverageGaps.length,
        );
      }
    }

    // 2. DELETE queries
    if (sqlTrimmed.startsWith('DELETE')) {
      if (sqlTrimmed.contains('FROM OUTCOME_CHUNKS')) {
        final countBefore = db.outcomeChunks.length;
        if (sql.contains('WHERE trade = \$1 AND location = \$2')) {
          db.outcomeChunks = db.outcomeChunks
              .where((c) => !(c.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  c.location.toLowerCase() == String(params[1]).toLowerCase()))
              .toList();
        } else if (sql.contains('WHERE file_path = \$1') || sql.contains('WHERE file_path IS NOT NULL')) {
          db.outcomeChunks =
              db.outcomeChunks.where((c) => c.filePath != params[0]).toList();
        } else {
          db.outcomeChunks = [];
        }
        await saveDb();
        return QueryResult(rows: const [], rowCount: countBefore - db.outcomeChunks.length);
      }

      if (sqlTrimmed.contains('FROM OUTCOMES')) {
        final countBefore = db.outcomes.length;
        if (sql.contains('WHERE trade = \$1 AND location = \$2')) {
          db.outcomes = db.outcomes
              .where((o) => !(o.trade.toLowerCase() == String(params[0]).toLowerCase() &&
                  o.location.toLowerCase() == String(params[1]).toLowerCase()))
              .toList();
        } else {
          db.outcomes = [];
        }
        await saveDb();
        return QueryResult(rows: const [], rowCount: countBefore - db.outcomes.length);
      }
    }

    // 3. INSERT queries
    if (sqlTrimmed.startsWith('INSERT INTO USERS')) {
      final existingIdx = db.users.indexWhere((u) => u.id == params[0]);
      final record = UserRecord(
        id: params[0] as String,
        phone: params[1] as String?,
        email: params[2] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.toString().split('.').last == (params[3] as String? ?? 'family'),
          orElse: () => UserRole.family,
        ),
        consent: params[4] as bool? ?? true,
        createdAt: DateTime.now().toIso8601String(),
      );
      if (existingIdx >= 0) {
        final existing = db.users[existingIdx];
        db.users[existingIdx] = UserRecord(
          id: existing.id,
          phone: record.phone ?? existing.phone,
          email: record.email ?? existing.email,
          name: record.name ?? existing.name,
          role: existing.role,
          passwordHash: record.passwordHash ?? existing.passwordHash,
          parentAccessCode: record.parentAccessCode ?? existing.parentAccessCode,
          language: record.language ?? existing.language,
          consent: record.consent ?? existing.consent,
          consentAt: record.consentAt ?? existing.consentAt,
          createdAt: existing.createdAt,
          failedAttempts: existing.failedAttempts,
          lockedUntil: existing.lockedUntil,
        );
      } else {
        db.users.add(record);
      }
      await saveDb();
      return QueryResult(rows: [db.users[existingIdx >= 0 ? existingIdx : db.users.length - 1].toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO SESSIONS')) {
      final existingIdx = db.sessions.indexWhere((s) => s.id == params[0]);
      final studentProfile = params[2] is String ? jsonDecode(params[2] as String) : (params[2] as Map<String, dynamic>? ?? {});
      final familyContext = params[3] is String ? jsonDecode(params[3] as String) : (params[3] as Map<String, dynamic>? ?? {});
      final record = SessionRecord(
        id: params[0] as String,
        userId: params[1] as String?,
        studentProfile: Map<String, dynamic>.from(studentProfile as Map<String, dynamic>),
        familyContext: Map<String, dynamic>.from(familyContext as Map<String, dynamic>),
        status: params[4] as String? ?? 'active',
      );
      if (existingIdx >= 0) {
        final existing = db.sessions[existingIdx];
        db.sessions[existingIdx] = SessionRecord(
          id: existing.id,
          userId: record.userId ?? existing.userId,
          studentId: existing.studentId,
          studentProfile: {...existing.studentProfile, ...record.studentProfile},
          familyContext: {...existing.familyContext, ...record.familyContext},
          recommendations: existing.recommendations,
          pathway: existing.pathway,
          status: record.status,
          currentStep: existing.currentStep,
          messages: existing.messages,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );
      } else {
        db.sessions.add(record);
      }
      await saveDb();
      return QueryResult(rows: [db.sessions[existingIdx >= 0 ? existingIdx : db.sessions.length - 1].toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO CONCERNS')) {
      final record = ConcernRecord(
        id: params[0] as String,
        sessionId: params[1] as String,
        category: params[2] as String,
        status: params[3] as String? ?? 'raised',
        askedAt: DateTime.now().toIso8601String(),
        resolvedAt: params[4] as String?,
        evidenceUsed: params[5] is String
            ? Map<String, dynamic>.from(jsonDecode(params[5] as String) as Map<String, dynamic>)
            : (params[5] as Map<String, dynamic>? ?? {}),
      );
      final existingIdx = db.concerns
          .indexWhere((c) => c.sessionId == record.sessionId && c.category == record.category);
      if (existingIdx >= 0) {
        db.concerns[existingIdx] = record;
      } else {
        db.concerns.add(record);
      }
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO OUTCOMES')) {
      final record = OutcomeRecord(
        id: params[0] as String,
        trade: params[1] as String,
        location: params[2] as String,
        provider: params[3] as String?,
        placementRate: params[4] == null ? null : (params[4] as num).toDouble(),
        avgEarnings: params[5] == null ? null : (params[5] as num).toDouble(),
        nsqfLevel: params[6] == null ? null : (params[6] as num).toInt(),
        durationMonths: params[7] == null ? null : (params[7] as num).toInt(),
        trainingCost: params[8] == null ? null : (params[8] as num).toDouble(),
        minEducation: params[9] as String?,
        jobRoles: params[10] is String
            ? (jsonDecode(params[10] as String) as List<dynamic>).cast<String>()
            : (params[10] as List<dynamic>? ?? const []).cast<String>(),
        progression: params[11] is String
            ? (jsonDecode(params[11] as String) as List<dynamic>).cast<String>()
            : (params[11] as List<dynamic>? ?? const []).cast<String>(),
        furtherEducation: params[12] as String?,
        source: params[13] as String?,
        dataDate: params[14] as String?,
        datasetVersion: params[15] as String?,
        createdAt: DateTime.now().toIso8601String(),
      );
      final idx = db.outcomes.indexWhere((o) => o.id == record.id);
      if (idx >= 0) {
        db.outcomes[idx] = record;
      } else {
        db.outcomes.add(record);
      }
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO OUTCOME_CHUNKS')) {
      List<double>? embeddingArr;
      if (params.length > 8 && params[8] != null) {
        if (params[8] is List) {
          embeddingArr = (params[8] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
        } else if (params[8] is String) {
          try {
            embeddingArr = (jsonDecode(params[8] as String) as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList();
          } catch (_) {
            // ignore parse errors
          }
        }
      }
      final record = ChunkRecord(
        id: params[0] as String,
        outcomeId: params[1] as String,
        topic: params[2] as String,
        text: params[3] as String,
        trade: params[4] as String,
        location: params[5] as String,
        source: params[6] as String,
        dataDate: params[7] as String,
        embedding: embeddingArr,
        filePath: params.length > 9 ? params[9] as String? : null,
      );
      final idx = db.outcomeChunks.indexWhere((c) => c.id == record.id);
      if (idx >= 0) {
        db.outcomeChunks[idx] = record;
      } else {
        db.outcomeChunks.add(record);
      }
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO ESCALATIONS')) {
      final record = EscalationRecord(
        id: params[0] as String,
        sessionId: params[1] as String,
        reason: params[2] as String,
        status: 'open',
        evidenceShown: params[3] is String
            ? (jsonDecode(params[3] as String) as List<dynamic>)
            : (params[3] as List<dynamic>? ?? []),
      );
      db.escalations.add(record);
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO DATASETS')) {
      final record = DatasetRecord(
        id: params[0] as String,
        version: params[1] as String,
        filename: params[2] as String? ?? '',
        totalRows: (params[3] as num?)?.toInt() ?? 0,
      );
      final idx = db.datasets.indexWhere((d) => d.version == record.version);
      if (idx >= 0) {
        db.datasets[idx] = record;
      } else {
        db.datasets.add(record);
      }
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO COVERAGE_GAPS')) {
      final record = CoverageGapRecord(
        id: params[0] as String,
        trade: params[1] as String?,
        location: params[2] as String?,
        question: params[3] as String? ?? '',
        createdAt: DateTime.now().toIso8601String(),
      );
      db.coverageGaps.add(record);
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    if (sqlTrimmed.startsWith('INSERT INTO ENGAGEMENT')) {
      final record = EngagementRecord(
        id: params[0] as String,
        sessionId: params[1] as String,
        step: (params[2] as num?)?.toInt() ?? 0,
      );
      db.engagement.add(record);
      await saveDb();
      return QueryResult(rows: [record.toJson()], rowCount: 1);
    }

    // 4. UPDATE queries
    if (sqlTrimmed.startsWith('UPDATE CONCERNS')) {
      final status = params[0] as String;
      final resolvedAt = params[1] as String?;
      final evidenceUsed = params[2];
      final sessionId = params[3] as String;
      final category = params[4] as String;
      final idx = db.concerns
          .indexWhere((c) => c.sessionId == sessionId && c.category == category);
      if (idx >= 0) {
        final existing = db.concerns[idx];
        existing.status = status;
        existing.resolvedAt = resolvedAt;
        existing.evidenceUsed = evidenceUsed is String
            ? Map<String, dynamic>.from(jsonDecode(evidenceUsed) as Map<String, dynamic>)
            : (evidenceUsed as Map<String, dynamic>? ?? {});
        await saveDb();
        return QueryResult(rows: [existing.toJson()], rowCount: 1);
      }
    }

    if (sqlTrimmed.startsWith('UPDATE SESSIONS')) {
      final status = params[0] as String;
      final sessionId = params[1] as String;
      final idx = db.sessions.indexWhere((s) => s.id == sessionId);
      if (idx >= 0) {
        final existing = db.sessions[idx];
        existing.status = status;
        existing.updatedAt = DateTime.now().toIso8601String();
        await saveDb();
        return QueryResult(rows: [existing.toJson()], rowCount: 1);
      }
    }

    if (sqlTrimmed.startsWith('UPDATE DATASETS')) {
      final validRows = params[0] as int;
      final rejectedRows = params[1] as int;
      final version = params[2] as String;
      final idx = db.datasets.indexWhere((d) => d.version == version);
      if (idx >= 0) {
        final existing = db.datasets[idx];
        existing.validRows = validRows;
        existing.rejectedRows = rejectedRows;
        await saveDb();
        return QueryResult(rows: [existing.toJson()], rowCount: 1);
      }
    }

    return const QueryResult(rows: [], rowCount: 0);
  }

  /// Cosine similarity vector search over outcome_chunks
  /// (port of vectorSearchOutcomeChunks).
  Future<List<VectorSearchResult>> vectorSearchOutcomeChunks(
    List<double> queryEmbedding, {
    String? trade,
    int topK = 6,
  }) async {
    final db = await getDb();
    List<ChunkRecord> chunks = db.outcomeChunks.where((c) => c.embedding != null && c.embedding!.isNotEmpty).toList();

    if (trade != null) {
      final tradeLower = trade.toLowerCase();
      chunks = chunks.where((c) => c.trade.toLowerCase() == tradeLower).toList();
    }

    final results = chunks.map((chunk) {
      final emb = chunk.embedding!;
      double dot = 0;
      double normA = 0;
      double normB = 0;
      final len = min(queryEmbedding.length, emb.length);

      for (var i = 0; i < len; i++) {
        dot += queryEmbedding[i] * emb[i];
        normA += queryEmbedding[i] * queryEmbedding[i];
        normB += emb[i] * emb[i];
      }

      final similarity = (normA > 0 && normB > 0) ? dot / (sqrt(normA) * sqrt(normB)) : 0;
      final distance = 1 - similarity;

      return VectorSearchResult(
        id: chunk.id,
        outcomeId: chunk.outcomeId,
        topic: chunk.topic,
        text: chunk.text,
        trade: chunk.trade,
        location: chunk.location,
        source: chunk.source,
        dataDate: chunk.dataDate,
        distance: distance,
      );
    }).toList();

    results.sort((a, b) => a.distance.compareTo(b.distance));
    return results.take(topK).toList();
  }
}

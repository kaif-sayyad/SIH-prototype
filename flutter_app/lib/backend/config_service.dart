import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Port of backend lib/config.ts — application configuration service.
class AppConfig {
  final String geminiApiKey;
  final String geminiModel;
  final String geminiEmbeddingModel;
  final String adminEmail;
  final String adminPassword;
  final String sessionSecret;
  final int port;

  const AppConfig({
    this.geminiApiKey = 'PASTE_YOUR_GEMINI_API_KEY_HERE',
    this.geminiModel = 'gemini-3.8-flash',
    this.geminiEmbeddingModel = 'gemini-embedding-001',
    this.adminEmail = 'admin@example.com',
    this.adminPassword = 'CHANGE_ME',
    this.sessionSecret = 'CHANGE_ME_TO_A_LONG_RANDOM_STRING',
    this.port = 3000,
  });

  AppConfig copyWith({
    String? geminiApiKey,
    String? geminiModel,
    String? geminiEmbeddingModel,
    String? adminEmail,
    String? adminPassword,
    String? sessionSecret,
    int? port,
  }) {
    return AppConfig(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      geminiEmbeddingModel: geminiEmbeddingModel ?? this.geminiEmbeddingModel,
      adminEmail: adminEmail ?? this.adminEmail,
      adminPassword: adminPassword ?? this.adminPassword,
      sessionSecret: sessionSecret ?? this.sessionSecret,
      port: port ?? this.port,
    );
  }
}

class ConfigService {
  static AppConfig? _cached;

  static const _defaults = AppConfig();

  /// Load configuration from bundled `assets/config.json` (falls back to
  /// defaults). Mirrors the Next.js `config.json` + env-var resolution.
  static Future<AppConfig> getConfig() async {
    if (_cached != null) return _cached!;

    Map<String, dynamic>? parsed;
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      parsed = null;
    }

    if (parsed != null) {
      _cached = _defaults.copyWith(
        geminiApiKey: parsed['GEMINI_API_KEY'] as String? ?? _defaults.geminiApiKey,
        geminiModel: parsed['GEMINI_MODEL'] as String? ?? _defaults.geminiModel,
        geminiEmbeddingModel:
            parsed['GEMINI_EMBEDDING_MODEL'] as String? ?? _defaults.geminiEmbeddingModel,
        adminEmail: parsed['ADMIN_EMAIL'] as String? ?? _defaults.adminEmail,
        adminPassword: parsed['ADMIN_PASSWORD'] as String? ?? _defaults.adminPassword,
        sessionSecret: parsed['SESSION_SECRET'] as String? ?? _defaults.sessionSecret,
        port: (parsed['PORT'] as num?)?.toInt() ?? _defaults.port,
      );
      return _cached!;
    }

    _cached = _defaults;
    return _cached!;
  }

  /// Mirrors hasValidGeminiKey(): false for placeholder/dev keys.
  static Future<bool> hasValidGeminiKey() async {
    final cfg = await getConfig();
    final key = cfg.geminiApiKey;
    return key.isNotEmpty &&
        key != 'PASTE_YOUR_GEMINI_API_KEY_HERE' &&
        key != 'mock-gemini-key-for-dev' &&
        key != 'your_gemini_api_key_here' &&
        key.length > 10;
  }
}

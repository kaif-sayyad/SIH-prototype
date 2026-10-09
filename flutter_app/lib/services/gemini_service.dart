import '../backend/agent/runner_service.dart';
import '../backend/agent/tools_service.dart';
import '../backend/database_service.dart';
import '../backend/gemini_service.dart';
import '../backend/rag/ingest_service.dart';
import '../backend/rag/retrieval_service.dart';
import '../backend/rag/verification_service.dart';

/// Flutter facade over the converted backend:
/// - Gemini API client (backend/gemini_service.dart)
/// - Agentic counsellor loop with RAG + verification guard
///   (backend/agent/runner_service.dart)
class GeminiService {
  final GeminiServiceBackend _gemini = GeminiServiceBackend();

  GeminiService({String? apiKey, String? model});

  /// Test connection to Gemini API (mirrors POST /api/admin/test-ai).
  Future<Map<String, dynamic>> testConnection() async {
    return await _gemini.testGeminiConnection();
  }

  /// Grounded career counselling query using the full backend
  /// agent loop: concern classification -> RAG evidence retrieval ->
  /// grounded generation -> verification guard -> escalation when
  /// verified data is missing.
  Future<Map<String, dynamic>> queryGroundedCounsellor({
    required String question,
    String? trade,
    String? location,
    String language = 'en',
    String role = 'family',
  }) async {
    final profile = <String, dynamic>{
      'sInterestTrade': trade,
      'sLoc': location,
    };

    final sessionId = 'flutter_${role}_session';

    final resp = await AgentRunner.runCounsellorAgent(AgentTurnRequest(
      sessionId: sessionId,
      userMessage: question,
      profile: profile,
      language: language == 'mr' ? 'mr' : 'en',
    ));

    // Resolve source / date metadata from cited chunks
    String? source;
    String? date;
    if (resp.citations.isNotEmpty) {
      final db = await DatabaseService().getDb();
      final cited = db.outcomeChunks
          .where((c) => resp.citations.contains(c.id))
          .toList();
      if (cited.isNotEmpty) {
        source = cited.first.source;
        date = cited.first.dataDate;
      }
    }

    return {
      'answer': resp.answer,
      'citations': resp.citations,
      'source': source,
      'date': date,
      'isGrounded': resp.grounded,
      'requiresEscalation': !resp.grounded,
      'concernCategory': resp.concernCategory,
      'escalated': resp.escalated,
    };
  }

  /// Direct RAG evidence retrieval (used by the knowledge screens).
  Future<List<RetrievedChunk>> retrieveEvidence(
    String question, {
    String? trade,
    String? location,
  }) async {
    final result = await RetrievalService.retrieveEvidence(
      question,
      profileTrade: trade,
      profileLocation: location,
    );
    return (result['chunks'] as List).cast<RetrievedChunk>();
  }

  /// Verification guard (port of verifyAnswerGrounding).
  Map<String, dynamic> verifyAnswerGrounding(
      String answer, List<RetrievedChunk> citedChunks) {
    return VerificationService.verifyAnswerGrounding(answer, citedChunks);
  }

  /// Recommend top-3 trades for a student profile (port of recommendTrades).
  Future<List<RecommendedTrade>> recommendTrades(
      Map<String, dynamic> profile) async {
    final db = await DatabaseService().getDb();
    if (db.outcomes.isEmpty) {
      // Seed knowledge from bundled assets on first use
      await IngestService.loadKnowledgeFiles();
    }
    return await ToolsService.recommendTrades(profile);
  }

  /// Compare vocational vs academic pathway (port of comparePathways).
  Future<Map<String, dynamic>> comparePathways(String trade, String location) async {
    final db = await DatabaseService().getDb();
    if (db.outcomes.isEmpty) {
      await IngestService.loadKnowledgeFiles();
    }
    return await ToolsService.comparePathways(trade, location);
  }

  /// Get career pathway steps for a trade (port of getPathway).
  Future<Map<String, dynamic>> getPathway(String trade) async {
    final db = await DatabaseService().getDb();
    if (db.outcomes.isEmpty) {
      await IngestService.loadKnowledgeFiles();
    }
    return await ToolsService.getPathway(trade);
  }

  /// Generate the family decision summary (port of generateFamilySummary).
  Future<Map<String, dynamic>> generateFamilySummary(String sessionId) async {
    return await ToolsService.generateFamilySummary(sessionId);
  }

  /// Update concern status (port of updateConcernStatus).
  Future<Map<String, dynamic>> updateConcernStatus(
    String sessionId,
    String category,
    String status, {
    Map<String, dynamic> evidenceUsed = const {},
  }) async {
    return await ToolsService.updateConcernStatus(sessionId, category, status,
        evidenceUsed: evidenceUsed);
  }

  /// Create a human-counsellor escalation (port of createEscalation).
  Future<Map<String, dynamic>> createEscalation(
    String sessionId,
    String reason, {
    List<dynamic> evidenceShown = const [],
  }) async {
    return await ToolsService.createEscalation(sessionId, reason,
        evidenceShown: evidenceShown);
  }
}

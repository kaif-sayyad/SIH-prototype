import '../rag/retrieval_service.dart';
import '../rag/verification_service.dart';
import 'tools_service.dart';

/// Port of backend lib/agent/runner.ts — the agentic AI counsellor loop.

class AgentTurnRequest {
  final String sessionId;
  final String userMessage;
  final Map<String, dynamic> profile;
  final String language; // 'en' | 'mr'

  const AgentTurnRequest({
    required this.sessionId,
    required this.userMessage,
    Map<String, dynamic>? profile,
    String language = 'en',
  })  : profile = profile ?? {},
        language = language;
}

class AgentTurnResponse {
  final String answer;
  final List<String> citations;
  final String? concernCategory;
  final bool grounded;
  final bool escalated;
  final int toolCallsCount;

  const AgentTurnResponse({
    required this.answer,
    required this.citations,
    this.concernCategory,
    required this.grounded,
    required this.escalated,
    required this.toolCallsCount,
  });

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'citations': citations,
        'concernCategory': concernCategory,
        'grounded': grounded,
        'escalated': escalated,
        'toolCallsCount': toolCallsCount,
      };
}

class AgentRunner {
  /// Run one counsellor agent turn (port of runCounsellorAgent).
  static Future<AgentTurnResponse> runCounsellorAgent(AgentTurnRequest req) async {
    final sessionId = req.sessionId;
    final userMessage = req.userMessage;
    final profile = req.profile;
    final language = req.language;
    final userTextLower = userMessage.toLowerCase();

    // Safety Rule 1: Check for human counsellor request explicitly
    if (RegExp(r'counsellor|human|talk to person|समुपदेशक|माणूस').hasMatch(userTextLower)) {
      await ToolsService.createEscalation(sessionId, 'User requested human counsellor');
      return AgentTurnResponse(
        answer: language == 'mr'
            ? 'मी तुमच्या विनंतीची नोंद घेतली आहे. मानव समुपदेशक लवकरच तुमच्याशी संपर्क साधेल.'
            : 'I have recorded your request for a human counsellor. A qualified counsellor will connect with your family.',
        citations: [],
        grounded: true,
        escalated: true,
        toolCallsCount: 1,
      );
    }

    // Safety Rule 2: Check for safety or social perception topics (no verified numerical data available)
    final safetyMatch = RegExp(r'safe|danger|accident|surroundings|सुरक्षा').hasMatch(userTextLower);
    final socialMatch = RegExp(r'respect|society|relatives|status|प्रतिष्ठा|समाज').hasMatch(userTextLower);
    if (safetyMatch || socialMatch) {
      final category = safetyMatch ? 'safety' : 'social';
      await ToolsService.updateConcernStatus(sessionId, category, 'escalated');
      await ToolsService.createEscalation(
        sessionId,
        "Topic '$category' has no verified outcome numerical dataset.",
      );

      return AgentTurnResponse(
        answer: language == 'mr'
            ? 'आम्हाकडे या विषयावर (सुरक्षा / सामाजिक प्रतिष्ठा) अद्याप सत्यापित संख्यात्मक डेटा उपलब्ध नाही.\nमानव समुपदेशक यावर आपल्या कुटुंबाशी चर्चा करू शकतात.'
            : 'We do not have verified outcome numerical dataset on this specific topic ($category).\nA human counsellor can discuss this with your family.',
        citations: [],
        concernCategory: category,
        grounded: false,
        escalated: true,
        toolCallsCount: 1,
      );
    }

    // Classify concern
    final classification = await ToolsService.classifyConcern(userMessage);
    final primaryCategory = (classification['categories'] as List).first.toString();

    // Mark concern as raised in session
    await ToolsService.updateConcernStatus(sessionId, primaryCategory, 'raised');

    // Retrieve evidence using RAG
    final trade = profile['trade'] ?? profile['sInterestTrade'] ?? 'Electrician';
    final location = profile['sLoc'] ?? 'Nagpur';

    final retrieved =
        await RetrievalService.retrieveEvidence(userMessage, profileTrade: trade as String?, profileLocation: location as String?);
    final chunks = (retrieved['chunks'] as List).cast<RetrievedChunk>();
    final ragResult = await VerificationService.runRAGPipeline(
      userMessage,
      chunks,
      language: language,
      sessionId: sessionId,
      trade: trade as String?,
      location: location as String?,
    );

    if (!ragResult.grounded) {
      await ToolsService.updateConcernStatus(sessionId, primaryCategory, 'escalated');
      await ToolsService.createEscalation(
        sessionId,
        'Verified data missing for trade: $trade, location: $location, question: "$userMessage"',
      );
    } else {
      await ToolsService.updateConcernStatus(
        sessionId,
        primaryCategory,
        'answered',
        evidenceUsed: {'citations': ragResult.citations},
      );
    }

    return AgentTurnResponse(
      answer: ragResult.answer,
      citations: ragResult.citations,
      concernCategory: primaryCategory,
      grounded: ragResult.grounded,
      escalated: !ragResult.grounded,
      toolCallsCount: 2,
    );
  }
}

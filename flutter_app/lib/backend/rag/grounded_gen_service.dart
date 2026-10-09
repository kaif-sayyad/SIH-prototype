import '../gemini_service.dart';
import 'retrieval_service.dart';

/// Port of backend lib/rag/grounded-gen.ts — evidence-grounded answer generation.

class GroundedResponse {
  final String answer;
  final List<String> citations;
  final String concern;
  final bool grounded;

  const GroundedResponse({
    required this.answer,
    required this.citations,
    required this.concern,
    required this.grounded,
  });
}

const String UNAVAILABLE_MESSAGE =
    'Verified data for this specific trade/location is currently unavailable.';

class GroundedGenService {
  static Future<GroundedResponse> generateGroundedAnswer(
    String question,
    List<RetrievedChunk> chunks, {
    String language = 'en',
    bool stricter = false,
  }) async {
    if (chunks.isEmpty) {
      return const GroundedResponse(
        answer: '$UNAVAILABLE_MESSAGE\nA human counsellor can assist you.',
        citations: [],
        concern: 'general',
        grounded: false,
      );
    }

    final chunksFormatted = chunks
        .map((c) =>
            '[Chunk ID: ${c.id}] (Trade: ${c.trade}, Location: ${c.location}, Topic: ${c.topic}, Source: ${c.source}, Date: ${c.dataDate}):\n${c.text}')
        .join('\n\n');

    final systemPrompt = 'You are a career counsellor assistant for the SkillPath Family Counselling Portal.\n'
        'Answer the family\'s question using ONLY the provided evidence chunks.\n\n'
        'STRICT GROUNDING RULES:\n'
        '1. Every single number, percentage, salary, duration, or figure MUST appear in the provided chunks.\n'
        '2. DO NOT invent, extrapolate, or use outside knowledge.\n'
        '3. Cite the Chunk IDs used in the "citations" array.\n'
        '4. Always state the source dataset and date clearly in your response.\n'
        '5. If user asks in Marathi (lang: mr), translate the answer into natural, polite Marathi while keeping all figures exact.\n'
        '6. Return valid JSON matching schema:\n'
        '   {"answer": "string", "citations": ["chunk_id"], "concern": "income|job|social|growth|safety|edu|cost|localjobs", "grounded": true}\n'
        '${stricter ? 'ATTENTION: CRITICAL RETRY - DO NOT INCLUDE ANY NUMBER OR STATISTIC THAT IS NOT DIRECTLY WRITTEN IN THE CHUNKS.' : ''}';

    final userPrompt = 'Language: ${language == 'mr' ? 'Marathi (mr)' : 'English (en)'}\n'
        'Question: $question\n\n'
        'Evidence Chunks:\n$chunksFormatted';

    final res = await GeminiServiceBackend().generateJSON(systemPrompt, userPrompt);

    if (res != null && res['answer'] is String && res['citations'] is List) {
      return GroundedResponse(
        answer: res['answer'] as String,
        citations: (res['citations'] as List).map((e) => e.toString()).toList(),
        concern: (res['concern'] as String?) ?? 'general',
        grounded: res['grounded'] != false,
      );
    }

    // Fallback generation if LLM is offline or non-JSON
    final primary = chunks.first;
    final sourceText = '\n(Source: ${primary.source}, Date: ${primary.dataDate})';
    return GroundedResponse(
      answer: '${primary.text}$sourceText',
      citations: [primary.id],
      concern: primary.topic,
      grounded: true,
    );
  }
}

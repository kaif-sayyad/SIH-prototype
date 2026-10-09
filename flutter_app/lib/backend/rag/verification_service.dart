import 'dart:math';

import '../database_service.dart';
import 'grounded_gen_service.dart';
import 'retrieval_service.dart';

/// Port of backend lib/rag/verification.ts — number-extraction verification
/// guard, RAG audit logging, and the end-to-end RAG pipeline with retry.

class VerificationService {
  /// Extract numbers, percentages, and monetary amounts (e.g. 78%, 18,000, ₹20000, 12, 4) from text
  static List<String> extractNumbersFromText(String text) {
    final matches = RegExp(r'(?:₹\s*)?\d+(?:,\d+)*(?:\.\d+)?%?').allMatches(text);
    return matches
        .map((m) => m.group(0)!)
        .map((m) => m.replaceAll(RegExp(r'[₹,\s]'), '').trim())
        .where((m) => m.isNotEmpty && m != '0')
        .toList();
  }

  /// Verify that all numbers in the generated answer exist in the context of the cited chunks
  static Map<String, dynamic> verifyAnswerGrounding(String answer, List<RetrievedChunk> citedChunks) {
    if (citedChunks.isEmpty) {
      return {'verified': false, 'ungroundedNumbers': ['No chunks cited']};
    }

    final answerNumbers = extractNumbersFromText(answer);
    if (answerNumbers.isEmpty) {
      return {'verified': true, 'ungroundedNumbers': <String>[]};
    }

    final chunkTextCombined = citedChunks.map((c) => c.text).join(' ');
    final chunkNumbers = extractNumbersFromText(chunkTextCombined).toSet();

    final ungroundedNumbers = <String>[];

    for (final num in answerNumbers) {
      final cleanNum = num.replaceAll('%', '');
      var found = false;

      for (final chunkNum in chunkNumbers) {
        final cleanChunkNum = chunkNum.replaceAll('%', '');
        if (cleanNum == cleanChunkNum || num == chunkNum) {
          found = true;
          break;
        }
      }

      if (!found && !chunkTextCombined.contains(cleanNum)) {
        ungroundedNumbers.add(num);
      }
    }

    return {
      'verified': ungroundedNumbers.isEmpty,
      'ungroundedNumbers': ungroundedNumbers,
    };
  }

  /// Audit log retrieval results without storing raw user message text
  static Future<void> logRAGAudit(String sessionId, String? topic, List<String> chunkIds, bool grounded) async {
    try {
      await DatabaseService().query(
        'INSERT INTO coverage_gaps (id, trade, location, question, created_at) VALUES (\$1, \$2, \$3, \$4, NOW())',
        [
          'audit_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}',
          topic ?? 'general',
          grounded ? 'grounded_ok' : 'data_unavailable',
          'RAG query audit: chunks=[${chunkIds.join(',')}] grounded=$grounded',
        ],
      );
    } catch (_) {
      // Non-blocking log
    }
  }

  /// Run end-to-end RAG pipeline with verification guard and retry logic
  /// (port of runRAGPipeline).
  static Future<GroundedResponse> runRAGPipeline(
    String question,
    List<RetrievedChunk> retrievedChunks, {
    String language = 'en',
    String? sessionId,
    String? trade,
    String? location,
  }) async {
    // 1. Check if empty chunks
    if (retrievedChunks.isEmpty) {
      if (sessionId != null) {
        await logRAGAudit(sessionId, trade, [], false);
        await DatabaseService().query(
          'INSERT INTO coverage_gaps (id, trade, location, question, created_at) VALUES (\$1, \$2, \$3, \$4, NOW())',
          [
            'gap_${DateTime.now().millisecondsSinceEpoch}',
            trade ?? 'Unknown',
            location ?? 'Unknown',
            question,
          ],
        );
      }
      return const GroundedResponse(
        answer: '$UNAVAILABLE_MESSAGE\nA human counsellor has been notified to assist your family.',
        citations: [],
        concern: 'general',
        grounded: false,
      );
    }

    // 2. Generate grounded answer (First Attempt)
    var genRes = await GroundedGenService.generateGroundedAnswer(question, retrievedChunks, language: language, stricter: false);

    // Filter cited chunks
    var cited = retrievedChunks.where((c) => genRes.citations.contains(c.id)).toList();
    if (cited.isEmpty) cited = retrievedChunks;

    // 3. Post-generation Verification Guard
    final verify1 = verifyAnswerGrounding(genRes.answer, cited);

    if (verify1['verified'] != true) {
      // Verification guard failed on 1st attempt. Hallucinated numbers: verify1['ungroundedNumbers']
      // Retry once with stricter prompt
      genRes = await GroundedGenService.generateGroundedAnswer(question, retrievedChunks, language: language, stricter: true);
      var cited2 = retrievedChunks.where((c) => genRes.citations.contains(c.id)).toList();
      if (cited2.isEmpty) cited2 = retrievedChunks;

      final verify2 = verifyAnswerGrounding(genRes.answer, cited2);
      if (verify2['verified'] != true) {
        // Verification guard failed on 2nd attempt. Replacing with unavailable message.
        if (sessionId != null) {
          await logRAGAudit(sessionId, trade, [], false);
        }
        return GroundedResponse(
          answer: '$UNAVAILABLE_MESSAGE\nA human counsellor will review this query.',
          citations: [],
          concern: genRes.concern,
          grounded: false,
        );
      }
    }

    if (sessionId != null) {
      await logRAGAudit(sessionId, trade, genRes.citations, true);
    }

    return genRes;
  }

  static String _randomSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

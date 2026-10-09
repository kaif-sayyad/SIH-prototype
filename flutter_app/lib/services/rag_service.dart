import '../backend/rag/verification_service.dart';

/// Flutter facade over the converted RAG verification guard
/// (backend/rag/verification_service.dart).
class RagService {
  static const String unavailableMessage =
      'Verified data for this specific trade/location is currently unavailable.';

  /// Extracts numbers, percentages, durations, currency amounts from text
  /// (port of extractNumbersFromText).
  static Set<num> extractNumbersFromText(String text) {
    final strings = VerificationService.extractNumbersFromText(text);
    return strings.map((s) => num.tryParse(s) ?? 0).where((n) => n != 0).toSet();
  }

  /// Verification Guard: ensures no invented figures appear in the answer.
  /// String-evidence variant matching the original facade signature.
  static bool verifyAnswerGrounding(String answer, String evidence) {
    final answerNumbers = extractNumbersFromText(answer);
    if (answerNumbers.isEmpty) return true;
    final evidenceNumbers = extractNumbersFromText(evidence);

    for (final n in answerNumbers) {
      final hasCloseMatch = evidenceNumbers.any((en) => (en - n).abs() < 0.01);
      if (!hasCloseMatch) {
        return false; // Hallucinated number detected
      }
    }
    return true;
  }
}

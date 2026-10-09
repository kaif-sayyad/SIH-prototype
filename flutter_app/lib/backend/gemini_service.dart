import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'config_service.dart';

/// Port of backend lib/gemini.ts — Gemini API client using the REST API
/// (Flutter equivalent of @google/genai SDK).

class GeminiServiceBackend {
  Future<String> get apiKey async => (await ConfigService.getConfig()).geminiApiKey;
  Future<String> get model async => (await ConfigService.getConfig()).geminiModel;
  Future<String> get embeddingModel async =>
      (await ConfigService.getConfig()).geminiEmbeddingModel;
  Future<bool> get hasValidKey async => ConfigService.hasValidGeminiKey();

  Future<String> get _endpoint async {
    final m = await model;
    return 'https://generativelanguage.googleapis.com/v1beta/models/$m';
  }

  /// Generate embedding vector (768 dimensions) for a text passage
  /// (port of generateEmbedding).
  Future<List<double>> generateEmbedding(String text) async {
    if (await hasValidKey) {
      try {
        final embModel = await embeddingModel;
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$embModel:embedContent?key=${await apiKey}');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': {
              'parts': [
                {'text': text}
              ]
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final values = data['embedding']?['values'];
          if (values is List) {
            return values.map((e) => (e as num).toDouble()).toList();
          }
          final embList = data['embeddings'] as List?;
          if (embList != null && embList.isNotEmpty) {
            final values2 = embList[0]?['values'];
            if (values2 is List) {
              return values2.map((e) => (e as num).toDouble()).toList();
            }
          }
        }
      } catch (err) {
        // Gemini API embedContent failed, falling back to deterministic vector
      }
    }

    // Fallback 768-dim deterministic vector based on string hash for offline testing
    final vector = List<double>.filled(768, 0.0);
    int hash = 0;
    for (var i = 0; i < text.length; i++) {
      hash = (hash << 5) - hash + text.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    for (var i = 0; i < 768; i++) {
      vector[i] = sin((hash + i) * 0.1);
    }
    return vector;
  }

  /// Generate structured JSON content using Gemini (port of generateJSON)
  Future<Map<String, dynamic>?> generateJSON(String systemInstruction, String userPrompt) async {
    if (!await hasValidKey) return null;

    try {
      final endpoint = await _endpoint;
      final url = Uri.parse('$endpoint:generateContent?key=${await apiKey}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': '$systemInstruction\n\nUser request: $userPrompt'}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.2,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return _parseJsonLoose(text);
        }
      }
    } catch (err) {
      // Gemini generateJSON failed
    }
    return null;
  }

  /// Test AI Connection for Admin Panel (port of testGeminiConnection)
  Future<Map<String, dynamic>> testGeminiConnection() async {
    if (!await hasValidKey) {
      return {
        'success': false,
        'message': 'AI key not set or placeholder key present in config',
      };
    }

    try {
      final endpoint = await _endpoint;
      final url = Uri.parse('$endpoint:generateContent?key=${await apiKey}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Respond with OK if connected.'}
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
        if (text.isNotEmpty) {
          return {
            'success': true,
            'message': 'Successfully connected to Gemini API (${await model}). Response: ${text.trim()}',
          };
        }
        return {'success': false, 'message': 'Gemini API returned empty response'};
      }
      return {
        'success': false,
        'message': 'Gemini API returned status ${response.statusCode}',
      };
    } catch (err) {
      return {
        'success': false,
        'message': 'Gemini API connection error: $err',
      };
    }
  }

  Map<String, dynamic>? _parseJsonLoose(String text) {
    var t = text.trim();
    // Strip markdown code fences if the model wrapped the JSON
    if (t.startsWith('```')) {
      t = t.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Try to extract the first {...} block
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(t.substring(start, end + 1));
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          // ignore
        }
      }
    }
    return null;
  }
}

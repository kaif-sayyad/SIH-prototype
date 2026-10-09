import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../database_service.dart';
import '../gemini_service.dart';

/// Port of backend lib/rag/ingest.ts — dataset normalization, ingestion
/// and knowledge-file indexing from bundled assets.

class IngestResult {
  final String datasetVersion;
  final int totalRows;
  final int validRows;
  final List<Map<String, dynamic>> rejectedRows;
  final int chunksCreated;
  final int guidesProcessed;

  const IngestResult({
    required this.datasetVersion,
    required this.totalRows,
    required this.validRows,
    required this.rejectedRows,
    required this.chunksCreated,
    required this.guidesProcessed,
  });
}

class NormalizedRow {
  final String trade;
  final String location;
  final String provider;
  final double? placement;
  final double? earnings;
  final int? nsqf;
  final int? duration;
  final double? cost;
  final String minEdu;
  final List<String> jobRoles;
  final List<String> progression;
  final String furtherEdu;
  final String source;
  final String dataDate;
  final Map<String, dynamic> raw;

  const NormalizedRow({
    required this.trade,
    required this.location,
    required this.provider,
    required this.placement,
    required this.earnings,
    required this.nsqf,
    required this.duration,
    required this.cost,
    required this.minEdu,
    required this.jobRoles,
    required this.progression,
    required this.furtherEdu,
    required this.source,
    required this.dataDate,
    required this.raw,
  });
}

class IngestService {
  static String _str(Map<String, dynamic> r, List<String> keys, [String def = '']) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return def;
  }

  /// Standardize input fields using alias mapping table (port of normalizeRow)
  static NormalizedRow normalizeRow(Map<String, dynamic> r) {
    final trade = _str(r, ['trade', 'course']);
    final location = _str(r, ['location', 'city', 'district']);
    final provider = _str(r, ['provider', 'institute'], 'Approved ITI / Skills Centre');

    double? placement;
    final rawVal = r['placement_rate'] ?? r['placement'] ?? r['placement_pct'];
    if (rawVal != null && rawVal.toString().trim().isNotEmpty) {
      final p = double.tryParse(rawVal.toString().replaceAll('%', ''));
      if (p != null) placement = p;
    }

    double? earnings;
    final rawEarn = r['avg_earnings'] ?? r['average_salary'] ?? r['salary'] ?? r['earnings'];
    if (rawEarn != null && rawEarn.toString().trim().isNotEmpty) {
      final cleaned = rawEarn.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      final e = double.tryParse(cleaned);
      if (e != null) earnings = e;
    }

    int? nsqf;
    final rawNsqf = r['nsqf_level'] ?? r['nsqf'];
    if (rawNsqf != null && rawNsqf.toString().trim().isNotEmpty) {
      final n = int.tryParse(rawNsqf.toString());
      if (n != null) nsqf = n;
    }

    int? duration;
    final rawDur = r['duration_months'] ?? r['duration'];
    if (rawDur != null && rawDur.toString().trim().isNotEmpty) {
      final d = int.tryParse(rawDur.toString());
      if (d != null) duration = d;
    }

    double? cost;
    final rawCost = r['training_cost'] ?? r['cost'];
    if (rawCost != null && rawCost.toString().trim().isNotEmpty) {
      final cleaned = rawCost.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      final c = double.tryParse(cleaned);
      if (c != null) cost = c;
    }

    final minEdu = _str(r, ['min_education', 'entry_qualification'], '10th pass');
    final furtherEdu = _str(r, ['further_education'],
        'Polytechnic Diploma (lateral entry), NSQF Level 5');
    final source = _str(r, ['source'], 'MSDE Vocational Survey 2026');
    final dataDate = _str(r, ['data_date'], '2026-01');

    List<String> jobRoles = [trade];
    final rawRoles = r['job_roles'];
    if (rawRoles != null) {
      if (rawRoles is List) {
        jobRoles = rawRoles.map((e) => e.toString()).toList();
      } else {
        jobRoles = rawRoles.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    List<String> progression = ['Training', trade, 'Senior Specialist', 'Supervisor'];
    final rawProg = r['progression'];
    if (rawProg != null) {
      if (rawProg is List) {
        progression = rawProg.map((e) => e.toString()).toList();
      } else {
        progression = rawProg.toString().split(RegExp(r'->|,')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    return NormalizedRow(
      trade: trade,
      location: location,
      provider: provider,
      placement: placement,
      earnings: earnings,
      nsqf: nsqf,
      duration: duration,
      cost: cost,
      minEdu: minEdu,
      jobRoles: jobRoles,
      progression: progression,
      furtherEdu: furtherEdu,
      source: source,
      dataDate: dataDate,
      raw: r,
    );
  }

  /// Parse a CSV string (with header) into raw outcome rows.
  static List<Map<String, dynamic>> parseCsvRows(String csvContent) {
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) return [];
    final header = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).where((row) => row.any((cell) => cell.toString().trim().isNotEmpty)).map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < header.length && i < row.length; i++) {
        map[header[i]] = row[i];
      }
      return map;
    }).toList();
  }

  /// Ingest a dataset version (port of ingestDataset).
  static Future<IngestResult> ingestDataset(
    String version,
    String filename,
    List<Map<String, dynamic>> rows,
  ) async {
    final dbService = DatabaseService();
    final gemini = GeminiServiceBackend();
    final rejectedRows = <Map<String, dynamic>>[];
    int validCount = 0;
    int chunksCreated = 0;

    final datasetId = 'dataset_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(5)}';
    await dbService.query(
      'INSERT INTO datasets (id, version, filename, total_rows, valid_rows, rejected_rows, uploaded_at) VALUES (\$1, \$2, \$3, \$4, 0, 0, NOW())',
      [datasetId, version, filename, rows.length],
    );

    for (var idx = 0; idx < rows.length; idx++) {
      final rawR = rows[idx];
      final rowNum = idx + 1;
      final norm = normalizeRow(rawR);

      // Validation checks
      if (norm.trade.isEmpty || norm.location.isEmpty) {
        rejectedRows.add({'row': rowNum, 'data': rawR, 'reason': 'Missing required trade or location'});
        continue;
      }

      if (norm.placement != null && (norm.placement! < 0 || norm.placement! > 100)) {
        rejectedRows.add({'row': rowNum, 'data': rawR, 'reason': 'Invalid placement rate (must be 0-100): ${norm.placement}'});
        continue;
      }

      if (norm.earnings != null && norm.earnings! < 0) {
        rejectedRows.add({'row': rowNum, 'data': rawR, 'reason': 'Invalid avg_earnings: ${norm.earnings}'});
        continue;
      }

      if (norm.nsqf != null && (norm.nsqf! < 1 || norm.nsqf! > 10)) {
        rejectedRows.add({'row': rowNum, 'data': rawR, 'reason': 'Invalid NSQF level (1-10): ${norm.nsqf}'});
        continue;
      }

      final outcomeId =
          'out_${norm.trade.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_${norm.location.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_$idx';

      await dbService.query('DELETE FROM outcome_chunks WHERE trade = \$1 AND location = \$2', [norm.trade, norm.location]);
      await dbService.query('DELETE FROM outcomes WHERE trade = \$1 AND location = \$2', [norm.trade, norm.location]);

      await dbService.query(
        'INSERT INTO outcomes (id, trade, location, provider, placement_rate, avg_earnings, nsqf_level, duration_months, training_cost, min_education, job_roles, progression, further_education, source, data_date, dataset_version) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16)',
        [
          outcomeId,
          norm.trade,
          norm.location,
          norm.provider,
          norm.placement,
          norm.earnings,
          norm.nsqf,
          norm.duration,
          norm.cost,
          norm.minEdu,
          jsonEncode(norm.jobRoles),
          jsonEncode(norm.progression),
          norm.furtherEdu,
          norm.source,
          norm.dataDate,
          version,
        ],
      );

      validCount++;

      // Generate topic fact chunks
      final topicFacts = <Map<String, String>>[];

      if (norm.placement != null) {
        topicFacts.add({
          'topic': 'placement',
          'text': '${norm.trade} in ${norm.location}: ${norm.placement}% of trainees were placed in jobs (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.earnings != null) {
        topicFacts.add({
          'topic': 'earnings',
          'text': '${norm.trade} in ${norm.location}: average earnings ₹${_formatINR(norm.earnings!)} per month for entry-level positions (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.progression.isNotEmpty) {
        topicFacts.add({
          'topic': 'progression',
          'text': 'Career progression for ${norm.trade}: typical path is ${norm.progression.join(' -> ')} (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.furtherEdu.isNotEmpty) {
        topicFacts.add({
          'topic': 'education',
          'text': 'Further education options after ${norm.trade}: ${norm.furtherEdu} (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.cost != null || norm.duration != null) {
        final costStr = norm.cost != null ? 'estimated training fee ₹${_formatINR(norm.cost!)}' : '';
        final durStr = norm.duration != null ? 'duration of ${norm.duration} months' : '';
        final combined = [durStr, costStr].where((s) => s.isNotEmpty).join(' and ');
        topicFacts.add({
          'topic': 'cost',
          'text': '${norm.trade} course details in ${norm.location}: $combined (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.provider.isNotEmpty) {
        topicFacts.add({
          'topic': 'providers',
          'text': 'Training providers for ${norm.trade} in ${norm.location}: ${norm.provider} (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      if (norm.nsqf != null) {
        topicFacts.add({
          'topic': 'nsqf',
          'text': '${norm.trade} is certified at National Skills Qualifications Framework (NSQF) Level ${norm.nsqf} (source: ${norm.source}, date: ${norm.dataDate}).',
        });
      }

      for (var cIdx = 0; cIdx < topicFacts.length; cIdx++) {
        final f = topicFacts[cIdx];
        final chunkId = 'chk_${outcomeId}_${f['topic']}_$cIdx';
        final embedding = await gemini.generateEmbedding(f['text']!);

        await dbService.query(
          'INSERT INTO outcome_chunks (id, outcome_id, topic, text, trade, location, source, data_date, embedding) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)',
          [chunkId, outcomeId, f['topic'], f['text'], norm.trade, norm.location, norm.source, norm.dataDate, embedding],
        );
        chunksCreated++;
      }
    }

    await dbService.query(
      'UPDATE datasets SET valid_rows = \$1, rejected_rows = \$2 WHERE version = \$3',
      [validCount, rejectedRows.length, version],
    );

    return IngestResult(
      datasetVersion: version,
      totalRows: rows.length,
      validRows: validCount,
      rejectedRows: rejectedRows,
      chunksCreated: chunksCreated,
      guidesProcessed: 0,
    );
  }

  /// Reload all knowledge files (port of loadKnowledgeFiles).
  /// In Flutter this ingests the bundled `assets/knowledge/` content.
  static Future<Map<String, dynamic>> loadKnowledgeFiles() async {
    await DatabaseService().getDb();

    int guideChunksCount = 0;
    IngestResult? outcomesResult;

    // 1. Ingest bundled outcomes.csv
    try {
      final csvContent = await rootBundle.loadString('assets/knowledge/outcomes.csv');
      final rows = parseCsvRows(csvContent);
      outcomesResult = await ingestDataset('knowledge_v1', 'outcomes.csv', rows);
    } catch (_) {
      // Asset missing - leave outcomes empty
    }

    // 2. Ingest bundled guides/*.md
    final guideFiles = ['guides/faq.md'];
    for (final filename in guideFiles) {
      try {
        final content = await rootBundle.loadString('assets/knowledge/$filename');
        final baseName = filename.split('/').last;

        // Split by heading (## or #)
        final sections = content.split(RegExp(r'(?=\n##?\s+)'));
        final gemini = GeminiServiceBackend();
        final dbService = DatabaseService();

        for (var sIdx = 0; sIdx < sections.length; sIdx++) {
          final secText = sections[sIdx].trim();
          if (secText.isEmpty) continue;

          final headingMatch = RegExp(r'^##?\s+(.*)', multiLine: true).firstMatch(secText);
          final heading = headingMatch != null ? headingMatch.group(1)!.trim() : 'General Guide';

          var topic = 'general';
          final hLower = heading.toLowerCase();
          if (hLower.contains('income') || hLower.contains('financial')) {
            topic = 'earnings';
          } else if (hLower.contains('perception') || hLower.contains('respect')) {
            topic = 'social';
          } else if (hLower.contains('safety')) {
            topic = 'safety';
          } else if (hLower.contains('growth') || hLower.contains('lateral')) {
            topic = 'progression';
          }

          final chunkId = 'chk_guide_${baseName}_$sIdx';
          final embedding = await gemini.generateEmbedding(secText);

          await dbService.query(
            'INSERT INTO outcome_chunks (id, outcome_id, topic, text, trade, location, source, data_date, embedding, file_path) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10)',
            [
              chunkId,
              'guide_$baseName',
              topic,
              secText,
              'All Vocational Trades',
              'All Districts',
              baseName,
              '2026-01',
              embedding,
              'assets/knowledge/$filename',
            ],
          );
          guideChunksCount++;
        }
      } catch (_) {
        // Guide asset missing
      }
    }

    return {
      'outcomesResult': outcomesResult,
      'guideChunks': guideChunksCount,
    };
  }

  static String _formatINR(double value) {
    final isWhole = value == value.roundToDouble();
    final s = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return _groupDigits(s);
  }

  static String _groupDigits(String s) {
    final parts = s.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (intPart.length <= 3) return intPart + decPart;
    final last3 = intPart.substring(intPart.length - 3);
    var rest = intPart.substring(0, intPart.length - 3);
    rest = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
    return '$rest,$last3$decPart';
  }

  static String _randomSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(len, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

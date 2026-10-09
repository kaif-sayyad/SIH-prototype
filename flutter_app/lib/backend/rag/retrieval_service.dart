import '../database_service.dart';
import '../gemini_service.dart';
import 'ingest_service.dart';

/// Port of backend lib/rag/retrieval.ts — entity extraction and
/// hybrid (structured + keyword) evidence retrieval.

class RetrievedChunk {
  final String id;
  final String outcomeId;
  final String topic;
  final String text;
  final String trade;
  final String location;
  final String source;
  final String dataDate;
  final double? distance;
  final String matchType; // 'exact' | 'trade_other_location' | 'semantic'

  const RetrievedChunk({
    required this.id,
    required this.outcomeId,
    required this.topic,
    required this.text,
    required this.trade,
    required this.location,
    required this.source,
    required this.dataDate,
    this.distance,
    required this.matchType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'outcome_id': outcomeId,
        'topic': topic,
        'text': text,
        'trade': trade,
        'location': location,
        'source': source,
        'data_date': dataDate,
        'distance': distance,
        'matchType': matchType,
      };
}

class ExtractedQuery {
  final String? trade;
  final String? location;
  final String? topic;

  const ExtractedQuery({this.trade, this.location, this.topic});

  factory ExtractedQuery.fromJson(Map<String, dynamic> json) => ExtractedQuery(
        trade: json['trade'] as String?,
        location: json['location'] as String?,
        topic: json['topic'] as String?,
      );

  Map<String, dynamic> toJson() => {'trade': trade, 'location': location, 'topic': topic};
}

class RetrievalService {
  /// Extract trade/location/topic entities from the question (port of extractQueryEntities).
  static Future<ExtractedQuery> extractQueryEntities(
    String question, {
    String? profileTrade,
    String? profileLocation,
  }) async {
    const prompt = 'Extract career/vocational trade name, location (city/district in India), and concern topic from the user question.\n'
        'Topics must be one of: "placement", "earnings", "progression", "education", "cost", "providers", "nsqf", "safety", "social".\n'
        'If trade or location is not explicitly stated in the question, return null for them so we can fall back to the profile context.\n'
        'Return JSON format: {"trade": string | null, "location": string | null, "topic": string | null}';

    final res = await GeminiServiceBackend().generateJSON(prompt, question);
    var entities = ExtractedQuery(
      trade: res?['trade'] as String?,
      location: res?['location'] as String?,
      topic: res?['topic'] as String?,
    );

    var trade = entities.trade;
    var location = entities.location;
    var topic = entities.topic;

    final qLower = question.toLowerCase();

    // Rule-based fallback entity extraction
    if (trade == null || trade.isEmpty) {
      if (RegExp(r'electrician|विद्युत').hasMatch(qLower)) {
        trade = 'Electrician';
      } else if (RegExp(r'solar|सौर').hasMatch(qLower)) {
        trade = 'Solar Technician';
      } else if (RegExp(r'cnc|vmc|मशीन').hasMatch(qLower)) {
        trade = 'CNC Operator';
      } else if (RegExp(r'plumber|प्लंबर').hasMatch(qLower)) {
        trade = 'Plumber';
      } else if (RegExp(r'welder|वेल्डर').hasMatch(qLower)) {
        trade = 'Welder';
      } else if (RegExp(r'auto|car|vehicle|ऑटोमॉबाईल').hasMatch(qLower)) {
        trade = 'Automotive Technician';
      } else if (RegExp(r'fitter|फिटर').hasMatch(qLower)) {
        trade = 'Fitter';
      } else if (RegExp(r'turner|टर्नर').hasMatch(qLower)) {
        trade = 'Turner';
      } else if (RegExp(r'rac|ac|cooling').hasMatch(qLower)) {
        trade = 'RAC Technician';
      } else if (RegExp(r'draftsman|draughtsman|design').hasMatch(qLower)) {
        trade = 'Draughtsman Mechanical';
      } else {
        trade = profileTrade;
      }
    }

    if (location == null || location.isEmpty) {
      if (RegExp(r'nagpur|नागपूर').hasMatch(qLower)) {
        location = 'Nagpur';
      } else if (RegExp(r'pune|पुणे').hasMatch(qLower)) {
        location = 'Pune';
      } else if (RegExp(r'mumbai|मुंबई').hasMatch(qLower)) {
        location = 'Mumbai';
      } else {
        location = profileLocation;
      }
    }

    if (topic == null || topic.isEmpty) {
      if (RegExp(r'job|placement|work|employ|नोकरी').hasMatch(qLower)) {
        topic = 'placement';
      } else if (RegExp(r'salary|earn|income|pay|money|पगार|कमाई').hasMatch(qLower)) {
        topic = 'earnings';
      } else if (RegExp(r'growth|promot|future|career|प्रगती').hasMatch(qLower)) {
        topic = 'progression';
      } else if (RegExp(r'degree|diploma|study|higher|education|शिक्षण').hasMatch(qLower)) {
        topic = 'education';
      } else if (RegExp(r'fee|cost|afford|price|खर्च').hasMatch(qLower)) {
        topic = 'cost';
      } else if (RegExp(r'safe|danger|accident|सुरक्षा').hasMatch(qLower)) {
        topic = 'safety';
      } else if (RegExp(r'status|respect|society|relative|समाज').hasMatch(qLower)) {
        topic = 'social';
      }
    }

    return ExtractedQuery(trade: trade, location: location, topic: topic);
  }

  /// Retrieve evidence chunks (port of retrieveEvidence).
  static Future<Map<String, dynamic>> retrieveEvidence(
    String question, {
    String? profileTrade,
    String? profileLocation,
  }) async {
    final dbService = DatabaseService();
    final db = await dbService.getDb();

    if (db.outcomeChunks.isEmpty) {
      await IngestService.loadKnowledgeFiles();
    }

    final entities =
        await extractQueryEntities(question, profileTrade: profileTrade, profileLocation: profileLocation);
    final trade = profileTrade ?? entities.trade;
    final location = profileLocation ?? entities.location;
    final topic = entities.topic;

    final chunksMap = <String, RetrievedChunk>{};

    // 1. Structured Filter First: trade + location (+ topic if available)
    if (trade != null && trade.isNotEmpty && location != null && location.isNotEmpty) {
      var structSql =
          'SELECT id, outcome_id, topic, text, trade, location, source, data_date FROM outcome_chunks WHERE LOWER(trade) = LOWER(\$1) AND LOWER(location) = LOWER(\$2)';
      final params = <dynamic>[trade, location];

      if (topic != null && topic.isNotEmpty) {
        structSql += ' AND LOWER(topic) = LOWER(\$3)';
        params.add(topic);
      }

      final structRes = await dbService.query(structSql, params);
      for (final r in structRes.rows) {
        chunksMap[r['id'] as String] = RetrievedChunk(
          id: r['id'] as String,
          outcomeId: r['outcome_id'] as String,
          topic: r['topic'] as String,
          text: r['text'] as String,
          trade: r['trade'] as String,
          location: r['location'] as String,
          source: r['source'] as String,
          dataDate: r['data_date'] as String,
          matchType: 'exact',
          distance: 0.0,
        );
      }
    }

    // 2. Structured Filter Fallback: same trade, other locations
    if (trade != null && trade.isNotEmpty && chunksMap.isEmpty) {
      var otherLocSql =
          'SELECT id, outcome_id, topic, text, trade, location, source, data_date FROM outcome_chunks WHERE LOWER(trade) = LOWER(\$1)';
      final params = <dynamic>[trade];
      if (topic != null && topic.isNotEmpty) {
        otherLocSql += ' AND LOWER(topic) = LOWER(\$2)';
        params.add(topic);
      }
      final otherRes = await dbService.query(otherLocSql, params);
      for (final r in otherRes.rows) {
        chunksMap[r['id'] as String] = RetrievedChunk(
          id: r['id'] as String,
          outcomeId: r['outcome_id'] as String,
          topic: r['topic'] as String,
          text: r['text'] as String,
          trade: r['trade'] as String,
          location: r['location'] as String,
          source: r['source'] as String,
          dataDate: r['data_date'] as String,
          matchType: 'trade_other_location',
          distance: 0.1,
        );
      }
    }

    // CRITICAL STRICT CHECK: If a trade was specified and no trade chunks exist in outcome dataset:
    if (trade != null && trade.isNotEmpty) {
      final hasTradeInDb = db.outcomeChunks.any((c) => c.trade.toLowerCase() == trade.toLowerCase());
      if (!hasTradeInDb) {
        return {'chunks': <RetrievedChunk>[], 'entities': entities};
      }
    }

    // 3. Keyword / BM25 Search Fallback (Only if trade is supported or null)
    if (chunksMap.isEmpty) {
      final qKeywords = question.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toList();

      for (final chk in db.outcomeChunks) {
        final textLower = chk.text.toLowerCase();
        int matchCount = 0;
        for (final kw in qKeywords) {
          if (textLower.contains(kw)) matchCount++;
        }
        if (matchCount > 0) {
          chunksMap[chk.id] = RetrievedChunk(
            id: chk.id,
            outcomeId: chk.outcomeId,
            topic: chk.topic,
            text: chk.text,
            trade: chk.trade,
            location: chk.location,
            source: chk.source,
            dataDate: chk.dataDate,
            matchType: 'semantic',
            distance: 0.3 - matchCount * 0.05,
          );
        }
      }
    }

    // 4. Merge & Rerank
    final results = chunksMap.values.toList()
      ..sort((a, b) {
        const rank = {'exact': 1, 'trade_other_location': 2, 'semantic': 3};
        if (rank[a.matchType] != rank[b.matchType]) {
          return rank[a.matchType]!.compareTo(rank[b.matchType]!);
        }
        return (a.distance ?? 0).compareTo(b.distance ?? 0);
      });

    return {'chunks': results.take(6).toList(), 'entities': entities};
  }
}

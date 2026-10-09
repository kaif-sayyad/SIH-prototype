import '../backend/database_service.dart';
import '../backend/rag/ingest_service.dart';
import '../models/trade_outcome.dart';

/// Flutter facade over the converted backend outcome database.
///
/// The verified outcome list is no longer hardcoded: it is served from
/// the local JSON database (backend/database_service.dart), seeded from
/// the bundled `assets/knowledge/outcomes.csv` (backend/rag/ingest_service.dart)
/// exactly like the Node backend's `loadKnowledgeFiles()`.
class KnowledgeService {
  static List<TradeOutcome> _cache = [];
  static bool _seeded = false;

  /// Seed the local database from bundled knowledge assets (idempotent).
  /// Mirrors the backend's knowledge re-indexing on first RAG query.
  static Future<void> ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;
    final db = await DatabaseService().getDb();
    if (db.outcomes.isEmpty) {
      await IngestService.loadKnowledgeFiles();
    }
    await refreshCache();
  }

  /// Refresh the in-memory verified outcome cache from the database.
  static Future<void> refreshCache() async {
    final db = await DatabaseService().getDb();
    _cache = db.outcomes.map((o) => _fromOutcomeRecord(o)).toList();
  }

  static TradeOutcome _fromOutcomeRecord(OutcomeRecord o) => TradeOutcome(
        trade: o.trade,
        provider: o.provider ?? 'Approved ITI / Skills Centre',
        location: o.location,
        placementRate: o.placementRate ?? 0.0,
        avgEarnings: (o.avgEarnings ?? 0).toInt(),
        nsqfLevel: o.nsqfLevel ?? 4,
        durationMonths: o.durationMonths ?? 12,
        trainingCost: (o.trainingCost ?? 0).toInt(),
        minEducation: o.minEducation ?? '10th pass',
        jobRoles: (o.jobRoles.isNotEmpty ? o.jobRoles.join(', ') : o.trade),
        progression: (o.progression.isNotEmpty ? o.progression.join(' -> ') : ''),
        furtherEducation: o.furtherEducation ??
            'Polytechnic Diploma (lateral entry), NSQF Level 5',
        source: o.source ?? 'MSDE Vocational Survey 2026',
        dataDate: o.dataDate ?? '2026-01',
      );

  /// Verified outcome records loaded from the local backend database.
  /// Call [ensureSeeded] first (async) for the full dataset.
  static List<TradeOutcome> get verifiedOutcomes => _cache;

  /// Search verified outcomes by trade and/or district (port of the
  /// backend's structured outcome query).
  static List<TradeOutcome> searchOutcomes({String? trade, String? location}) {
    return _cache.where((o) {
      final matchesTrade = trade == null ||
          trade.isEmpty ||
          o.trade.toLowerCase().contains(trade.toLowerCase());
      final matchesLocation = location == null ||
          location.isEmpty ||
          o.location.toLowerCase().contains(location.toLowerCase());
      return matchesTrade && matchesLocation;
    }).toList();
  }

  static TradeOutcome? findExact(String trade) {
    try {
      return _cache.firstWhere(
        (o) => o.trade.toLowerCase() == trade.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

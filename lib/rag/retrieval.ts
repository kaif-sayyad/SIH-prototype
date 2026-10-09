import { query, vectorSearchOutcomeChunks, getDb } from '../db';
import { generateEmbedding, generateJSON } from '../gemini';
import { loadKnowledgeFiles } from './ingest';

export interface RetrievedChunk {
  id: string;
  outcome_id: string;
  topic: string;
  text: string;
  trade: string;
  location: string;
  source: string;
  data_date: string;
  distance?: number;
  matchType: 'exact' | 'trade_other_location' | 'semantic';
}

export interface ExtractedQuery {
  trade: string | null;
  location: string | null;
  topic: string | null;
}

export async function extractQueryEntities(
  question: string,
  profileTrade?: string,
  profileLocation?: string
): Promise<ExtractedQuery> {
  const prompt = `Extract career/vocational trade name, location (city/district in India), and concern topic from the user question.
Topics must be one of: "placement", "earnings", "progression", "education", "cost", "providers", "nsqf", "safety", "social".
If trade or location is not explicitly stated in the question, return null for them so we can fall back to the profile context.
Return JSON format: {"trade": string | null, "location": string | null, "topic": string | null}`;

  const res = await generateJSON<ExtractedQuery>(prompt, question);

  let trade = res?.trade || null;
  let location = res?.location || null;
  let topic = res?.topic || null;

  const qLower = question.toLowerCase();

  // Rule-based fallback entity extraction
  if (!trade) {
    if (/electrician|विद्युत/.test(qLower)) trade = 'Electrician';
    else if (/solar|सौर/.test(qLower)) trade = 'Solar Technician';
    else if (/cnc|vmc|मशीन/.test(qLower)) trade = 'CNC Operator';
    else if (/plumber|प्लंबर/.test(qLower)) trade = 'Plumber';
    else if (/welder|वेल्डर/.test(qLower)) trade = 'Welder';
    else if (/auto|car|vehicle|ऑटोमॉबाईल/.test(qLower)) trade = 'Automotive Technician';
    else if (/fitter|फिटर/.test(qLower)) trade = 'Fitter';
    else if (/turner|टर्नर/.test(qLower)) trade = 'Turner';
    else if (/rac|ac|cooling/.test(qLower)) trade = 'RAC Technician';
    else if (/draftsman|draughtsman|design/.test(qLower)) trade = 'Draughtsman Mechanical';
    else trade = profileTrade || null;
  }

  if (!location) {
    if (/nagpur|नागपूर/.test(qLower)) location = 'Nagpur';
    else if (/pune|पुणे/.test(qLower)) location = 'Pune';
    else if (/mumbai|मुंबई/.test(qLower)) location = 'Mumbai';
    else location = profileLocation || null;
  }

  if (!topic) {
    if (/job|placement|work|employ|नोकरी/.test(qLower)) topic = 'placement';
    else if (/salary|earn|income|pay|money|पगार|कमाई/.test(qLower)) topic = 'earnings';
    else if (/growth|promot|future|career|प्रगती/.test(qLower)) topic = 'progression';
    else if (/degree|diploma|study|higher|education|शिक्षण/.test(qLower)) topic = 'education';
    else if (/fee|cost|afford|price|खर्च/.test(qLower)) topic = 'cost';
    else if (/safe|danger|accident|सुरक्षा/.test(qLower)) topic = 'safety';
    else if (/status|respect|society|relative|समाज/.test(qLower)) topic = 'social';
  }

  return { trade, location, topic };
}

export async function retrieveEvidence(
  question: string,
  profileTrade?: string,
  profileLocation?: string
): Promise<{ chunks: RetrievedChunk[]; entities: ExtractedQuery }> {
  const db = await getDb();

  if (db.outcome_chunks.length === 0) {
    await loadKnowledgeFiles();
  }

  const entities = await extractQueryEntities(question, profileTrade, profileLocation);
  const trade = profileTrade || entities.trade;
  const location = profileLocation || entities.location;
  const topic = entities.topic;

  const chunksMap = new Map<string, RetrievedChunk>();

  // 1. Structured Filter First: trade + location (+ topic if available)
  if (trade && location) {
    let structSql = `
      SELECT id, outcome_id, topic, text, trade, location, source, data_date
      FROM outcome_chunks
      WHERE LOWER(trade) = LOWER($1) AND LOWER(location) = LOWER($2)
    `;
    const params: any[] = [trade, location];

    if (topic) {
      structSql += ` AND LOWER(topic) = LOWER($3)`;
      params.push(topic);
    }

    const structRes = await query(structSql, params);
    for (const r of structRes.rows) {
      chunksMap.set(r.id, {
        ...r,
        matchType: 'exact',
        distance: 0.0,
      });
    }
  }

  // 2. Structured Filter Fallback: same trade, other locations
  if (trade && chunksMap.size === 0) {
    let otherLocSql = `
      SELECT id, outcome_id, topic, text, trade, location, source, data_date
      FROM outcome_chunks
      WHERE LOWER(trade) = LOWER($1)
    `;
    const params: any[] = [trade];
    if (topic) {
      otherLocSql += ` AND LOWER(topic) = LOWER($2)`;
      params.push(topic);
    }
    const otherRes = await query(otherLocSql, params);
    for (const r of otherRes.rows) {
      chunksMap.set(r.id, {
        ...r,
        matchType: 'trade_other_location',
        distance: 0.1,
      });
    }
  }

  // CRITICAL STRICT CHECK: If a trade was specified (e.g. Aerospace Engineer) and no trade chunks exist in outcome dataset:
  if (trade) {
    const hasTradeInDb = db.outcome_chunks.some(c => c.trade.toLowerCase() === trade.toLowerCase());
    if (!hasTradeInDb) {
      return { chunks: [], entities };
    }
  }

  // 3. Keyword / BM25 Search Fallback (Only if trade is supported or null)
  if (chunksMap.size === 0) {
    const qKeywords = question.toLowerCase().split(/\s+/).filter(w => w.length > 3);
    const dbChunks = db.outcome_chunks;

    for (const chk of dbChunks) {
      const textLower = chk.text.toLowerCase();
      let matchCount = 0;
      for (const kw of qKeywords) {
        if (textLower.includes(kw)) matchCount++;
      }
      if (matchCount > 0) {
        chunksMap.set(chk.id, {
          id: chk.id,
          outcome_id: chk.outcome_id,
          topic: chk.topic,
          text: chk.text,
          trade: chk.trade,
          location: chk.location,
          source: chk.source,
          data_date: chk.data_date,
          matchType: 'semantic',
          distance: 0.3 - matchCount * 0.05,
        });
      }
    }
  }

  // 4. Merge & Rerank
  const results = Array.from(chunksMap.values()).sort((a, b) => {
    const rank = { exact: 1, trade_other_location: 2, semantic: 3 };
    if (rank[a.matchType] !== rank[b.matchType]) {
      return rank[a.matchType] - rank[b.matchType];
    }
    return (a.distance || 0) - (b.distance || 0);
  });

  return { chunks: results.slice(0, 6), entities };
}

import fs from 'fs';
import path from 'path';

export interface UserRecord {
  id: string;
  phone?: string | null;
  email?: string | null;
  name?: string | null;
  role: 'family' | 'parent' | 'counsellor' | 'admin';
  password_hash?: string | null;
  parent_access_code?: string | null;
  language?: string;
  consent?: boolean;
  consent_at?: string;
  created_at: string;
  failed_attempts?: number;
  locked_until?: string | null;
}

export interface SessionRecord {
  id: string;
  user_id?: string | null;
  student_id?: string | null;
  student_profile?: any;
  family_context?: any;
  recommendations?: any;
  pathway?: any;
  status: string; // 'active' | 'completed' | 'escalated'
  current_step?: number;
  messages?: Array<{ sender: 'student' | 'parent' | 'ai' | 'counsellor'; text: string; timestamp: string; citation?: string }>;
  created_at: string;
  updated_at: string;
}

export interface ConcernRecord {
  id: string;
  session_id: string;
  category: string;
  status: 'raised' | 'answered' | 'resolved' | 'unresolved' | 'escalated';
  sentiment?: 'positive' | 'neutral' | 'hesitant' | 'negative';
  sentiment_intensity?: number;
  asked_at: string;
  resolved_at?: string | null;
  evidence_used?: any;
}

export interface SentimentShiftRecord {
  id: string;
  session_id: string;
  concern_category: string;
  district?: string;
  initial_sentiment: string;
  final_sentiment: string;
  shift: 'shifted_positive' | 'unchanged' | 'shifted_negative';
  updated_at: string;
}

export interface OutcomeRecord {
  id: string;
  trade: string;
  location: string;
  provider?: string;
  placement_rate?: number | null;
  avg_earnings?: number | null;
  earnings_min?: number | null;
  earnings_max?: number | null;
  nsqf_level?: number | null;
  duration_months?: number | null;
  training_cost?: number | null;
  min_education?: string;
  job_roles?: string[];
  progression?: string[];
  further_education?: string;
  source?: string;
  data_date?: string;
  dataset_version?: string;
  created_at?: string;
}

export interface ChunkRecord {
  id: string;
  outcome_id: string;
  topic: string;
  text: string;
  trade: string;
  location: string;
  source: string;
  data_date: string;
  embedding?: number[];
  file_path?: string;
}

export interface EscalationRecord {
  id: string;
  session_id: string;
  student_name?: string;
  reason: string;
  status: 'open' | 'in_progress' | 'resolved';
  counsellor_id?: string | null;
  counsellor_notes?: string | null;
  evidence_shown?: any;
  preferred_contact_time?: string;
  preferred_language?: string;
  created_at: string;
  updated_at: string;
}

export interface DatasetRecord {
  id: string;
  version: string;
  filename: string;
  total_rows: number;
  valid_rows: number;
  rejected_rows: number;
  uploaded_at: string;
}

export interface CoverageGapRecord {
  id: string;
  trade?: string;
  location?: string;
  question: string;
  created_at: string;
}

export interface EngagementRecord {
  id: string;
  session_id: string;
  step: number;
  time_spent_seconds?: number;
  parent_joined?: boolean;
  voice_used?: boolean;
  language?: string;
  completed?: boolean;
  created_at: string;
}

export interface DbSchema {
  users: UserRecord[];
  sessions: SessionRecord[];
  concerns: ConcernRecord[];
  sentiment_shifts: SentimentShiftRecord[];
  outcomes: OutcomeRecord[];
  outcome_chunks: ChunkRecord[];
  escalations: EscalationRecord[];
  datasets: DatasetRecord[];
  coverage_gaps: CoverageGapRecord[];
  engagement: EngagementRecord[];
}

const dbDir = path.join(process.cwd(), 'data');
const dbFile = path.join(dbDir, 'db.json');

let dbMemory: DbSchema | null = null;

export function loadDb(): DbSchema {
  if (dbMemory) return dbMemory;

  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  if (fs.existsSync(dbFile)) {
    try {
      const content = fs.readFileSync(dbFile, 'utf8');
      dbMemory = JSON.parse(content);
      // Ensure all arrays exist
      if (!dbMemory!.users) dbMemory!.users = [];
      if (!dbMemory!.sessions) dbMemory!.sessions = [];
      if (!dbMemory!.concerns) dbMemory!.concerns = [];
      if (!dbMemory!.sentiment_shifts) dbMemory!.sentiment_shifts = [];
      if (!dbMemory!.outcomes) dbMemory!.outcomes = [];
      if (!dbMemory!.outcome_chunks) dbMemory!.outcome_chunks = [];
      if (!dbMemory!.escalations) dbMemory!.escalations = [];
      if (!dbMemory!.datasets) dbMemory!.datasets = [];
      if (!dbMemory!.coverage_gaps) dbMemory!.coverage_gaps = [];
      if (!dbMemory!.engagement) dbMemory!.engagement = [];
      return dbMemory!;
    } catch (err) {
      console.warn('Error reading db.json, creating new database schema:', (err as Error).message);
    }
  }

  dbMemory = {
    users: [],
    sessions: [],
    concerns: [],
    sentiment_shifts: [],
    outcomes: [],
    outcome_chunks: [],
    escalations: [],
    datasets: [],
    coverage_gaps: [],
    engagement: [],
  };

  saveDb();
  return dbMemory;
}

export function saveDb(): void {
  if (!dbMemory) return;
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }
  fs.writeFileSync(dbFile, JSON.stringify(dbMemory, null, 2), 'utf8');
}

export async function getDb(): Promise<DbSchema> {
  return loadDb();
}

/**
 * Universal SQL Query compatibility wrapper
 */
export async function query<T = any>(sql: string, params: any[] = []): Promise<{ rows: T[]; rowCount: number }> {
  const db = loadDb();
  const sqlTrimmed = sql.trim().toUpperCase();

  // 1. SELECT queries
  if (sqlTrimmed.startsWith('SELECT')) {
    if (sqlTrimmed.includes('FROM USERS')) {
      let filtered = [...db.users];
      if (sql.includes('WHERE id = $1') || sql.includes('WHERE ID = $1')) {
        filtered = filtered.filter(u => u.id === params[0]);
      } else if (sql.includes('WHERE phone = $1') || sql.includes('WHERE PHONE = $1')) {
        filtered = filtered.filter(u => u.phone === params[0]);
      } else if (sql.includes('parent_access_code = $1')) {
        filtered = filtered.filter(u => u.parent_access_code === params[0]);
      } else if (sql.includes('email = $1')) {
        filtered = filtered.filter(u => u.email === params[0]);
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM SESSIONS')) {
      let filtered = [...db.sessions];
      if (sql.includes('WHERE id = $1')) {
        filtered = filtered.filter(s => s.id === params[0]);
      } else if (sql.includes('WHERE user_id = $1')) {
        filtered = filtered.filter(s => s.user_id === params[0]);
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM CONCERNS')) {
      let filtered = [...db.concerns];
      if (sql.includes('session_id = $1 AND category = $2')) {
        filtered = filtered.filter(c => c.session_id === params[0] && c.category === params[1]);
      } else if (sql.includes('session_id = $1')) {
        filtered = filtered.filter(c => c.session_id === params[0]);
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM OUTCOMES')) {
      let filtered = [...db.outcomes];
      if (sql.includes('LOWER(trade) = LOWER($1) AND LOWER(location) = LOWER($2)')) {
        filtered = filtered.filter(o => o.trade.toLowerCase() === String(params[0]).toLowerCase() && o.location.toLowerCase() === String(params[1]).toLowerCase());
      } else if (sql.includes('LOWER(trade) = LOWER($1)')) {
        filtered = filtered.filter(o => o.trade.toLowerCase() === String(params[0]).toLowerCase());
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM OUTCOME_CHUNKS')) {
      let filtered = [...db.outcome_chunks];
      if (sql.includes('LOWER(trade) = LOWER($1) AND LOWER(location) = LOWER($2) AND LOWER(topic) = LOWER($3)')) {
        filtered = filtered.filter(c => c.trade.toLowerCase() === String(params[0]).toLowerCase() && c.location.toLowerCase() === String(params[1]).toLowerCase() && c.topic.toLowerCase() === String(params[2]).toLowerCase());
      } else if (sql.includes('LOWER(trade) = LOWER($1) AND LOWER(location) = LOWER($2)')) {
        filtered = filtered.filter(c => c.trade.toLowerCase() === String(params[0]).toLowerCase() && c.location.toLowerCase() === String(params[1]).toLowerCase());
      } else if (sql.includes('LOWER(trade) = LOWER($1) AND LOWER(topic) = LOWER($2)')) {
        filtered = filtered.filter(c => c.trade.toLowerCase() === String(params[0]).toLowerCase() && c.topic.toLowerCase() === String(params[1]).toLowerCase());
      } else if (sql.includes('LOWER(trade) = LOWER($1)')) {
        filtered = filtered.filter(c => c.trade.toLowerCase() === String(params[0]).toLowerCase());
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM ESCALATIONS')) {
      let filtered = [...db.escalations];
      if (sql.includes('WHERE id = $1')) {
        filtered = filtered.filter(e => e.id === params[0]);
      } else if (sql.includes('WHERE session_id = $1')) {
        filtered = filtered.filter(e => e.session_id === params[0]);
      }
      return { rows: filtered as any[], rowCount: filtered.length };
    }

    if (sqlTrimmed.includes('FROM DATASETS')) {
      return { rows: db.datasets as any[], rowCount: db.datasets.length };
    }

    if (sqlTrimmed.includes('FROM COVERAGE_GAPS')) {
      return { rows: db.coverage_gaps as any[], rowCount: db.coverage_gaps.length };
    }
  }

  // 2. DELETE queries
  if (sqlTrimmed.startsWith('DELETE')) {
    if (sqlTrimmed.includes('FROM OUTCOME_CHUNKS')) {
      if (sql.includes('WHERE trade = $1 AND location = $2')) {
        const countBefore = db.outcome_chunks.length;
        db.outcome_chunks = db.outcome_chunks.filter(c => !(c.trade.toLowerCase() === String(params[0]).toLowerCase() && c.location.toLowerCase() === String(params[1]).toLowerCase()));
        saveDb();
        return { rows: [], rowCount: countBefore - db.outcome_chunks.length };
      }
      if (sql.includes('WHERE file_path = $1') || sql.includes('WHERE file_path IS NOT NULL')) {
        const countBefore = db.outcome_chunks.length;
        db.outcome_chunks = db.outcome_chunks.filter(c => c.file_path !== params[0]);
        saveDb();
        return { rows: [], rowCount: countBefore - db.outcome_chunks.length };
      }
      db.outcome_chunks = [];
      saveDb();
      return { rows: [], rowCount: 1 };
    }

    if (sqlTrimmed.includes('FROM OUTCOMES')) {
      if (sql.includes('WHERE trade = $1 AND location = $2')) {
        const countBefore = db.outcomes.length;
        db.outcomes = db.outcomes.filter(o => !(o.trade.toLowerCase() === String(params[0]).toLowerCase() && o.location.toLowerCase() === String(params[1]).toLowerCase()));
        saveDb();
        return { rows: [], rowCount: countBefore - db.outcomes.length };
      }
      db.outcomes = [];
      saveDb();
      return { rows: [], rowCount: 1 };
    }
  }

  // 3. INSERT queries
  if (sqlTrimmed.startsWith('INSERT INTO USERS')) {
    const existingIdx = db.users.findIndex(u => u.id === params[0]);
    const record: UserRecord = {
      id: params[0],
      phone: params[1] || null,
      email: params[2] || null,
      role: params[3] || 'family',
      consent: params[4] ?? true,
      created_at: new Date().toISOString(),
    };
    if (existingIdx >= 0) db.users[existingIdx] = { ...db.users[existingIdx], ...record };
    else db.users.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO SESSIONS')) {
    const existingIdx = db.sessions.findIndex(s => s.id === params[0]);
    const record: SessionRecord = {
      id: params[0],
      user_id: params[1] || null,
      student_profile: typeof params[2] === 'string' ? JSON.parse(params[2]) : params[2] || {},
      family_context: typeof params[3] === 'string' ? JSON.parse(params[3]) : params[3] || {},
      status: params[4] || 'active',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    if (existingIdx >= 0) db.sessions[existingIdx] = { ...db.sessions[existingIdx], ...record };
    else db.sessions.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO CONCERNS')) {
    const record: ConcernRecord = {
      id: params[0],
      session_id: params[1],
      category: params[2],
      status: params[3] || 'raised',
      asked_at: new Date().toISOString(),
      resolved_at: params[4] || null,
      evidence_used: typeof params[5] === 'string' ? JSON.parse(params[5]) : params[5] || {},
    };
    const existingIdx = db.concerns.findIndex(c => c.session_id === record.session_id && c.category === record.category);
    if (existingIdx >= 0) db.concerns[existingIdx] = record;
    else db.concerns.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO OUTCOMES')) {
    const record: OutcomeRecord = {
      id: params[0],
      trade: params[1],
      location: params[2],
      provider: params[3],
      placement_rate: params[4] !== undefined && params[4] !== null ? Number(params[4]) : null,
      avg_earnings: params[5] !== undefined && params[5] !== null ? Number(params[5]) : null,
      nsqf_level: params[6] !== undefined && params[6] !== null ? Number(params[6]) : null,
      duration_months: params[7] !== undefined && params[7] !== null ? Number(params[7]) : null,
      training_cost: params[8] !== undefined && params[8] !== null ? Number(params[8]) : null,
      min_education: params[9],
      job_roles: typeof params[10] === 'string' ? JSON.parse(params[10]) : params[10] || [],
      progression: typeof params[11] === 'string' ? JSON.parse(params[11]) : params[11] || [],
      further_education: params[12],
      source: params[13],
      data_date: params[14],
      dataset_version: params[15],
      created_at: new Date().toISOString(),
    };
    const idx = db.outcomes.findIndex(o => o.id === record.id);
    if (idx >= 0) db.outcomes[idx] = record;
    else db.outcomes.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO OUTCOME_CHUNKS')) {
    let embeddingArr: number[] | undefined = undefined;
    if (params[8]) {
      if (Array.isArray(params[8])) embeddingArr = params[8];
      else if (typeof params[8] === 'string') {
        try {
          embeddingArr = JSON.parse(params[8]);
        } catch {
          // ignore parsing error if custom string
        }
      }
    }

    const record: ChunkRecord = {
      id: params[0],
      outcome_id: params[1],
      topic: params[2],
      text: params[3],
      trade: params[4],
      location: params[5],
      source: params[6],
      data_date: params[7],
      embedding: embeddingArr,
      file_path: params[9],
    };
    const idx = db.outcome_chunks.findIndex(c => c.id === record.id);
    if (idx >= 0) db.outcome_chunks[idx] = record;
    else db.outcome_chunks.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO ESCALATIONS')) {
    const record: EscalationRecord = {
      id: params[0],
      session_id: params[1],
      reason: params[2],
      status: 'open',
      evidence_shown: typeof params[3] === 'string' ? JSON.parse(params[3]) : params[3] || [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    db.escalations.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  if (sqlTrimmed.startsWith('INSERT INTO DATASETS')) {
    const record: DatasetRecord = {
      id: params[0],
      version: params[1],
      filename: params[2],
      total_rows: params[3] || 0,
      valid_rows: 0,
      rejected_rows: 0,
      uploaded_at: new Date().toISOString(),
    };
    const idx = db.datasets.findIndex(d => d.version === record.version);
    if (idx >= 0) db.datasets[idx] = record;
    else db.datasets.push(record);
    saveDb();
    return { rows: [record as any], rowCount: 1 };
  }

  // 4. UPDATE queries
  if (sqlTrimmed.startsWith('UPDATE CONCERNS')) {
    const [status, resolvedAt, evidenceUsed, sessionId, category] = params;
    const existing = db.concerns.find(c => c.session_id === sessionId && c.category === category);
    if (existing) {
      existing.status = status;
      existing.resolved_at = resolvedAt;
      existing.evidence_used = typeof evidenceUsed === 'string' ? JSON.parse(evidenceUsed) : evidenceUsed;
      saveDb();
      return { rows: [existing as any], rowCount: 1 };
    }
  }

  if (sqlTrimmed.startsWith('UPDATE SESSIONS')) {
    const [status, sessionId] = params;
    const existing = db.sessions.find(s => s.id === sessionId);
    if (existing) {
      existing.status = status;
      existing.updated_at = new Date().toISOString();
      saveDb();
      return { rows: [existing as any], rowCount: 1 };
    }
  }

  if (sqlTrimmed.startsWith('UPDATE DATASETS')) {
    const [validRows, rejectedRows, version] = params;
    const existing = db.datasets.find(d => d.version === version);
    if (existing) {
      existing.valid_rows = validRows;
      existing.rejected_rows = rejectedRows;
      saveDb();
      return { rows: [existing as any], rowCount: 1 };
    }
  }

  return { rows: [], rowCount: 0 };
}

/**
 * Cosine similarity vector search over outcome_chunks
 */
export async function vectorSearchOutcomeChunks(
  queryEmbedding: number[],
  trade?: string,
  topK: number = 6
): Promise<Array<{
  id: string;
  outcome_id: string;
  topic: string;
  text: string;
  trade: string;
  location: string;
  source: string;
  data_date: string;
  distance: number;
}>> {
  const db = loadDb();
  let chunks = db.outcome_chunks.filter(c => c.embedding && c.embedding.length > 0);

  if (trade) {
    const tradeLower = trade.toLowerCase();
    chunks = chunks.filter(c => c.trade.toLowerCase() === tradeLower);
  }

  // Compute cosine similarity distance
  const results = chunks.map(chunk => {
    const emb = chunk.embedding!;
    let dot = 0;
    let normA = 0;
    let normB = 0;
    const len = Math.min(queryEmbedding.length, emb.length);

    for (let i = 0; i < len; i++) {
      dot += queryEmbedding[i] * emb[i];
      normA += queryEmbedding[i] * queryEmbedding[i];
      normB += emb[i] * emb[i];
    }

    const similarity = normA > 0 && normB > 0 ? dot / (Math.sqrt(normA) * Math.sqrt(normB)) : 0;
    const distance = 1 - similarity;

    return {
      id: chunk.id,
      outcome_id: chunk.outcome_id,
      topic: chunk.topic,
      text: chunk.text,
      trade: chunk.trade,
      location: chunk.location,
      source: chunk.source,
      data_date: chunk.data_date,
      distance,
    };
  });

  results.sort((a, b) => a.distance - b.distance);
  return results.slice(0, topK);
}

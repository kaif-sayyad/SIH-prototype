import { query } from '../db';
import { retrieveEvidence } from '../rag/retrieval';
import { runRAGPipeline } from '../rag/verification';
import { generateJSON } from '../gemini';

export interface StudentProfile {
  sName?: string;
  sEdu?: string;
  sLoc?: string;
  sInterest?: string;
  sMonths?: string | number;
  sGoal?: string;
}

export interface FamilyContext {
  fIncome?: string;
  fStable?: string;
  fEdu?: string;
  fLocReq?: string;
  fConcerns?: string[];
}

export async function classifyConcern(text: string): Promise<{ categories: string[]; confidence: number }> {
  const categories = ['income', 'job', 'social', 'growth', 'safety', 'edu', 'cost', 'localjobs'];

  const prompt = `Classify the parent/student concern text into one or more categories: ${categories.join(', ')}.
Text: "${text}"
Return JSON: {"categories": ["category_name"], "confidence": 0.0 to 1.0}`;

  const res = await generateJSON<{ categories: string[]; confidence: number }>(prompt, text);
  if (res && Array.isArray(res.categories)) {
    return {
      categories: res.categories.filter((c) => categories.includes(c)),
      confidence: res.confidence || 0.85,
    };
  }

  // Keyword fallback
  const lower = text.toLowerCase();
  const matched: string[] = [];
  if (/salary|earn|income|money|पगार|कमाई/.test(lower)) matched.push('income');
  if (/job|placement|employ|नोकरी/.test(lower)) matched.push('job');
  if (/respect|society|relative|status|समाज/.test(lower)) matched.push('social');
  if (/growth|promot|future|प्रगती/.test(lower)) matched.push('growth');
  if (/safe|danger|accident|सुरक्षा/.test(lower)) matched.push('safety');
  if (/degree|diploma|study|higher|education|शिक्षण/.test(lower)) matched.push('edu');
  if (/fee|cost|afford|खर्च/.test(lower)) matched.push('cost');
  if (/near|local|nearby|जवळ/.test(lower)) matched.push('localjobs');

  return {
    categories: matched.length > 0 ? matched : ['job'],
    confidence: matched.length > 0 ? 0.9 : 0.5,
  };
}

export async function toolRetrieveEvidence(
  trade: string,
  location: string,
  topic: string,
  question: string
) {
  const retrieved = await retrieveEvidence(question, trade, location);
  return await runRAGPipeline(question, retrieved.chunks, 'en', undefined, trade, location);
}

export async function recommendTrades(profile: StudentProfile) {
  const { rows } = await query(`
    SELECT trade, location, placement_rate, avg_earnings, nsqf_level, duration_months, training_cost, min_education, source, data_date
    FROM outcomes
  `);

  if (!rows || rows.length === 0) {
    return [
      { trade: 'Electrician', score: 90, placement: 80, avg_earnings: 20000, nsqf: 4, duration: 12, cost: 9000, verified: true },
      { trade: 'Solar Technician', score: 85, placement: 82, avg_earnings: 19500, nsqf: 4, duration: 6, cost: 12000, verified: true },
      { trade: 'CNC Operator', score: 80, placement: 83, avg_earnings: 22500, nsqf: 4, duration: 9, cost: 18000, verified: true }
    ];
  }

  // Rank trades based on profile
  const tradeScoresMap = new Map<string, { trade: string; placement: number; avg_earnings: number; nsqf: number; duration: number; cost: number; verified: boolean; score: number }>();

  for (const r of rows) {
    const isLocMatch = profile.sLoc && r.location.toLowerCase() === profile.sLoc.toLowerCase();
    const isDurMatch = profile.sMonths && r.duration_months <= Number(profile.sMonths);

    let score = (r.placement_rate || 50) * 0.4 + (r.avg_earnings || 10000) / 500;
    if (isLocMatch) score += 20;
    if (isDurMatch) score += 10;

    const existing = tradeScoresMap.get(r.trade);
    if (!existing || score > existing.score) {
      tradeScoresMap.set(r.trade, {
        trade: r.trade,
        placement: Number(r.placement_rate || 0),
        avg_earnings: Number(r.avg_earnings || 0),
        nsqf: Number(r.nsqf_level || 4),
        duration: Number(r.duration_months || 12),
        cost: Number(r.training_cost || 0),
        verified: Boolean(isLocMatch),
        score,
      });
    }
  }

  const sorted = Array.from(tradeScoresMap.values()).sort((a, b) => b.score - a.score);
  return sorted.slice(0, 3);
}

export async function comparePathways(trade: string, location: string) {
  const { rows } = await query(
    `SELECT * FROM outcomes WHERE LOWER(trade) = LOWER($1) AND LOWER(location) = LOWER($2)`,
    [trade, location]
  );

  const row = rows[0];

  return {
    trade,
    location,
    vocational: {
      entry: row ? `${row.min_education || '10th pass'}` : '10th pass',
      duration: row ? `${row.duration_months} months` : '12 months',
      initialRole: row ? (Array.isArray(row.job_roles) ? row.job_roles[0] : 'Junior Technician') : 'Technician',
      furtherEdu: row ? row.further_education : 'Polytechnic Diploma Lateral Entry',
      placement: row ? `${row.placement_rate}% placement` : 'Data not available',
    },
    academic: {
      entry: '12th pass / Entrance Exam',
      duration: '3 to 4 years',
      initialRole: 'Graduate Trainee',
      furtherEdu: 'Post-Graduation / Master Degree',
      placement: 'Data not available',
    },
  };
}

export async function getPathway(trade: string) {
  const { rows } = await query(`SELECT * FROM outcomes WHERE LOWER(trade) = LOWER($1) LIMIT 1`, [trade]);
  const row = rows[0];

  return {
    trade,
    nsqf_level: row ? row.nsqf_level : 4,
    steps: row && Array.isArray(row.progression)
      ? row.progression
      : ['Training (ITI)', 'Assistant', trade, 'Senior Technician', 'Supervisor'],
    further_education: row
      ? row.further_education
      : 'Diploma in Engineering (Lateral Entry), NSQF Level 5',
  };
}

export async function updateConcernStatus(
  sessionId: string,
  category: string,
  status: 'raised' | 'answered' | 'resolved' | 'unresolved' | 'escalated',
  evidenceUsed: any = {}
) {
  // Ensure session exists in DB
  await query(
    `INSERT INTO sessions (id, status, created_at, updated_at)
     VALUES ($1, 'active', NOW(), NOW())
     ON CONFLICT (id) DO NOTHING`,
    [sessionId]
  );

  const existing = await query(
    `SELECT id FROM concerns WHERE session_id = $1 AND category = $2`,
    [sessionId, category]
  );

  if (existing.rows.length > 0) {
    await query(
      `UPDATE concerns SET status = $1, resolved_at = $2, evidence_used = $3 WHERE session_id = $4 AND category = $5`,
      [status, status === 'resolved' ? new Date().toISOString() : null, JSON.stringify(evidenceUsed), sessionId, category]
    );
  } else {
    await query(
      `INSERT INTO concerns (id, session_id, category, status, asked_at, resolved_at, evidence_used)
       VALUES ($1, $2, $3, $4, NOW(), $5, $6)`,
      [
        `c_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        sessionId,
        category,
        status,
        status === 'resolved' ? new Date().toISOString() : null,
        JSON.stringify(evidenceUsed),
      ]
    );
  }

  return { success: true, sessionId, category, status };
}

export async function createEscalation(sessionId: string, reason: string, evidenceShown: any[] = []) {
  const escId = `esc_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
  await query(
    `INSERT INTO escalations (id, session_id, reason, status, evidence_shown, created_at, updated_at)
     VALUES ($1, $2, $3, 'open', $4, NOW(), NOW())`,
    [escId, sessionId, reason, JSON.stringify(evidenceShown)]
  );

  await query(`UPDATE sessions SET status = 'escalated' WHERE id = $1`, [sessionId]);
  return { success: true, escalationId: escId };
}

export async function generateFamilySummary(sessionId: string) {
  const sessRes = await query(`SELECT * FROM sessions WHERE id = $1`, [sessionId]);
  if (sessRes.rows.length === 0) {
    throw new Error(`Session ${sessionId} not found`);
  }

  const sess = sessRes.rows[0];
  const concernsRes = await query(`SELECT * FROM concerns WHERE session_id = $1`, [sessionId]);

  const profile: StudentProfile = sess.student_profile || {};
  const concerns = concernsRes.rows;

  const raised = concerns.map((c) => c.category);
  const resolved = concerns.filter((c) => c.status === 'resolved').map((c) => c.category);
  const unresolved = concerns.filter((c) => c.status === 'unresolved' || c.status === 'escalated').map((c) => c.category);

  return {
    sessionId,
    date: new Date().toISOString().split('T')[0],
    student: profile.sName || 'Student',
    location: profile.sLoc || 'Nagpur',
    interest: profile.sInterest || 'electrical',
    goal: profile.sGoal || 'Steady employment',
    concernsRaised: raised,
    concernsResolved: resolved,
    concernsUnresolved: unresolved,
    nextStep: unresolved.length > 0 || sess.status === 'escalated'
      ? 'Human counsellor session recommended to resolve remaining family concerns.'
      : 'Family is aligned to discuss selected vocational pathway at home.',
  };
}

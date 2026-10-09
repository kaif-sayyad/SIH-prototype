import fs from 'fs';
import path from 'path';
import Papa from 'papaparse';
import { query, getDb } from '../db';
import { generateEmbedding } from '../gemini';

export interface RawOutcomeRow {
  trade?: string;
  course?: string;
  location?: string;
  city?: string;
  district?: string;
  provider?: string;
  institute?: string;
  placement_rate?: string | number;
  placement?: string | number;
  placement_pct?: string | number;
  avg_earnings?: string | number;
  average_salary?: string | number;
  salary?: string | number;
  earnings?: string | number;
  earnings_min?: string | number;
  earnings_max?: string | number;
  nsqf_level?: string | number;
  nsqf?: string | number;
  duration_months?: string | number;
  duration?: string | number;
  training_cost?: string | number;
  cost?: string | number;
  min_education?: string;
  entry_qualification?: string;
  job_roles?: string | string[];
  progression?: string | string[];
  further_education?: string;
  source?: string;
  data_date?: string;
  [key: string]: any;
}

export interface IngestResult {
  datasetVersion: string;
  totalRows: number;
  validRows: number;
  rejectedRows: Array<{ row: number; data: any; reason: string }>;
  chunksCreated: number;
  guidesProcessed: number;
}

/**
 * Standardize input fields using alias mapping table
 */
export function normalizeRow(r: RawOutcomeRow): {
  trade: string;
  location: string;
  provider: string;
  placement: number | null;
  earnings: number | null;
  nsqf: number | null;
  duration: number | null;
  cost: number | null;
  minEdu: string;
  jobRoles: string[];
  progression: string[];
  furtherEdu: string;
  source: string;
  dataDate: string;
  raw: any;
} {
  const trade = (r.trade || r.course || '').toString().trim();
  const location = (r.location || r.city || r.district || '').toString().trim();
  const provider = (r.provider || r.institute || 'Approved ITI / Skills Centre').toString().trim();

  let placement: number | null = null;
  const rawVal = r.placement_rate ?? r.placement ?? r.placement_pct;
  if (rawVal !== undefined && rawVal !== null && rawVal !== '') {
    const p = parseFloat(String(rawVal).replace('%', ''));
    if (!isNaN(p)) placement = p;
  }

  let earnings: number | null = null;
  const rawEarn = r.avg_earnings ?? r.average_salary ?? r.salary ?? r.earnings;
  if (rawEarn !== undefined && rawEarn !== null && rawEarn !== '') {
    const e = parseFloat(String(rawEarn).replace(/[^0-9.]/g, ''));
    if (!isNaN(e)) earnings = e;
  }

  let nsqf: number | null = null;
  const rawNsqf = r.nsqf_level ?? r.nsqf;
  if (rawNsqf !== undefined && rawNsqf !== null && rawNsqf !== '') {
    const n = parseInt(String(rawNsqf), 10);
    if (!isNaN(n)) nsqf = n;
  }

  let duration: number | null = null;
  const rawDur = r.duration_months ?? r.duration;
  if (rawDur !== undefined && rawDur !== null && rawDur !== '') {
    const d = parseInt(String(rawDur), 10);
    if (!isNaN(d)) duration = d;
  }

  let cost: number | null = null;
  const rawCost = r.training_cost ?? r.cost;
  if (rawCost !== undefined && rawCost !== null && rawCost !== '') {
    const c = parseFloat(String(rawCost).replace(/[^0-9.]/g, ''));
    if (!isNaN(c)) cost = c;
  }

  const minEdu = (r.min_education || r.entry_qualification || '10th pass').toString().trim();
  const furtherEdu = (r.further_education || 'Polytechnic Diploma (lateral entry), NSQF Level 5').toString().trim();
  const source = (r.source || 'MSDE Vocational Survey 2026').toString().trim();
  const dataDate = (r.data_date || '2026-01').toString().trim();

  let jobRoles: string[] = [trade];
  if (r.job_roles) {
    if (Array.isArray(r.job_roles)) jobRoles = r.job_roles;
    else jobRoles = String(r.job_roles).split(',').map(s => s.trim()).filter(Boolean);
  }

  let progression: string[] = ['Training', trade, 'Senior Specialist', 'Supervisor'];
  if (r.progression) {
    if (Array.isArray(r.progression)) progression = r.progression;
    else progression = String(r.progression).split(/->|,/).map(s => s.trim()).filter(Boolean);
  }

  return {
    trade,
    location,
    provider,
    placement,
    earnings,
    nsqf,
    duration,
    cost,
    minEdu,
    jobRoles,
    progression,
    furtherEdu,
    source,
    dataDate,
    raw: r,
  };
}

export async function ingestDataset(
  version: string,
  filename: string,
  rows: RawOutcomeRow[]
): Promise<IngestResult> {
  const rejectedRows: Array<{ row: number; data: any; reason: string }> = [];
  let validCount = 0;
  let chunksCreated = 0;

  const datasetId = `dataset_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  await query(
    `INSERT INTO datasets (id, version, filename, total_rows, valid_rows, rejected_rows, uploaded_at)
     VALUES ($1, $2, $3, $4, 0, 0, NOW())`,
    [datasetId, version, filename, rows.length]
  );

  for (let idx = 0; idx < rows.length; idx++) {
    const rawR = rows[idx];
    const rowNum = idx + 1;
    const norm = normalizeRow(rawR);

    // Validation checks
    if (!norm.trade || !norm.location) {
      rejectedRows.push({ row: rowNum, data: rawR, reason: 'Missing required trade or location' });
      continue;
    }

    if (norm.placement !== null && (norm.placement < 0 || norm.placement > 100)) {
      rejectedRows.push({ row: rowNum, data: rawR, reason: `Invalid placement rate (must be 0-100): ${norm.placement}` });
      continue;
    }

    if (norm.earnings !== null && norm.earnings < 0) {
      rejectedRows.push({ row: rowNum, data: rawR, reason: `Invalid avg_earnings: ${norm.earnings}` });
      continue;
    }

    if (norm.nsqf !== null && (norm.nsqf < 1 || norm.nsqf > 10)) {
      rejectedRows.push({ row: rowNum, data: rawR, reason: `Invalid NSQF level (1-10): ${norm.nsqf}` });
      continue;
    }

    const outcomeId = `out_${norm.trade.toLowerCase().replace(/[^a-z0-9]/g, '')}_${norm.location.toLowerCase().replace(/[^a-z0-9]/g, '')}_${idx}`;

    await query(`DELETE FROM outcome_chunks WHERE trade = $1 AND location = $2`, [norm.trade, norm.location]);
    await query(`DELETE FROM outcomes WHERE trade = $1 AND location = $2`, [norm.trade, norm.location]);

    await query(
      `INSERT INTO outcomes (
        id, trade, location, provider, placement_rate, avg_earnings, nsqf_level,
        duration_months, training_cost, min_education, job_roles, progression,
        further_education, source, data_date, dataset_version
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
      [
        outcomeId, norm.trade, norm.location, norm.provider, norm.placement, norm.earnings, norm.nsqf,
        norm.duration, norm.cost, norm.minEdu, JSON.stringify(norm.jobRoles), JSON.stringify(norm.progression),
        norm.furtherEdu, norm.source, norm.dataDate, version
      ]
    );

    validCount++;

    // Generate topic fact chunks
    const topicFacts: Array<{ topic: string; text: string }> = [];

    if (norm.placement !== null) {
      topicFacts.push({
        topic: 'placement',
        text: `${norm.trade} in ${norm.location}: ${norm.placement}% of trainees were placed in jobs (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.earnings !== null) {
      topicFacts.push({
        topic: 'earnings',
        text: `${norm.trade} in ${norm.location}: average earnings ₹${norm.earnings.toLocaleString('en-IN')} per month for entry-level positions (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.progression.length > 0) {
      topicFacts.push({
        topic: 'progression',
        text: `Career progression for ${norm.trade}: typical path is ${norm.progression.join(' -> ')} (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.furtherEdu) {
      topicFacts.push({
        topic: 'education',
        text: `Further education options after ${norm.trade}: ${norm.furtherEdu} (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.cost !== null || norm.duration !== null) {
      const costStr = norm.cost !== null ? `estimated training fee ₹${norm.cost.toLocaleString('en-IN')}` : '';
      const durStr = norm.duration !== null ? `duration of ${norm.duration} months` : '';
      const combined = [durStr, costStr].filter(Boolean).join(' and ');
      topicFacts.push({
        topic: 'cost',
        text: `${norm.trade} course details in ${norm.location}: ${combined} (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.provider) {
      topicFacts.push({
        topic: 'providers',
        text: `Training providers for ${norm.trade} in ${norm.location}: ${norm.provider} (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    if (norm.nsqf !== null) {
      topicFacts.push({
        topic: 'nsqf',
        text: `${norm.trade} is certified at National Skills Qualifications Framework (NSQF) Level ${norm.nsqf} (source: ${norm.source}, date: ${norm.dataDate}).`,
      });
    }

    for (let cIdx = 0; cIdx < topicFacts.length; cIdx++) {
      const f = topicFacts[cIdx];
      const chunkId = `chk_${outcomeId}_${f.topic}_${cIdx}`;
      const embedding = await generateEmbedding(f.text);

      await query(
        `INSERT INTO outcome_chunks (id, outcome_id, topic, text, trade, location, source, data_date, embedding)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [chunkId, outcomeId, f.topic, f.text, norm.trade, norm.location, norm.source, norm.dataDate, embedding]
      );
      chunksCreated++;
    }
  }

  await query(
    `UPDATE datasets SET valid_rows = $1, rejected_rows = $2 WHERE version = $3`,
    [validCount, rejectedRows.length, version]
  );

  return {
    datasetVersion: version,
    totalRows: rows.length,
    validRows: validCount,
    rejectedRows,
    chunksCreated,
    guidesProcessed: 0,
  };
}

/**
 * Reload all knowledge files from knowledge/ directory
 */
export async function loadKnowledgeFiles(): Promise<{ outcomesResult?: IngestResult; guideChunks: number }> {
  await getDb();

  const knowledgeDir = path.join(process.cwd(), 'knowledge');
  let guideChunksCount = 0;

  if (!fs.existsSync(knowledgeDir)) {
    fs.mkdirSync(knowledgeDir, { recursive: true });
  }

  // 1. Ingest outcomes.csv
  const outcomesPath = path.join(knowledgeDir, 'outcomes.csv');
  let outcomesResult: IngestResult | undefined;

  if (fs.existsSync(outcomesPath)) {
    const csvContent = fs.readFileSync(outcomesPath, 'utf8');
    const parseRes = Papa.parse<RawOutcomeRow>(csvContent, { header: true, skipEmptyLines: true });
    outcomesResult = await ingestDataset('knowledge_v1', 'outcomes.csv', parseRes.data);
  }

  // 2. Ingest guides/*.md and guides/*.txt
  const guidesDir = path.join(knowledgeDir, 'guides');
  if (fs.existsSync(guidesDir)) {
    const guideFiles = fs.readdirSync(guidesDir).filter(f => f.endsWith('.md') || f.endsWith('.txt'));

    for (const file of guideFiles) {
      const filePath = path.join(guidesDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const filename = path.basename(file);

      // Split by heading (## or #) or blank lines
      const sections = content.split(/(?=\n##?\s+)/g);

      for (let sIdx = 0; sIdx < sections.length; sIdx++) {
        const secText = sections[sIdx].trim();
        if (!secText) continue;

        const headingMatch = secText.match(/^##?\s+(.*)/m);
        const heading = headingMatch ? headingMatch[1].trim() : 'General Guide';

        let topic = 'general';
        const hLower = heading.toLowerCase();
        if (hLower.includes('income') || hLower.includes('financial')) topic = 'earnings';
        else if (hLower.includes('perception') || hLower.includes('respect')) topic = 'social';
        else if (hLower.includes('safety')) topic = 'safety';
        else if (hLower.includes('growth') || hLower.includes('lateral')) topic = 'progression';

        const chunkId = `chk_guide_${filename}_${sIdx}`;
        const embedding = await generateEmbedding(secText);

        await query(
          `INSERT INTO outcome_chunks (id, outcome_id, topic, text, trade, location, source, data_date, embedding, file_path)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            chunkId,
            `guide_${filename}`,
            topic,
            secText,
            'All Vocational Trades',
            'All Districts',
            filename,
            '2026-01',
            embedding,
            filePath,
          ]
        );
        guideChunksCount++;
      }
    }
  }

  return { outcomesResult, guideChunks: guideChunksCount };
}

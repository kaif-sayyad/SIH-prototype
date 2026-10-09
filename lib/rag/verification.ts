import { GroundedResponse, generateGroundedAnswer, UNAVAILABLE_MESSAGE } from './grounded-gen';
import { RetrievedChunk } from './retrieval';
import { query } from '../db';

/**
 * Extract numbers, percentages, and monetary amounts (e.g. 78%, 18,000, ₹20000, 12, 4) from text
 */
export function extractNumbersFromText(text: string): string[] {
  // Regex matches numbers, percentages, rupee amounts
  const matches = text.match(/(?:₹\s*)?\d+(?:,\d+)*(?:\.\d+)?%?/g);
  if (!matches) return [];

  return matches.map((m) => {
    // Normalize string by removing currency symbols, commas, and percentage signs for numeric comparison
    return m.replace(/[₹,\s]/g, '').trim();
  }).filter((m) => m.length > 0 && m !== '0');
}

/**
 * Verify that all numbers in the generated answer exist in the context of the cited chunks
 */
export function verifyAnswerGrounding(
  answer: string,
  citedChunks: RetrievedChunk[]
): { verified: boolean; ungroundedNumbers: string[] } {
  if (!citedChunks || citedChunks.length === 0) {
    return { verified: false, ungroundedNumbers: ['No chunks cited'] };
  }

  const answerNumbers = extractNumbersFromText(answer);
  if (answerNumbers.length === 0) {
    return { verified: true, ungroundedNumbers: [] };
  }

  // Combine text of all cited chunks
  const chunkTextCombined = citedChunks.map((c) => c.text).join(' ');
  const chunkNumbers = new Set(extractNumbersFromText(chunkTextCombined));

  const ungroundedNumbers: string[] = [];

  for (const num of answerNumbers) {
    // Extract numeric raw value
    const cleanNum = num.replace('%', '');
    let found = false;

    // Check exact match or raw number match in chunkNumbers or chunk text
    for (const chunkNum of Array.from(chunkNumbers)) {
      const cleanChunkNum = chunkNum.replace('%', '');
      if (cleanNum === cleanChunkNum || num === chunkNum) {
        found = true;
        break;
      }
    }

    if (!found && !chunkTextCombined.includes(cleanNum)) {
      ungroundedNumbers.push(num);
    }
  }

  return {
    verified: ungroundedNumbers.length === 0,
    ungroundedNumbers,
  };
}

/**
 * Audit log retrieval results without storing raw user message text
 */
export async function logRAGAudit(
  sessionId: string,
  topic: string | null,
  chunkIds: string[],
  grounded: boolean
) {
  try {
    await query(
      `INSERT INTO coverage_gaps (id, trade, location, question, created_at)
       VALUES ($1, $2, $3, $4, NOW())`,
      [
        `audit_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        topic || 'general',
        grounded ? 'grounded_ok' : 'data_unavailable',
        `RAG query audit: chunks=[${chunkIds.join(',')}] grounded=${grounded}`,
      ]
    );
  } catch (err) {
    // Non-blocking log
  }
}

/**
 * Run end-to-end RAG pipeline with verification guard and retry logic
 */
export async function runRAGPipeline(
  question: string,
  retrievedChunks: RetrievedChunk[],
  language: 'en' | 'mr' = 'en',
  sessionId?: string,
  trade?: string,
  location?: string
): Promise<GroundedResponse & { escalated: boolean }> {
  // 1. Check if empty chunks
  if (!retrievedChunks || retrievedChunks.length === 0) {
    if (sessionId) {
      await logRAGAudit(sessionId, trade || null, [], false);
      // Log coverage gap
      await query(
        `INSERT INTO coverage_gaps (id, trade, location, question, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [`gap_${Date.now()}`, trade || 'Unknown', location || 'Unknown', question]
      );
    }
    return {
      answer: `${UNAVAILABLE_MESSAGE}\nA human counsellor has been notified to assist your family.`,
      citations: [],
      concern: 'general',
      grounded: false,
      escalated: true,
    };
  }

  // 2. Generate grounded answer (First Attempt)
  let genRes = await generateGroundedAnswer(question, retrievedChunks, language, false);

  // Filter cited chunks
  let cited = retrievedChunks.filter((c) => genRes.citations.includes(c.id));
  if (cited.length === 0) cited = retrievedChunks;

  // 3. Post-generation Verification Guard
  const verify1 = verifyAnswerGrounding(genRes.answer, cited);

  if (!verify1.verified) {
    console.warn('Verification guard failed on 1st attempt. Hallucinated numbers:', verify1.ungroundedNumbers);
    // Retry once with stricter prompt
    genRes = await generateGroundedAnswer(question, retrievedChunks, language, true);
    let cited2 = retrievedChunks.filter((c) => genRes.citations.includes(c.id));
    if (cited2.length === 0) cited2 = retrievedChunks;

    const verify2 = verifyAnswerGrounding(genRes.answer, cited2);
    if (!verify2.verified) {
      console.warn('Verification guard failed on 2nd attempt. Replacing with unavailable message.');
      if (sessionId) {
        await logRAGAudit(sessionId, trade || null, [], false);
      }
      return {
        answer: `${UNAVAILABLE_MESSAGE}\nA human counsellor will review this query.`,
        citations: [],
        concern: genRes.concern,
        grounded: false,
        escalated: true,
      };
    }
  }

  if (sessionId) {
    await logRAGAudit(sessionId, trade || null, genRes.citations, true);
  }

  return {
    ...genRes,
    escalated: false,
  };
}

import { RetrievedChunk } from './retrieval';
import { generateJSON } from '../gemini';

export interface GroundedResponse {
  answer: string;
  citations: string[];
  concern: string;
  grounded: boolean;
}

export const UNAVAILABLE_MESSAGE = "Verified data for this specific trade/location is currently unavailable.";

export async function generateGroundedAnswer(
  question: string,
  chunks: RetrievedChunk[],
  language: 'en' | 'mr' = 'en',
  stricter: boolean = false
): Promise<GroundedResponse> {
  if (!chunks || chunks.length === 0) {
    return {
      answer: `${UNAVAILABLE_MESSAGE}\nA human counsellor can assist you.`,
      citations: [],
      concern: 'general',
      grounded: false,
    };
  }

  const chunksFormatted = chunks
    .map((c) => `[Chunk ID: ${c.id}] (Trade: ${c.trade}, Location: ${c.location}, Topic: ${c.topic}, Source: ${c.source}, Date: ${c.data_date}):\n${c.text}`)
    .join('\n\n');

  const systemPrompt = `You are a career counsellor assistant for the SkillPath Family Counselling Portal.
Answer the family's question using ONLY the provided evidence chunks.

STRICT GROUNDING RULES:
1. Every single number, percentage, salary, duration, or figure MUST appear in the provided chunks.
2. DO NOT invent, extrapolate, or use outside knowledge.
3. Cite the Chunk IDs used in the "citations" array.
4. Always state the source dataset and date clearly in your response.
5. If user asks in Marathi (lang: mr), translate the answer into natural, polite Marathi while keeping all figures exact.
6. Return valid JSON matching schema:
   {
     "answer": "string",
     "citations": ["chunk_id"],
     "concern": "income|job|social|growth|safety|edu|cost|localjobs",
     "grounded": true
   }
${stricter ? 'ATTENTION: CRITICAL RETRY - DO NOT INCLUDE ANY NUMBER OR STATISTIC THAT IS NOT DIRECTLY WRITTEN IN THE CHUNKS.' : ''}`;

  const userPrompt = `Language: ${language === 'mr' ? 'Marathi (mr)' : 'English (en)'}
Question: ${question}

Evidence Chunks:
${chunksFormatted}`;

  const res = await generateJSON<GroundedResponse>(systemPrompt, userPrompt);

  if (res && res.answer && Array.isArray(res.citations)) {
    return {
      answer: res.answer,
      citations: res.citations,
      concern: res.concern || 'general',
      grounded: res.grounded !== false,
    };
  }

  // Fallback generation if LLM is offline or non-JSON
  const primary = chunks[0];
  const sourceText = `\n(Source: ${primary.source}, Date: ${primary.data_date})`;
  return {
    answer: primary.text + sourceText,
    citations: [primary.id],
    concern: primary.topic,
    grounded: true,
  };
}

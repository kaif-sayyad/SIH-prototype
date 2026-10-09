import { GoogleGenAI } from '@google/genai';
import { getConfig, hasValidGeminiKey } from './config';

export function getGeminiClient(): GoogleGenAI | null {
  if (!hasValidGeminiKey()) return null;
  const cfg = getConfig();
  return new GoogleGenAI({ apiKey: cfg.GEMINI_API_KEY });
}

export function getGeminiModelName(): string {
  return getConfig().GEMINI_MODEL || 'gemini-2.5-flash';
}

export function getGeminiEmbeddingModelName(): string {
  return getConfig().GEMINI_EMBEDDING_MODEL || 'gemini-embedding-001';
}

/**
 * Generate embedding vector (768 dimensions) for a text passage
 */
export async function generateEmbedding(text: string): Promise<number[]> {
  const client = getGeminiClient();
  if (client) {
    try {
      const model = getGeminiEmbeddingModelName();
      const res = await client.models.embedContent({
        model,
        contents: text,
      });
      const resAny = res as any;
      if (resAny.embedding?.values) {
        return resAny.embedding.values;
      }
      if (resAny.embeddings?.[0]?.values) {
        return resAny.embeddings[0].values;
      }
    } catch (err) {
      console.warn('Gemini API embedContent failed, falling back to deterministic vector:', (err as Error).message);
    }
  }

  // Fallback 768-dim deterministic vector based on string hash for offline testing
  const vector = new Array(768).fill(0);
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = (hash << 5) - hash + text.charCodeAt(i);
    hash |= 0;
  }
  for (let i = 0; i < 768; i++) {
    vector[i] = Math.sin((hash + i) * 0.1);
  }
  return vector;
}

/**
 * Generate structured content using Gemini
 */
export async function generateJSON<T = any>(
  systemInstruction: string,
  userPrompt: string
): Promise<T | null> {
  const client = getGeminiClient();
  if (client) {
    try {
      const model = getGeminiModelName();
      const res = await client.models.generateContent({
        model,
        contents: `${systemInstruction}\n\nUser request: ${userPrompt}`,
        config: {
          responseMimeType: 'application/json',
        },
      });
      if (res.text) {
        return JSON.parse(res.text) as T;
      }
    } catch (err) {
      console.warn('Gemini generateJSON failed:', (err as Error).message);
    }
  }
  return null;
}

/**
 * Test AI Connection for Admin Panel
 */
export async function testGeminiConnection(): Promise<{ success: boolean; message: string }> {
  if (!hasValidGeminiKey()) {
    return {
      success: false,
      message: 'AI key not set or placeholder key present in config.json',
    };
  }

  try {
    const client = getGeminiClient();
    if (!client) throw new Error('Could not initialize Gemini client');

    const model = getGeminiModelName();
    const res = await client.models.generateContent({
      model,
      contents: 'Respond with OK if connected.',
    });

    if (res.text) {
      return {
        success: true,
        message: `Successfully connected to Gemini API (${model}). Response: ${res.text.trim()}`,
      };
    }
    return { success: false, message: 'Gemini API returned empty response' };
  } catch (err) {
    return {
      success: false,
      message: `Gemini API connection error: ${(err as Error).message}`,
    };
  }
}

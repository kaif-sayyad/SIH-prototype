import fs from 'fs';
import path from 'path';

export interface AppConfig {
  GEMINI_API_KEY: string;
  GEMINI_MODEL: string;
  GEMINI_EMBEDDING_MODEL: string;
  ADMIN_EMAIL: string;
  ADMIN_PASSWORD: string;
  SESSION_SECRET: string;
  PORT: number;
}

const DEFAULT_CONFIG: AppConfig = {
  GEMINI_API_KEY: 'PASTE_YOUR_GEMINI_API_KEY_HERE',
  GEMINI_MODEL: 'gemini-2.5-flash',
  GEMINI_EMBEDDING_MODEL: 'gemini-embedding-001',
  ADMIN_EMAIL: 'admin@example.com',
  ADMIN_PASSWORD: 'CHANGE_ME',
  SESSION_SECRET: 'CHANGE_ME_TO_A_LONG_RANDOM_STRING',
  PORT: 3000,
};

let cachedConfig: AppConfig | null = null;

export function getConfig(): AppConfig {
  if (cachedConfig) return cachedConfig;

  const configPath = path.join(process.cwd(), 'config.json');
  if (fs.existsSync(configPath)) {
    try {
      const raw = fs.readFileSync(configPath, 'utf8');
      const parsed = JSON.parse(raw);
      cachedConfig = {
        ...DEFAULT_CONFIG,
        ...parsed,
      };
      return cachedConfig!;
    } catch (err) {
      console.warn('Failed to parse config.json, using defaults:', (err as Error).message);
    }
  }

  // Fallback to process.env if available
  cachedConfig = {
    GEMINI_API_KEY: process.env.GEMINI_API_KEY || DEFAULT_CONFIG.GEMINI_API_KEY,
    GEMINI_MODEL: process.env.GEMINI_MODEL || DEFAULT_CONFIG.GEMINI_MODEL,
    GEMINI_EMBEDDING_MODEL: process.env.GEMINI_EMBEDDING_MODEL || DEFAULT_CONFIG.GEMINI_EMBEDDING_MODEL,
    ADMIN_EMAIL: process.env.ADMIN_EMAIL || DEFAULT_CONFIG.ADMIN_EMAIL,
    ADMIN_PASSWORD: process.env.ADMIN_PASSWORD || DEFAULT_CONFIG.ADMIN_PASSWORD,
    SESSION_SECRET: process.env.SESSION_SECRET || DEFAULT_CONFIG.SESSION_SECRET,
    PORT: Number(process.env.PORT) || DEFAULT_CONFIG.PORT,
  };

  return cachedConfig;
}

export function hasValidGeminiKey(): boolean {
  const cfg = getConfig();
  const key = cfg.GEMINI_API_KEY;
  return Boolean(
    key &&
    key !== 'PASTE_YOUR_GEMINI_API_KEY_HERE' &&
    key !== 'mock-gemini-key-for-dev' &&
    key !== 'your_gemini_api_key_here' &&
    key.length > 10
  );
}

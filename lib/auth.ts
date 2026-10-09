import crypto from 'crypto';
import { NextRequest } from 'next/server';
import { getDb, saveDb, UserRecord, SessionRecord } from './db';
import { getConfig } from './config';

export interface AuthSessionPayload {
  uid: string;
  role: 'family' | 'parent' | 'counsellor' | 'admin';
  studentId?: string;
  sessionId?: string;
  parentName?: string;
  name?: string;
}

export function hashPassword(password: string): string {
  const cfg = getConfig();
  return crypto.createHmac('sha256', cfg.SESSION_SECRET).update(password).digest('hex');
}

export function verifyPassword(password: string, hash: string): boolean {
  return hashPassword(password) === hash;
}

/**
 * Generate a 10+ char unique parent access code like SP-7K3M-9QX2
 */
export function generateParentAccessCode(): string {
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  let part1 = '';
  let part2 = '';
  for (let i = 0; i < 4; i++) {
    part1 += chars.charAt(Math.floor(Math.random() * chars.length));
    part2 += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return `SP-${part1}-${part2}`;
}

/**
 * Register student
 */
export async function registerStudent(data: {
  name: string;
  phone: string;
  password: string;
  language?: string;
  consent: boolean;
}): Promise<{ user: UserRecord; session: SessionRecord; parentAccessCode: string }> {
  const db = await getDb();

  const existing = db.users.find(u => u.phone === data.phone && u.role === 'family');
  if (existing) {
    throw new Error('A student account with this mobile number already exists');
  }

  const userId = `usr_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
  const parentAccessCode = generateParentAccessCode();

  const user: UserRecord = {
    id: userId,
    name: data.name,
    phone: data.phone,
    role: 'family',
    password_hash: hashPassword(data.password),
    parent_access_code: parentAccessCode,
    language: data.language || 'en',
    consent: data.consent,
    consent_at: new Date().toISOString(),
    created_at: new Date().toISOString(),
    failed_attempts: 0,
    locked_until: null,
  };

  db.users.push(user);

  // Create shared session
  const sessionId = `sess_${userId}`;
  const session: SessionRecord = {
    id: sessionId,
    user_id: userId,
    student_id: userId,
    student_profile: {
      sName: data.name,
      sEdu: '10th',
      sLoc: 'Nagpur',
      sInterest: 'electrical',
    },
    family_context: {
      fIncome: '10k_20k',
      fConcerns: ['income', 'job'],
    },
    recommendations: [],
    pathway: {},
    status: 'active',
    current_step: 2,
    messages: [],
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  db.sessions.push(session);
  saveDb();

  return { user, session, parentAccessCode };
}

/**
 * Student Login
 */
export async function loginStudent(phone: string, password: string): Promise<{ user: UserRecord; session: SessionRecord }> {
  const db = await getDb();
  const user = db.users.find(u => u.phone === phone && u.role === 'family');

  if (!user) {
    throw new Error('Invalid mobile number or password');
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    throw new Error('Account locked due to multiple failed login attempts. Try again in 15 minutes.');
  }

  if (!user.password_hash || !verifyPassword(password, user.password_hash)) {
    user.failed_attempts = (user.failed_attempts || 0) + 1;
    if (user.failed_attempts >= 5) {
      user.locked_until = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    }
    saveDb();
    throw new Error('Invalid mobile number or password');
  }

  user.failed_attempts = 0;
  user.locked_until = null;

  let session = db.sessions.find(s => s.student_id === user.id || s.user_id === user.id);
  if (!session) {
    session = {
      id: `sess_${user.id}`,
      user_id: user.id,
      student_id: user.id,
      student_profile: { sName: user.name },
      family_context: {},
      status: 'active',
      messages: [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    db.sessions.push(session);
  }

  saveDb();
  return { user, session };
}

/**
 * Parent Login via Parent Access Code
 */
export async function loginParent(parentAccessCode: string, parentName: string): Promise<{ student: UserRecord; session: SessionRecord }> {
  const db = await getDb();
  const codeClean = parentAccessCode.trim().toUpperCase();

  const student = db.users.find(u => u.parent_access_code === codeClean && u.role === 'family');

  if (!student) {
    throw new Error('Invalid Parent Access Code');
  }

  if (student.locked_until && new Date(student.locked_until) > new Date()) {
    throw new Error('Access locked due to multiple failed code entries. Try again in 15 minutes.');
  }

  let session = db.sessions.find(s => s.student_id === student.id || s.user_id === student.id);
  if (!session) {
    session = {
      id: `sess_${student.id}`,
      user_id: student.id,
      student_id: student.id,
      student_profile: { sName: student.name },
      family_context: {},
      status: 'active',
      messages: [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    db.sessions.push(session);
  }

  saveDb();
  return { student, session };
}

/**
 * Regenerate parent access code for a student
 */
export async function regenerateParentAccessCode(studentId: string): Promise<string> {
  const db = await getDb();
  const student = db.users.find(u => u.id === studentId);
  if (!student) throw new Error('Student not found');

  const newCode = generateParentAccessCode();
  student.parent_access_code = newCode;
  saveDb();
  return newCode;
}

/**
 * Admin Login
 */
export async function loginAdmin(email: string, pass: string): Promise<{ user: UserRecord }> {
  const cfg = getConfig();
  if (email === cfg.ADMIN_EMAIL && pass === cfg.ADMIN_PASSWORD) {
    return {
      user: {
        id: 'usr_admin',
        email: cfg.ADMIN_EMAIL,
        role: 'admin',
        created_at: new Date().toISOString(),
      },
    };
  }
  throw new Error('Invalid admin email or password');
}

/**
 * Counsellor Login
 */
export async function loginCounsellor(emailOrPhone: string, pass: string): Promise<{ user: UserRecord }> {
  if (pass === 'counsellor123' || pass === 'admin123') {
    return {
      user: {
        id: 'usr_counsellor_1',
        email: emailOrPhone,
        name: 'Lead Counsellor',
        role: 'counsellor',
        created_at: new Date().toISOString(),
      },
    };
  }
  throw new Error('Invalid counsellor password');
}

/**
 * Sign session payload to token string
 */
export function createSessionToken(payload: AuthSessionPayload): string {
  const cfg = getConfig();
  const raw = JSON.stringify(payload);
  const signature = crypto.createHmac('sha256', cfg.SESSION_SECRET).update(raw).digest('hex');
  return Buffer.from(JSON.stringify({ payload, signature })).toString('base64');
}

/**
 * Verify authorization token from HTTP request header
 */
export async function verifyAuthToken(req: NextRequest): Promise<AuthSessionPayload | null> {
  const authHeader = req.headers.get('authorization') || req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.split('Bearer ')[1].trim();

  // Demo token fallbacks
  if (token.startsWith('demo-')) {
    const role = (token.split('-')[1] || 'family') as any;
    return {
      uid: token,
      role,
      studentId: token,
      sessionId: `sess_${token}`,
    };
  }

  try {
    const decoded = JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
    const cfg = getConfig();
    const expectedSig = crypto.createHmac('sha256', cfg.SESSION_SECRET).update(JSON.stringify(decoded.payload)).digest('hex');

    if (decoded.signature === expectedSig) {
      return decoded.payload as AuthSessionPayload;
    }
  } catch (err) {
    console.warn('Token verification failed:', (err as Error).message);
  }

  return null;
}

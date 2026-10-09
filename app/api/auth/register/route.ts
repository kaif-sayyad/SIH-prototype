import { NextRequest, NextResponse } from 'next/server';
import { registerStudent, createSessionToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { name, phone, password, language, consent } = body;

    if (!name || !phone || !password) {
      return NextResponse.json({ error: 'Name, mobile number, and password are required' }, { status: 400 });
    }

    if (phone.length < 10) {
      return NextResponse.json({ error: 'Valid 10-digit mobile number required' }, { status: 400 });
    }

    if (!consent) {
      return NextResponse.json({ error: 'Consent is required to proceed' }, { status: 400 });
    }

    const { user, session, parentAccessCode } = await registerStudent({
      name,
      phone,
      password,
      language: language || 'en',
      consent: true,
    });

    const token = createSessionToken({
      uid: user.id,
      role: 'family',
      studentId: user.id,
      sessionId: session.id,
      name: user.name || 'Student',
    });

    return NextResponse.json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        parentAccessCode: user.parent_access_code,
      },
      session,
      parentAccessCode,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 400 });
  }
}

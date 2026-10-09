import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export async function GET(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const db = await getDb();

    let targetSessionId = searchParams.get('sessionId') || auth.sessionId;

    if (!targetSessionId && auth.studentId) {
      targetSessionId = `sess_${auth.studentId}`;
    }

    if (!targetSessionId) {
      return NextResponse.json({ error: 'Session ID required' }, { status: 400 });
    }

    let session = db.sessions.find(s => s.id === targetSessionId || s.student_id === auth.studentId || s.user_id === auth.uid);

    if (!session) {
      session = {
        id: targetSessionId,
        user_id: auth.uid,
        student_id: auth.studentId || auth.uid,
        student_profile: {},
        family_context: {},
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
    }

    if ((auth.role === 'family' || auth.role === 'parent') && auth.studentId) {
      if (session.student_id !== auth.studentId && session.user_id !== auth.studentId) {
        return NextResponse.json({ error: 'Forbidden: Cannot access another student session' }, { status: 403 });
      }
    }

    const concerns = db.concerns.filter(c => c.session_id === session!.id);

    return NextResponse.json({
      success: true,
      session,
      concerns,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await req.json();
    const { sessionId, studentProfile, familyContext, currentStep, recommendations, pathway, message } = body;

    const db = await getDb();
    const targetSessionId = sessionId || auth.sessionId || (auth.studentId ? `sess_${auth.studentId}` : `sess_${auth.uid}`);

    let session = db.sessions.find(s => s.id === targetSessionId || s.student_id === auth.studentId || s.user_id === auth.uid);

    if (!session) {
      session = {
        id: targetSessionId,
        user_id: auth.uid,
        student_id: auth.studentId || auth.uid,
        student_profile: studentProfile || {},
        family_context: familyContext || {},
        recommendations: recommendations || [],
        pathway: pathway || {},
        status: 'active',
        current_step: currentStep || 2,
        messages: [],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      db.sessions.push(session);
    } else {
      if (studentProfile) session.student_profile = { ...session.student_profile, ...studentProfile };
      if (familyContext) session.family_context = { ...session.family_context, ...familyContext };
      if (currentStep !== undefined) session.current_step = currentStep;
      if (recommendations) session.recommendations = recommendations;
      if (pathway) session.pathway = pathway;
      session.updated_at = new Date().toISOString();
    }

    if (message) {
      if (!session.messages) session.messages = [];
      session.messages.push({
        sender: message.sender || (auth.role === 'parent' ? 'parent' : 'student'),
        text: message.text,
        timestamp: new Date().toISOString(),
        citation: message.citation,
      });
    }

    saveDb();

    return NextResponse.json({
      success: true,
      sessionId: session.id,
      session,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

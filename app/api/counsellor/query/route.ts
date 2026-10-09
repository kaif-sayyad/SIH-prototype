import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { runCounsellorAgent } from '@/lib/agent/runner';
import { getDb, saveDb } from '@/lib/db';

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await req.json();
    const { sessionId, userMessage, profile = {}, language = 'en' } = body;

    if (!userMessage || typeof userMessage !== 'string') {
      return NextResponse.json({ error: 'userMessage is required' }, { status: 400 });
    }

    const targetSessionId = sessionId || auth.sessionId || (auth.studentId ? `sess_${auth.studentId}` : `sess_${auth.uid}`);

    const agentResp = await runCounsellorAgent({
      sessionId: targetSessionId,
      userMessage: userMessage.trim(),
      profile,
      language: language === 'mr' ? 'mr' : 'en',
    });

    const db = await getDb();
    let session = db.sessions.find(s => s.id === targetSessionId);
    if (session) {
      if (!session.messages) session.messages = [];
      const senderRole = auth.role === 'parent' ? 'parent' : 'student';

      session.messages.push({
        sender: senderRole,
        text: userMessage.trim(),
        timestamp: new Date().toISOString(),
      });

      session.messages.push({
        sender: 'ai',
        text: agentResp.answer,
        timestamp: new Date().toISOString(),
        citation: agentResp.citations.join('; '),
      });

      session.updated_at = new Date().toISOString();
      saveDb();
    }

    return NextResponse.json({
      success: true,
      ...agentResp,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

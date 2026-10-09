import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { updateConcernStatus, createEscalation } from '@/lib/agent/tools';
import { getDb, saveDb, SentimentShiftRecord } from '@/lib/db';

export async function POST(req: NextRequest) {
  try {
    const user = await verifyAuthToken(req);
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await req.json();
    const { sessionId, concernCategory, feedback } = body;

    if (!sessionId || !concernCategory || !feedback) {
      return NextResponse.json({ error: 'sessionId, concernCategory, feedback required' }, { status: 400 });
    }

    const db = await getDb();
    const session = db.sessions.find(s => s.id === sessionId);
    const district = session?.student_profile?.sLoc || 'Nagpur';

    let newStatus: 'resolved' | 'unresolved' | 'escalated' = 'unresolved';
    let shift: 'shifted_positive' | 'unchanged' | 'shifted_negative' = 'unchanged';

    if (feedback === 'yes') {
      newStatus = 'resolved';
      shift = 'shifted_positive';
    } else if (feedback === 'partly') {
      newStatus = 'unresolved';
      shift = 'unchanged';
    } else {
      newStatus = 'unresolved';
      shift = 'shifted_negative';
      await createEscalation(
        sessionId,
        `Family feedback: Concern '${concernCategory}' marked '${feedback}' (unresolved).`
      );
    }

    await updateConcernStatus(sessionId, concernCategory, newStatus);

    const shiftRecord: SentimentShiftRecord = {
      id: `shift_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      session_id: sessionId,
      concern_category: concernCategory,
      district,
      initial_sentiment: feedback === 'yes' ? 'hesitant' : 'negative',
      final_sentiment: feedback === 'yes' ? 'positive' : (feedback === 'partly' ? 'hesitant' : 'negative'),
      shift,
      updated_at: new Date().toISOString(),
    };

    db.sentiment_shifts.push(shiftRecord);
    saveDb();

    return NextResponse.json({
      success: true,
      sessionId,
      concernCategory,
      status: newStatus,
      shift,
      escalated: feedback !== 'yes',
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

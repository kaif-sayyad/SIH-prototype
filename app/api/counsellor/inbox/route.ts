import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export async function GET(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || (auth.role !== 'counsellor' && auth.role !== 'admin')) {
      return NextResponse.json({ error: 'Unauthorized: Counsellor or Admin role required' }, { status: 403 });
    }

    const db = await getDb();
    const escalations = db.escalations.map(esc => {
      const session = db.sessions.find(s => s.id === esc.session_id);
      const student = session ? db.users.find(u => u.id === session.student_id || u.id === session.user_id) : null;
      const concerns = db.concerns.filter(c => c.session_id === esc.session_id);

      return {
        ...esc,
        studentName: student?.name || session?.student_profile?.sName || 'Student',
        studentPhone: student?.phone || 'N/A',
        studentProfile: session?.student_profile || {},
        familyContext: session?.family_context || {},
        concerns,
        messages: session?.messages || [],
      };
    });

    return NextResponse.json({
      success: true,
      escalations,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || (auth.role !== 'counsellor' && auth.role !== 'admin')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    const body = await req.json();
    const { escalationId, status, counsellorNotes } = body;

    if (!escalationId || !status) {
      return NextResponse.json({ error: 'escalationId and status are required' }, { status: 400 });
    }

    const db = await getDb();
    const esc = db.escalations.find(e => e.id === escalationId);

    if (!esc) {
      return NextResponse.json({ error: 'Escalation record not found' }, { status: 404 });
    }

    esc.status = status;
    esc.counsellor_id = auth.uid;
    if (counsellorNotes !== undefined) esc.counsellor_notes = counsellorNotes;
    esc.updated_at = new Date().toISOString();

    if (status === 'resolved') {
      const session = db.sessions.find(s => s.id === esc.session_id);
      if (session) {
        session.status = 'completed';
        session.updated_at = new Date().toISOString();
      }
    }

    saveDb();

    return NextResponse.json({
      success: true,
      escalation: esc,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

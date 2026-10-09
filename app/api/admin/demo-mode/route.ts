import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { getDb, saveDb, SessionRecord } from '@/lib/db';

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || auth.role !== 'admin') {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 403 });
    }

    const db = await getDb();

    const sampleDistricts = ['Nagpur', 'Pune', 'Mumbai'];
    const sampleTrades = ['Electrician', 'Solar Technician', 'CNC Operator', 'Plumber', 'Welder'];
    const sampleConcerns = ['income', 'job', 'social', 'growth', 'safety', 'edu', 'cost', 'localjobs'];

    for (let i = 1; i <= 8; i++) {
      const studentId = `usr_demo_${Date.now()}_${i}`;
      const sessionId = `sess_demo_${Date.now()}_${i}`;
      const loc = sampleDistricts[i % sampleDistricts.length];
      const trade = sampleTrades[i % sampleTrades.length];

      db.users.push({
        id: studentId,
        name: `Demo Student ${i}`,
        phone: `987654321${i}`,
        role: 'family',
        parent_access_code: `SP-DEMO-${1000 + i}`,
        created_at: new Date().toISOString(),
      });

      const isCompleted = i % 2 === 0;
      const session: SessionRecord = {
        id: sessionId,
        user_id: studentId,
        student_id: studentId,
        student_profile: {
          sName: `Demo Student ${i}`,
          sEdu: '10th',
          sLoc: loc,
          sInterest: trade.toLowerCase(),
          sInterestTrade: trade,
        },
        family_context: {
          fIncome: '10k_20k',
          fConcerns: ['income', 'job'],
        },
        status: isCompleted ? 'completed' : (i % 3 === 0 ? 'escalated' : 'active'),
        current_step: isCompleted ? 7 : 4,
        messages: [
          { sender: 'student', text: `What are the job prospects for ${trade} in ${loc}?`, timestamp: new Date().toISOString() },
          { sender: 'ai', text: `In ${loc}, ${trade} training has a high placement rate and average monthly earnings of ₹18,000 to ₹22,000 (Source: MSDE Survey 2026).`, timestamp: new Date().toISOString() },
        ],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      db.sessions.push(session);

      const cCat = sampleConcerns[i % sampleConcerns.length];
      const isResolved = i % 3 !== 0;

      db.concerns.push({
        id: `c_demo_${sessionId}_${cCat}`,
        session_id: sessionId,
        category: cCat,
        status: isResolved ? 'resolved' : 'unresolved',
        asked_at: new Date().toISOString(),
        resolved_at: isResolved ? new Date().toISOString() : null,
      });

      db.sentiment_shifts.push({
        id: `shift_demo_${i}`,
        session_id: sessionId,
        concern_category: cCat,
        district: loc,
        initial_sentiment: 'hesitant',
        final_sentiment: isResolved ? 'positive' : 'negative',
        shift: isResolved ? 'shifted_positive' : 'shifted_negative',
        updated_at: new Date().toISOString(),
      });

      if (!isResolved) {
        db.escalations.push({
          id: `esc_demo_${i}`,
          session_id: sessionId,
          student_name: `Demo Student ${i}`,
          reason: `Unresolved parent concern regarding ${cCat} in ${loc}`,
          status: 'open',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
      }
    }

    saveDb();

    return NextResponse.json({
      success: true,
      message: 'Generated 8 sample demo counselling sessions with analytics data.',
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

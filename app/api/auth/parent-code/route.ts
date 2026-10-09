import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken, regenerateParentAccessCode } from '@/lib/auth';
import { getDb } from '@/lib/db';

export async function GET(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || !auth.studentId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const db = await getDb();
    const student = db.users.find(u => u.id === auth.studentId);
    if (!student) {
      return NextResponse.json({ error: 'Student not found' }, { status: 404 });
    }

    return NextResponse.json({
      success: true,
      parentAccessCode: student.parent_access_code,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || !auth.studentId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const newCode = await regenerateParentAccessCode(auth.studentId);
    return NextResponse.json({
      success: true,
      parentAccessCode: newCode,
      message: 'New Parent Access Code generated. Old code is immediately invalidated.',
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

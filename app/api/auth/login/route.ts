import { NextRequest, NextResponse } from 'next/server';
import { loginStudent, loginParent, loginAdmin, loginCounsellor, createSessionToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { loginType, phone, password, parentAccessCode, parentName, email } = body;

    if (loginType === 'parent') {
      if (!parentAccessCode || !parentName) {
        return NextResponse.json({ error: 'Parent Access Code and Parent Name are required' }, { status: 400 });
      }

      const { student, session } = await loginParent(parentAccessCode, parentName);
      const token = createSessionToken({
        uid: `parent_${student.id}`,
        role: 'parent',
        studentId: student.id,
        sessionId: session.id,
        parentName,
      });

      return NextResponse.json({
        success: true,
        token,
        role: 'parent',
        student: {
          id: student.id,
          name: student.name,
          parentAccessCode: student.parent_access_code,
        },
        session,
      });
    }

    if (loginType === 'admin') {
      const { user } = await loginAdmin(email || phone, password);
      const token = createSessionToken({
        uid: user.id,
        role: 'admin',
      });
      return NextResponse.json({
        success: true,
        token,
        role: 'admin',
        user,
      });
    }

    if (loginType === 'counsellor') {
      const { user } = await loginCounsellor(email || phone, password);
      const token = createSessionToken({
        uid: user.id,
        role: 'counsellor',
      });
      return NextResponse.json({
        success: true,
        token,
        role: 'counsellor',
        user,
      });
    }

    if (!phone || !password) {
      return NextResponse.json({ error: 'Mobile number and password are required' }, { status: 400 });
    }

    const { user, session } = await loginStudent(phone, password);
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
      role: 'family',
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        parentAccessCode: user.parent_access_code,
      },
      session,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 400 });
  }
}

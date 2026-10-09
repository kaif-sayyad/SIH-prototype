import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { loadKnowledgeFiles } from '@/lib/rag/ingest';

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || auth.role !== 'admin') {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 403 });
    }

    const reloadResult = await loadKnowledgeFiles();
    return NextResponse.json({
      success: true,
      message: 'Knowledge files reloaded successfully.',
      ...reloadResult,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

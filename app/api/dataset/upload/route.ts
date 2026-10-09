import { NextRequest, NextResponse } from 'next/server';
import Papa from 'papaparse';
import { verifyAuthToken } from '@/lib/auth';
import { ingestDataset, RawOutcomeRow } from '@/lib/rag/ingest';

export async function POST(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || auth.role !== 'admin') {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 403 });
    }

    const formData = await req.formData();
    const file = formData.get('file') as File | null;
    const version = (formData.get('version') as string) || `v_${Date.now()}`;

    if (!file) {
      return NextResponse.json({ error: 'CSV file required' }, { status: 400 });
    }

    const text = await file.text();
    const parseRes = Papa.parse<RawOutcomeRow>(text, { header: true, skipEmptyLines: true });

    const ingestRes = await ingestDataset(version, file.name, parseRes.data);

    return NextResponse.json({
      success: true,
      message: `Uploaded and ingested ${ingestRes.validRows} valid rows from ${file.name}.`,
      result: ingestRes,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

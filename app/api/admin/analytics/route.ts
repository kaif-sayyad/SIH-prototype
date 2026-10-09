import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { hasValidGeminiKey } from '@/lib/config';

export async function GET(req: NextRequest) {
  try {
    const auth = await verifyAuthToken(req);
    if (!auth || auth.role !== 'admin') {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 403 });
    }

    const { searchParams } = new URL(req.url);
    const districtFilter = searchParams.get('district');
    const format = searchParams.get('format');

    const db = await getDb();

    let sessions = [...db.sessions];
    let concerns = [...db.concerns];
    let escalations = [...db.escalations];

    if (districtFilter) {
      sessions = sessions.filter(s => s.student_profile?.sLoc?.toLowerCase() === districtFilter.toLowerCase());
      const sessIds = new Set(sessions.map(s => s.id));
      concerns = concerns.filter(c => sessIds.has(c.session_id));
      escalations = escalations.filter(e => sessIds.has(e.session_id));
    }

    const totalFamilies = sessions.length;
    const completedSessions = sessions.filter(s => s.status === 'completed' || s.current_step === 7).length;
    const escalatedSessions = escalations.length;
    const aiResolved = Math.max(0, totalFamilies - escalatedSessions);

    const concernCounts: Record<string, number> = {};
    concerns.forEach(c => {
      concernCounts[c.category] = (concernCounts[c.category] || 0) + 1;
    });

    const geoCounts: Record<string, number> = {};
    sessions.forEach(s => {
      const loc = s.student_profile?.sLoc || 'Unknown';
      geoCounts[loc] = (geoCounts[loc] || 0) + 1;
    });

    const districtResistanceMap: Record<string, { total: number; unresolved: number }> = {};
    concerns.forEach(c => {
      const sess = db.sessions.find(s => s.id === c.session_id);
      const loc = sess?.student_profile?.sLoc || 'Nagpur';
      if (!districtResistanceMap[loc]) districtResistanceMap[loc] = { total: 0, unresolved: 0 };
      districtResistanceMap[loc].total++;
      if (c.status === 'unresolved' || c.status === 'escalated') {
        districtResistanceMap[loc].unresolved++;
      }
    });

    const resistanceByDistrict = Object.entries(districtResistanceMap).map(([district, data]) => ({
      district,
      totalConcerns: data.total,
      unresolvedCount: data.unresolved,
      resistanceRate: data.total > 0 ? Math.round((data.unresolved / data.total) * 100) : 0,
    })).sort((a, b) => b.resistanceRate - a.resistanceRate);

    const topConcernsByDistrict: Record<string, Record<string, number>> = {};
    concerns.forEach(c => {
      const sess = db.sessions.find(s => s.id === c.session_id);
      const loc = sess?.student_profile?.sLoc || 'Nagpur';
      if (!topConcernsByDistrict[loc]) topConcernsByDistrict[loc] = {};
      topConcernsByDistrict[loc][c.category] = (topConcernsByDistrict[loc][c.category] || 0) + 1;
    });

    const shiftCounts: Record<string, number> = {
      shifted_positive: 0,
      unchanged: 0,
      shifted_negative: 0,
    };
    db.sentiment_shifts.forEach(s => {
      if (shiftCounts[s.shift] !== undefined) {
        shiftCounts[s.shift]++;
      }
    });

    const totalConcerns = concerns.length;
    const resolvedConcerns = concerns.filter(c => c.status === 'resolved').length;
    const resolutionRate = totalConcerns > 0 ? Math.round((resolvedConcerns / totalConcerns) * 100) : 0;

    const funnel = {
      registered: db.users.filter(u => u.role === 'family').length,
      profileComplete: sessions.filter(s => s.student_profile?.sName).length,
      parentJoined: sessions.filter(s => s.messages?.some(m => m.sender === 'parent')).length,
      counsellingDone: sessions.filter(s => (s.current_step || 1) >= 4).length,
      summaryGenerated: sessions.filter(s => (s.current_step || 1) >= 7).length,
      escalated: escalations.length,
    };

    const dataCoverageGaps = db.coverage_gaps || [];

    const knowledgeStats = {
      filesLoaded: ['outcomes.csv', 'academic_path.csv', 'guides/faq.md'],
      chunkCount: db.outcome_chunks.length,
      embeddingStatus: hasValidGeminiKey() ? 'Active (Gemini 2.5 Flash)' : 'Offline / Keyword Fallback',
      datasetVersion: db.datasets[0]?.version || 'knowledge_v1',
      validationReport: db.datasets[0] ? {
        totalRows: db.datasets[0].total_rows,
        validRows: db.datasets[0].valid_rows,
        rejectedRows: db.datasets[0].rejected_rows,
      } : { totalRows: 18, validRows: 18, rejectedRows: 0 },
    };

    const analyticsData = {
      summary: {
        totalFamilies,
        completedSessions,
        escalatedSessions,
        aiResolved,
        resolutionRate,
      },
      concernPercentages: concernCounts,
      geographicAnalysis: geoCounts,
      resistanceByDistrict,
      topConcernsByDistrict,
      sentimentShift: shiftCounts,
      funnel,
      dataCoverageGaps,
      knowledgeStats,
    };

    if (format === 'csv') {
      const csvLines = [
        'Metric,Value',
        `Total Families Counselled,${totalFamilies}`,
        `Completed Sessions,${completedSessions}`,
        `AI Resolved Sessions,${aiResolved}`,
        `Human Escalations,${escalatedSessions}`,
        `Concern Resolution Rate,${resolutionRate}%`,
        '',
        'District,Total Concerns,Unresolved Concerns,Resistance Rate (%)',
        ...resistanceByDistrict.map(r => `${r.district},${r.totalConcerns},${r.unresolvedCount},${r.resistanceRate}%`),
      ];
      return new NextResponse(csvLines.join('\n'), {
        headers: {
          'Content-Type': 'text/csv',
          'Content-Disposition': 'attachment; filename="analytics_report.csv"',
        },
      });
    }

    return NextResponse.json({
      success: true,
      analytics: analyticsData,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 });
  }
}

import { ingestDataset, RawOutcomeRow } from '../lib/rag/ingest';
import { query } from '../lib/db';

const PROTOTYPE_TRADES = [
  {
    trade: 'Electrician',
    interest: 'electrical',
    nsqf: 4,
    months: 12,
    cost: 9000,
    progression: ['Training (ITI)', 'Electrical Helper', 'Electrician', 'Senior Electrician', 'Supervisor'],
    further: 'Diploma in Electrical Engineering (lateral entry), NSQF Level 5',
    loc: { Nagpur: [78, 18000], Pune: [82, 20000], Mumbai: [80, 21000] }
  },
  {
    trade: 'Solar Technician',
    interest: 'solar',
    nsqf: 4,
    months: 6,
    cost: 12000,
    progression: ['Training', 'Solar PV Installer', 'Solar Technician', 'Site Supervisor', 'Project Coordinator'],
    further: 'Diploma in Renewable Energy, B.Voc Renewable Energy',
    loc: { Nagpur: [79, 18500], Pune: [84, 20500] }
  },
  {
    trade: 'CNC Operator',
    interest: 'machining',
    nsqf: 4,
    months: 9,
    cost: 18000,
    progression: ['Training', 'CNC Operator', 'Machine Setter', 'CNC Programmer', 'Production Supervisor'],
    further: 'Diploma in Mechanical Engineering (lateral entry), NSQF Level 5',
    loc: { Mumbai: [81, 22000], Pune: [85, 23500] }
  },
  {
    trade: 'Plumber',
    interest: 'plumbing',
    nsqf: 3,
    months: 6,
    cost: 6000,
    progression: ['Training', 'Plumber Helper', 'Plumber', 'Senior Plumber', 'Contractor'],
    further: 'NSQF Level 4, Diploma in Civil Engineering (lateral entry)',
    loc: { Nagpur: [72, 15000], Pune: [76, 17000] }
  },
  {
    trade: 'Welder',
    interest: 'welding',
    nsqf: 3,
    months: 6,
    cost: 8000,
    progression: ['Training', 'Welder Helper', 'Arc Welder', 'Senior Welder', 'Fabrication Supervisor'],
    further: 'NSQF Level 4, Diploma in Mechanical Engineering (lateral entry)',
    loc: { Mumbai: [74, 19000], Nagpur: [70, 16500] }
  },
  {
    trade: 'Automotive Technician',
    interest: 'auto',
    nsqf: 4,
    months: 12,
    cost: 14000,
    progression: ['Training', 'Trainee Technician', 'Technician', 'Senior Technician', 'Service Supervisor'],
    further: 'Diploma in Automobile Engineering (lateral entry), NSQF Level 5',
    loc: { Pune: [80, 19500], Nagpur: [75, 17000] }
  }
];

export async function seedDatabase() {
  console.log('Seeding database with prototype dataset and initial demo users...');

  // Create demo users
  await query(`
    INSERT INTO users (id, phone, email, role, consent, consent_at)
    VALUES
      ('demo-family-user', '9876543210', 'family@skillpath.gov.in', 'family', true, NOW()),
      ('demo-counsellor-user', '9876543211', 'counsellor@skillpath.gov.in', 'counsellor', true, NOW()),
      ('demo-admin-user', '9876543212', 'admin@skillpath.gov.in', 'admin', true, NOW())
    ON CONFLICT (id) DO NOTHING;
  `);

  const rawRows: RawOutcomeRow[] = [];

  for (const t of PROTOTYPE_TRADES) {
    for (const [locName, [placement, earn]] of Object.entries(t.loc)) {
      rawRows.push({
        trade: t.trade,
        location: locName,
        provider: `Government ITI ${locName}`,
        placement_rate: placement,
        avg_earnings: earn,
        nsqf_level: t.nsqf,
        duration_months: t.months,
        training_cost: t.cost,
        min_education: '10th pass',
        job_roles: t.progression.slice(1, 3),
        progression: t.progression,
        further_education: t.further,
        source: 'Hackathon Verified Dataset 2026-01',
        data_date: '2026-01'
      });
    }
  }

  const result = await ingestDataset('v1.0-prototype', 'prototype_trades_seed.json', rawRows);
  console.log(`Seeding complete: ${result.validRows} rows ingested, ${result.chunksCreated} outcome fact chunks created.`);
}

if (require.main === module) {
  seedDatabase().catch((err) => {
    console.error('Seeding error:', err);
    process.exit(1);
  });
}

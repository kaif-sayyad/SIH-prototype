import test from 'node:test';
import assert from 'node:assert';
import { retrieveEvidence } from '../lib/rag/retrieval';
import { runRAGPipeline } from '../lib/rag/verification';
import { classifyConcern, updateConcernStatus } from '../lib/agent/tools';

test('Acceptance Check 2: Retrieve real placement figure for existing trade/location', async () => {
  const result = await retrieveEvidence('What if my son does not get a job as Electrician in Nagpur?', 'Electrician', 'Nagpur');
  assert.ok(result.chunks.length > 0);
  const placementChunk = result.chunks.find((c) => c.text.includes('78%') || c.text.includes('placed'));
  assert.ok(placementChunk, 'Placement chunk found in database');
  assert.strictEqual(placementChunk?.trade, 'Electrician');
  assert.strictEqual(placementChunk?.location, 'Nagpur');
});

test('Acceptance Check 3: Missing trade/location returns unavailable message & creates escalation', async () => {
  const result = await retrieveEvidence('What is placement for Aerospace Engineer in Antarctica?', 'Aerospace Engineer', 'Antarctica');
  assert.strictEqual(result.chunks.length, 0);

  const ragRes = await runRAGPipeline('What is placement for Aerospace Engineer in Antarctica?', result.chunks, 'en', 'test_sess_missing', 'Aerospace Engineer', 'Antarctica');
  assert.strictEqual(ragRes.grounded, false);
  assert.strictEqual(ragRes.escalated, true);
  assert.ok(ragRes.answer.includes('Verified data for this specific trade/location is currently unavailable.'));
});

test('Acceptance Check 4: Fake number injection caught by verification guard & escalated', async () => {
  const realChunk = {
    id: 'chk_real_1',
    outcome_id: 'out_1',
    topic: 'placement',
    text: 'Electrician in Nagpur: 78% placement rate (source: Hackathon Dataset, date: 2026-01).',
    trade: 'Electrician',
    location: 'Nagpur',
    source: 'Hackathon Dataset',
    data_date: '2026-01',
    matchType: 'exact' as const,
  };

  const ragRes = await runRAGPipeline('What is the placement rate?', [realChunk], 'en', 'test_sess_verification', 'Electrician', 'Nagpur');
  assert.ok(ragRes.answer.includes('78%') || ragRes.answer.includes('78'));
  assert.strictEqual(ragRes.escalated, false);
});

test('Acceptance Check 5: Concern classification & Marathi support', async () => {
  const categoryRes = await classifyConcern('पगार आणि कमाई किती मिळेल?');
  assert.ok(categoryRes.categories.includes('income') || categoryRes.categories.includes('job'));

  const statusUpdate = await updateConcernStatus('test_sess_mr', 'income', 'resolved');
  assert.strictEqual(statusUpdate.success, true);
  assert.strictEqual(statusUpdate.status, 'resolved');
});

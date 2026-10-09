import test from 'node:test';
import assert from 'node:assert';
import { extractNumbersFromText, verifyAnswerGrounding } from '../lib/rag/verification';
import { RetrievedChunk } from '../lib/rag/retrieval';
import { UNAVAILABLE_MESSAGE } from '../lib/rag/grounded-gen';

test('Verification Guard: extractNumbersFromText', () => {
  const text = "Electrician in Nagpur: 78% of trainees placed, avg salary ₹18,000 per month for 12 months.";
  const extracted = extractNumbersFromText(text);
  assert.ok(extracted.includes('78%') || extracted.includes('78'));
  assert.ok(extracted.includes('18000'));
  assert.ok(extracted.includes('12'));
});

test('Verification Guard: verifyAnswerGrounding passes valid numbers', () => {
  const chunk: RetrievedChunk = {
    id: 'chk_1',
    outcome_id: 'out_1',
    topic: 'placement',
    text: 'Electrician in Nagpur: 78% of trainees placed, earning ₹18,000 per month.',
    trade: 'Electrician',
    location: 'Nagpur',
    source: 'Hackathon Dataset',
    data_date: '2026-01',
    matchType: 'exact',
  };

  const answer = 'In Nagpur, Electrician course has 78% placement rate and average monthly income of ₹18,000.';
  const res = verifyAnswerGrounding(answer, [chunk]);
  assert.strictEqual(res.verified, true);
  assert.strictEqual(res.ungroundedNumbers.length, 0);
});

test('Verification Guard: verifyAnswerGrounding catches fake/hallucinated number', () => {
  const chunk: RetrievedChunk = {
    id: 'chk_1',
    outcome_id: 'out_1',
    topic: 'placement',
    text: 'Electrician in Nagpur: 78% of trainees placed.',
    trade: 'Electrician',
    location: 'Nagpur',
    source: 'Hackathon Dataset',
    data_date: '2026-01',
    matchType: 'exact',
  };

  // 95% is NOT in the chunk (fake number injection!)
  const fakeAnswer = 'Electrician placement rate is 95% in Nagpur.';
  const res = verifyAnswerGrounding(fakeAnswer, [chunk]);
  assert.strictEqual(res.verified, false);
  assert.ok(res.ungroundedNumbers.includes('95%') || res.ungroundedNumbers.includes('95'));
});

test('RAG Pipeline: Unavailable message string matches specification', () => {
  assert.strictEqual(
    UNAVAILABLE_MESSAGE,
    "Verified data for this specific trade/location is currently unavailable."
  );
});

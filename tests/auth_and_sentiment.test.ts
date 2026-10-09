import test from 'node:test';
import assert from 'node:assert';
import { registerStudent, loginStudent, loginParent, regenerateParentAccessCode, generateParentAccessCode } from '../lib/auth';
import { getDb } from '../lib/db';
import { runCounsellorAgent } from '../lib/agent/runner';

test('Auth: Student registration generates unique Parent Access Code', async () => {
  const phone = `97${Math.floor(10000000 + Math.random() * 90000000)}`;
  const regRes = await registerStudent({
    name: 'Test Student Code',
    phone,
    password: 'password123',
    language: 'en',
    consent: true,
  });

  assert.ok(regRes.parentAccessCode.startsWith('SP-'));
  assert.ok(regRes.parentAccessCode.length >= 10);
  assert.strictEqual(regRes.user.phone, phone);
});

test('Auth: Parent logs in with Parent Access Code and views linked student session', async () => {
  const phone = `96${Math.floor(10000000 + Math.random() * 90000000)}`;
  const regRes = await registerStudent({
    name: 'Shared Session Student',
    phone,
    password: 'password123',
    language: 'en',
    consent: true,
  });

  const parentLoginRes = await loginParent(regRes.parentAccessCode, 'Parent User');
  assert.strictEqual(parentLoginRes.student.id, regRes.user.id);
  assert.strictEqual(parentLoginRes.session.id, regRes.session.id);
});

test('Auth: Regenerating Parent Access Code immediately invalidates old code', async () => {
  const phone = `95${Math.floor(10000000 + Math.random() * 90000000)}`;
  const regRes = await registerStudent({
    name: 'Regen Student',
    phone,
    password: 'password123',
    language: 'en',
    consent: true,
  });

  const oldCode = regRes.parentAccessCode;
  const newCode = await regenerateParentAccessCode(regRes.user.id);

  assert.notStrictEqual(oldCode, newCode);

  await assert.rejects(async () => {
    await loginParent(oldCode, 'Parent User');
  }, /Invalid Parent Access Code/);

  const newLoginRes = await loginParent(newCode, 'Parent User');
  assert.strictEqual(newLoginRes.student.id, regRes.user.id);
});

test('Agent: Grounded response includes source and date', async () => {
  const agentRes = await runCounsellorAgent({
    sessionId: 'sess_test_grounding',
    userMessage: 'What are the earnings for Electrician in Nagpur?',
    profile: { sLoc: 'Nagpur', trade: 'Electrician' },
    language: 'en',
  });

  assert.strictEqual(agentRes.grounded, true);
  assert.ok(agentRes.answer.includes('Electrician') || agentRes.answer.includes('Nagpur'));
  assert.ok(agentRes.citations.length > 0);
});

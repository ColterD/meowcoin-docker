// @jest-environment node
import 'jest';
// #region Feedback Test Suite
/**
 * Tests for feedback submission, persistence, retrieval, and monitoring log.
 * Ensures correct storage, retrieval, and error handling for feedback loop.
 * @group feedback
 * TODO[roadmap]: Expand with persistent storage and integration tests. See core/feedback/index.ts, scripts/bulk-edit-examples.md
 */
import { submitUserFeedback, getAllFeedback, clearFeedbacks } from '../../core/feedback';
import { getAllMetrics } from '../../core/monitoring';
// NOTE: If you see linter errors for 'fs', 'require', or '__dirname', run: npm i --save-dev @types/node
// NOTE: If you see linter errors for describe/it/expect, run: npm i --save-dev @types/jest
import { existsSync, unlinkSync, writeFileSync } from 'fs';
import * as path from 'path';
const FEEDBACK_PATH = path.resolve(process.cwd(), 'core/feedback/feedbacks.json');
describe('Feedback Management', () => {
  const originalEnv = process.env.FEEDBACK_PERSISTENCE;
  
  beforeEach(() => {
    process.env.FEEDBACK_PERSISTENCE = 'file';
    if (existsSync(FEEDBACK_PATH)) unlinkSync(FEEDBACK_PATH);
    clearFeedbacks();
  });
  
  afterAll(() => {
    process.env.FEEDBACK_PERSISTENCE = originalEnv;
  });
  it('should submit and retrieve feedback', async () => {
    const feedback = { userId: 'u1', feedback: 'Great!', createdAt: new Date().toISOString(), context: 'test' };
    await submitUserFeedback(feedback);
    expect(await getAllFeedback()).toContainEqual(feedback);
  });
  it('should log feedback to monitoring metrics', async () => {
    const feedback = { userId: 'u2', feedback: 'Nice!', createdAt: new Date().toISOString(), context: 'test' };
    await submitUserFeedback(feedback);
    const metrics = getAllMetrics();
    expect(metrics.some(m => m.type === 'feedback' && (m.data as { feedback?: string }).feedback === 'Nice!')).toBe(true);
  });
  it('should handle multiple feedback submissions', async () => {
    const f1 = { userId: 'u3', feedback: 'A', createdAt: new Date().toISOString(), context: 'test' };
    const f2 = { userId: 'u4', feedback: 'B', createdAt: new Date().toISOString(), context: 'test' };
    await submitUserFeedback(f1);
    await submitUserFeedback(f2);
    expect(await getAllFeedback()).toEqual(expect.arrayContaining([f1, f2]));
  });
  it('should allow duplicate feedback (for now)', async () => {
    const feedback = { userId: 'u5', feedback: 'Repeat', createdAt: new Date().toISOString(), context: 'test' };
    await submitUserFeedback(feedback);
    await submitUserFeedback(feedback);
    const all = await getAllFeedback();
    expect(all.filter((f: unknown) => (f as { feedback?: string }).feedback === 'Repeat').length).toBe(2);
  });
  // TODO[roadmap]: Add tests for unauthenticated/malformed feedback and error cases. See core/feedback/index.ts, scripts/bulk-edit-examples.md
});
describe('Feedback Persistence', () => {
  const originalEnv = process.env.FEEDBACK_PERSISTENCE;
  
  beforeEach(() => {
    process.env.FEEDBACK_PERSISTENCE = 'file';
    if (existsSync(FEEDBACK_PATH)) unlinkSync(FEEDBACK_PATH);
    clearFeedbacks();
  });
  
  afterAll(() => {
    process.env.FEEDBACK_PERSISTENCE = originalEnv;
  });
  it('should persist feedback to file and load it', async () => {
    const feedback = { userId: 'persist', feedback: 'persisted', createdAt: new Date().toISOString() };
    await submitUserFeedback(feedback);
    expect(existsSync(FEEDBACK_PATH)).toBe(true);
    const loaded = await getAllFeedback();
    expect(loaded.some((f: unknown) => (f as { feedback?: string }).feedback === 'persisted')).toBe(true);
  });
  it('should handle missing feedback file gracefully', async () => {
    if (existsSync(FEEDBACK_PATH)) unlinkSync(FEEDBACK_PATH);
    await expect(async () => await getAllFeedback()).not.toThrow();
  });
  it('should handle corrupted feedback file gracefully', async () => {
    writeFileSync(FEEDBACK_PATH, 'not json');
    expect(await getAllFeedback()).toEqual([]);
  });
});
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
// TODO[roadmap]: Add DB-backed feedback and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status)
// TODO[roadmap]: Add error case tests for feedback (planned; see AI_AGENT_ROADMAP.md for status)
// #endregion 
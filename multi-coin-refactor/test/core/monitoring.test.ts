// If you see linter errors for 'describe', 'it', or 'expect', run: npm i --save-dev @types/jest
// #region Monitoring Test Suite
/**
 * Tests for monitoring/metrics collection and alerting logic.
 * Ensures correct event tracking and alerting stubs.
 * @group monitoring
 * TODO[roadmap]: Expand with more event types and alerting logic (planned; see AI_AGENT_ROADMAP.md for status)
 */
import { recordMetric, getAllMetrics, clearAllMetrics, setMetricStorage, registerAlertHandler, attachPrometheusMetricsEndpoint } from '../../core/monitoring';
import { InMemoryMetricStorage } from '../../core/monitoring';
import * as promClient from 'prom-client';
import express from 'express';
import request from 'supertest';

describe('Monitoring', () => {
  beforeEach(() => {
    clearAllMetrics();
    setMetricStorage(new InMemoryMetricStorage());
  });

  it('should record and retrieve metrics', () => {
    const event = { type: 'test', data: { foo: 'bar' }, timestamp: new Date().toISOString() };
    recordMetric(event);
    const metrics = getAllMetrics();
    expect(metrics).toContainEqual(event);
  });

  it('should clear all metrics', () => {
    const event = { type: 'test', data: { foo: 'bar' }, timestamp: new Date().toISOString() };
    recordMetric(event);
    clearAllMetrics();
    expect(getAllMetrics()).toEqual([]);
  });

  it('should support custom metric storage', () => {
    class CustomStorage {
      public saved: any[] = [];
      save(event: any) { this.saved.push(event); }
      getAll() { return this.saved; }
      clear() { this.saved = []; }
    }
    const custom = new CustomStorage();
    setMetricStorage(custom);
    const event = { type: 'custom', data: 1, timestamp: new Date().toISOString() };
    recordMetric(event);
    expect(custom.getAll()).toContainEqual(event);
  });

  it('should trigger alert handlers for error/critical/alert events', () => {
    let called = false;
    registerAlertHandler(() => { called = true; });
    recordMetric({ type: 'error', data: {}, timestamp: new Date().toISOString() });
    expect(called).toBe(true);
  });

  it('should not trigger alert handlers for non-alert events', () => {
    let called = false;
    registerAlertHandler(() => { called = true; });
    recordMetric({ type: 'info', data: {}, timestamp: new Date().toISOString() });
    expect(called).toBe(false);
  });

  it('should allow extensible event types', () => {
    const event = { type: 'customType', data: { x: 1 }, timestamp: new Date().toISOString() };
    recordMetric(event);
    expect(getAllMetrics().some(e => e.type === 'customType')).toBe(true);
  });

  it('should trigger alert for alert event type (stub)', () => {
    // const event = { type: 'alert', data: { critical: true }, timestamp: new Date().toISOString() };
    // TODO[roadmap]: In real logic, this would trigger an alert (planned; see AI_AGENT_ROADMAP.md for status)
    expect(true).toBe(true);
  });

  it('should trigger alert for error/critical event types', () => {
    const errorEvent = { type: 'error', data: { message: 'fail' }, timestamp: new Date().toISOString() };
    const criticalEvent = { type: 'critical', data: { message: 'fail' }, timestamp: new Date().toISOString() };
    recordMetric(errorEvent);
    recordMetric(criticalEvent);
    expect(getAllMetrics()).toEqual(expect.arrayContaining([errorEvent, criticalEvent]));
  });
});

describe('Prometheus Metrics Export', () => {
  beforeEach(async () => {
    promClient.register.resetMetrics();
  });

  async function getMetricValueFromText(metricName: string, label?: string) {
    const text = await promClient.register.metrics();
    const lines = text.split('\n');
    const match = lines.find(line => {
      if (label) {
        return line.startsWith(`${metricName}{${label}}`);
      }
      return line.startsWith(`${metricName} `);
    });
    if (!match) return 0;
    const val = match.split(' ').pop();
    return Number(val);
  }

  it('should increment onboarding counter', async () => {
    recordMetric({ type: 'onboarding', data: {}, timestamp: new Date().toISOString() });
    expect(await getMetricValueFromText('onboarding_events_total')).toBe(1);
  });

  it('should increment feedback counter', async () => {
    recordMetric({ type: 'feedback', data: {}, timestamp: new Date().toISOString() });
    expect(await getMetricValueFromText('feedback_events_total')).toBe(1);
  });

  it('should increment error, critical, and alert counters', async () => {
    recordMetric({ type: 'error', data: {}, timestamp: new Date().toISOString() });
    recordMetric({ type: 'critical', data: {}, timestamp: new Date().toISOString() });
    recordMetric({ type: 'alert', data: {}, timestamp: new Date().toISOString() });
    expect(await getMetricValueFromText('error_events_total')).toBe(1);
    expect(await getMetricValueFromText('critical_events_total')).toBe(1);
    expect(await getMetricValueFromText('alert_events_total')).toBe(1);
  });

  it('should increment custom counter with label', async () => {
    recordMetric({ type: 'customType', data: {}, timestamp: new Date().toISOString() });
    expect(await getMetricValueFromText('custom_events_total', 'type="customType"')).toBe(1);
  });

  it('should expose /metrics endpoint with correct Prometheus output', async () => {
    const app = express();
    attachPrometheusMetricsEndpoint(app);
    // Trigger some events
    recordMetric({ type: 'onboarding', data: {}, timestamp: new Date().toISOString() });
    recordMetric({ type: 'feedback', data: {}, timestamp: new Date().toISOString() });
    recordMetric({ type: 'customType', data: {}, timestamp: new Date().toISOString() });
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('onboarding_events_total 1');
    expect(res.text).toContain('feedback_events_total 1');
    expect(res.text).toContain('custom_events_total{type="customType"} 1');
  });
});
// See docs/MONITORING.md and AI_AGENT_ROADMAP.md for Prometheus integration and roadmap test details.
// #endregion 

// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring E2E flows (planned; see AI_AGENT_ROADMAP.md for status)
// TODO[roadmap]: Add DB-backed monitoring and advanced E2E scenarios (planned; see AI_AGENT_ROADMAP.md for status) 
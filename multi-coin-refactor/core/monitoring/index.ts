// #region Monitoring & Metrics
/**
 * Real-time monitoring for all nodes, coins, and services.
 * Collects metrics for onboarding, feedback, config, error, and critical events.
 * Pluggable storage (in-memory, file, custom) and alert handler registry.
 * Cross-link to docs/MONITORING.md, core/onboarding/configStore.ts, core/feedback/index.ts.
 * TODO[roadmap]: Integrate with external monitoring tools and add alert handler registry (planned; see AI_AGENT_ROADMAP.md for status)
 */

import * as promClient from 'prom-client';

export interface MetricEvent {
  type: string;
  data: unknown;
  timestamp: string;
}

export interface MetricStorage {
  save(event: MetricEvent): void;
  getAll(): MetricEvent[];
  clear(): void;
}

export class InMemoryMetricStorage implements MetricStorage {
  private metrics: MetricEvent[] = [];
  save(event: MetricEvent) { this.metrics.push(event); }
  getAll() { return this.metrics; }
  clear() { this.metrics = []; }
}

// TODO[roadmap]: Add FileMetricStorage, ExternalMetricStorage, etc. (planned; see AI_AGENT_ROADMAP.md for status)
let storage: MetricStorage = new InMemoryMetricStorage();
export function setMetricStorage(customStorage: MetricStorage) {
  storage = customStorage;
}

// Alert handler registry
export type AlertHandler = (event: MetricEvent) => void;
const alertHandlers: AlertHandler[] = [];
export function registerAlertHandler(handler: AlertHandler) {
  alertHandlers.push(handler);
}

function maybeTriggerAlert(event: MetricEvent) {
  // Trigger alert handlers for error/critical/alert events
  if (["error", "critical", "alert"].includes(event.type)) {
    alertHandlers.forEach(h => h(event));
  }
}

// Create counters for key event types
const onboardingCounter = new promClient.Counter({
  name: 'onboarding_events_total',
  help: 'Total number of onboarding events',
});
const feedbackCounter = new promClient.Counter({
  name: 'feedback_events_total',
  help: 'Total number of feedback events',
});
const errorCounter = new promClient.Counter({
  name: 'error_events_total',
  help: 'Total number of error events',
});
const criticalCounter = new promClient.Counter({
  name: 'critical_events_total',
  help: 'Total number of critical events',
});
const alertCounter = new promClient.Counter({
  name: 'alert_events_total',
  help: 'Total number of alert events',
});
const customCounter = new promClient.Counter({
  name: 'custom_events_total',
  help: 'Total number of custom events',
  labelNames: ['type'],
});

// Export a function to attach /metrics endpoint to an Express app
export function attachPrometheusMetricsEndpoint(app: any) {
  app.get('/metrics', async (_req: any, res: any) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
  });
}

export function recordMetric(event: MetricEvent) {
  storage.save(event);
  maybeTriggerAlert(event);
  // Prometheus metrics export
  switch (event.type) {
    case 'onboarding':
      onboardingCounter.inc();
      break;
    case 'feedback':
      feedbackCounter.inc();
      break;
    case 'error':
      errorCounter.inc();
      break;
    case 'critical':
      criticalCounter.inc();
      break;
    case 'alert':
      alertCounter.inc();
      break;
    default:
      customCounter.inc({ type: event.type });
      break;
  }
  // TODO[roadmap]: Integrate with OpenTelemetry and N|Solid for advanced observability (see AI_AGENT_ROADMAP.md)
}

export function getAllMetrics() {
  return storage.getAll();
}

export function clearAllMetrics() {
  storage.clear();
}
// #endregion 
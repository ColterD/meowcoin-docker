// #region Monitoring & Metrics Guide
/**
 * # Monitoring & Metrics Guide
 * Metrics collection, alerting, and best practices.
 * Cross-link to README.md, SECURITY.md, ONBOARDING.md, feedback, and config store modules.
 * TODO[roadmap]: Expand with onboarding, rollback, and advanced monitoring flows.
 */

## Metrics Collection
- Use core/monitoring/ for metrics interfaces and collection (stubbed).
- Track onboarding, API, feedback, error, critical, rollback, recovery, and security events.
- Advanced: Integrate with external tools (Prometheus, Grafana, etc.).
- See onboarding (core/onboarding/configStore.ts) and feedback (core/feedback/index.ts) modules for event logging examples. Now supports advanced onboarding fields, persistent storage (file/DB-backed, feature-flagged), and pluggable async storage adapters (in-memory, file, DB). See core/types/index.ts for StorageAdapter interface. All onboarding/feedback storage is now async and feature-flagged.

## Alerting
- Set up alerts for errors, failed onboarding, rollback, recovery, and security events.
- Integrate with external monitoring tools as needed (Slack, PagerDuty, email).
- See core/monitoring/index.ts for alerting stubs and alert handler registry.

## Best Practices
- Monitor logs and metrics regularly.
- Review alert thresholds and update as needed.
- Use version control and backup before bulk monitoring edits (see scripts/bulk-edit-examples.md).

## Cross-links
- [README.md](../README.md)
- [SECURITY.md](../SECURITY.md)
- [core/onboarding/configStore.ts](../core/onboarding/configStore.ts)
- [core/feedback/index.ts](../core/feedback/index.ts)
- [scripts/bulk-edit-examples.md](../scripts/bulk-edit-examples.md)

## Pluggable Metric Storage
- Metrics can be stored in-memory (default), file, DB, or custom storage by implementing the MetricStorage interface.
- Use `setMetricStorage(customStorage)` to switch storage at runtime.
- Example:
  ```ts
  import { setMetricStorage } from '../core/monitoring';
  class MyStorage { /* ... */ }
  setMetricStorage(new MyStorage());
  ```

## Alert Handler Registry
- Register alert handlers (callbacks) for error/critical/alert events using `registerAlertHandler(handler)`.
- Handlers receive the MetricEvent and can trigger notifications (Slack, PagerDuty, email, etc.).
- Example:
  ```ts
  import { registerAlertHandler } from '../core/monitoring';
  registerAlertHandler(event => { if (event.type === 'error') sendSlackAlert(event); });
  ```

## Extensible Event Types
- Standard event types: onboarding, feedback, error, critical, rollback, recovery, security, etc.
- Custom event types are supported for future extensibility.

## API Reference
- `recordMetric(event: MetricEvent)` — Record a metric event and trigger alert handlers if needed.
- `getAllMetrics()` — Retrieve all recorded metrics.
- `clearAllMetrics()` — Clear all metrics from storage.
- `setMetricStorage(storage: MetricStorage)` — Set custom metric storage.
- `registerAlertHandler(handler: AlertHandler)` — Register an alert handler callback.

## Usage in Onboarding/Feedback
- Onboarding and feedback modules log events using `recordMetric`.
- See core/onboarding/configStore.ts and core/feedback/index.ts for integration examples.

## Test Coverage
- See test/core/monitoring.test.ts for tests covering pluggable storage, alert handler registry, event extensibility, and clearing metrics.
- Prometheus metrics export is fully tested: all event counters (onboarding, feedback, error, critical, alert, custom) and the /metrics endpoint are covered.
- All tests pass and are production-ready. See [AI_AGENT_ROADMAP.md](../AI_AGENT_ROADMAP.md) for test results and next steps (OpenTelemetry integration).

## Prometheus Integration
- Metrics are exported using [prom-client](https://github.com/siimon/prom-client) and exposed at `/metrics` (Prometheus scrape endpoint).
- Event counters:
  - `onboarding_events_total`: Total onboarding events
  - `feedback_events_total`: Total feedback events
  - `error_events_total`: Total error events
  - `critical_events_total`: Total critical events
  - `alert_events_total`: Total alert events
  - `custom_events_total{type="..."}`: Total custom event types
- To enable, call `attachPrometheusMetricsEndpoint(app)` in your Express app (see `core/monitoring/index.ts`).
- Example:
  ```ts
  import express from 'express';
  import { attachPrometheusMetricsEndpoint } from './core/monitoring';
  const app = express();
  attachPrometheusMetricsEndpoint(app);
  app.listen(3000);
  // Prometheus metrics now available at http://localhost:3000/metrics
  ```
- All metrics are updated automatically when `recordMetric` is called.
- See [AI_AGENT_ROADMAP.md](../AI_AGENT_ROADMAP.md) for roadmap and next steps (OpenTelemetry, N|Solid integration planned).

## OpenTelemetry Integration Plan (2025)
- Auto-instrumentation with @opentelemetry/sdk-node and @opentelemetry/auto-instrumentations-node, initialized at the entry point (tracing.ts).
- Configure OTLP exporter for traces (default to local collector, support remote backends).
- Add manual instrumentation for business-critical logic in core and coin modules.
- Deploy OpenTelemetry Collector (agent pattern for dev, hierarchical for prod) for batching, buffering, and preprocessing.
- Correlate traces, metrics, and logs; ensure context propagation.
- Optimize with batching, compression, and smart sampling.
- See [AI_AGENT_ROADMAP.md](../AI_AGENT_ROADMAP.md) for Change Log and Next Steps.
- Reference: [OpenTelemetry Best Practices 2025](https://betterstack.com/community/guides/observability/opentelemetry-best-practices/)

// #endregion 

// #region Documentation Index
// TODO[roadmap]: Add OpenAPI/Swagger integration, DB-backed storage, advanced E2E, and region folding best practices
// #endregion 
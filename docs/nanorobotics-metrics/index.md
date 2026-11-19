# Nanorobotics Metrics & Observability

## Purpose
Expose Prometheus-compatible metrics for guard enforcement, schedule evaluation, budget utilization, and ALN manifest validation.

## Metric Families
| Metric Name | Type | Description |
|-------------|------|-------------|
| `guard_evaluations_total` | Counter | Total guard checks by layer and outcome |
| `guard_blocks_total` | Counter | Blocked operations by reason and host |
| `thermal_delta_celsius` | Gauge | Real-time brain/core/skin temperature deltas |
| `duty_cycle_utilization` | Gauge | Current rolling-window duty fraction |
| `energy_budget_utilization` | Gauge | Fraction of daily joule budget consumed |
| `residual_risk_vt` | Gauge | Current aggregated quadratic risk score |
| `evidence_validation_failed_total` | Counter | Evidence bundle validation failures |
| `guard_evaluation_latency_seconds` | Histogram | Guard evaluation duration distribution |

## Integration Requirements
- All metrics must include `host_did` label for multi-tenant isolation.
- Gauges update synchronously with scheduler/guard state transitions.
- Histograms use standard Prometheus buckets: `[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]`.
- CI pipelines scrape `/metrics` endpoint to enforce SLOs before manifest acceptance.

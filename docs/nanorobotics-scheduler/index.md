# Nanorobotics Scheduler Documentation

This directory defines the scheduling primitives for duty-cycle, thermal, and energy-aware nanoswarm orchestration.

## Core Components
- `DutyScheduler`: Enforces continuous duty limits, cooldown periods, and rolling-window duty fractions.
- `ThermalGuard`: Validates brain, core, and skin temperature deltas against thermodynamic envelopes.
- `EnergyAllocator`: Manages daily joule budgets, peak power draw, and mission prioritization.
- `SwarmScheduler`: Unifies components into a single evaluation pipeline with allow/defer/deny semantics.

## Scheduling Invariants
- Duty fraction never exceeds `max_duty_fraction` over rolling windows.
- Temperature deltas remain within `safe_max` corridors; hard stops trigger immediate defer/deny.
- Energy allocation respects `min_reserve_joules` and daily caps.
- All decisions are deterministic, auditable, and reversible only through explicit consent pathways.

## Integration Notes
The scheduler consumes `HostBudget` parameters and returns structured `ScheduleDecision` enums. It does not bypass guard layers or safety invariants.

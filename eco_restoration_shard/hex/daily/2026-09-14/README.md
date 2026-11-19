# Cyboquatic Daily Artifact Set — 2026-09-14

Domain: (d) Cyboquatic workload telemetry (`energyreqJ`, `ΔVt`).

Date-derived sub-task: conservative, operator-reviewed workload admission for
canal, drain, wetland-inlet, and retention-basin restoration machinery using
bounded energy demand, terminal-voltage sag, KER governance values, FOG media
classification, and Canal-node limits.

Hash method:
sum(ordinal(character) × one-based-position) for "2026-09-14", modulo 7.
The resulting zero-based index is 3, selecting domain (d).

Files:
- workload_policy.aln
- schema.sql
- CyboquaticWorkload.cpp
- CyboquaticWorkload.java
- CyboquaticWorkload.kt
- fog_task_router.lua

Build and run:
- SQLite: sqlite3 cyboquatic_workload.db < schema.sql
- C++: c++ -std=c++20 -O2 -Wall -Wextra -Wpedantic CyboquaticWorkload.cpp -o cyboquatic-workload
- Java: javac CyboquaticWorkload.java
- Kotlin: kotlinc CyboquaticWorkload.kt -include-runtime -d cyboquatic-workload.jar
- Lua: lua fog_task_router.lua input.csv

CSV columns:
workload_id,canal_node_id,task_type,mass_kg,distance_m,duty_seconds,
rated_power_w,motor_efficiency,baseline_voltage_v,internal_resistance_ohm,
battery_soc,renewable_fraction,media_class

task_type:
debris_skim, sediment_dredge, biofilm_scrub, aerator_drive

media_class:
known_safe, unmodeled_media, pfas_suspected, hazardous_material, unknown

All fractional values must be in the closed interval 0–1. The artifacts provide
decision support and database validation only. They do not autonomously start,
stop, steer, calibrate, or otherwise control physical machinery. Operator
authorization and site-specific environmental procedures remain required.

#!/usr/bin/env python3
"""
Periphyton/PFAS Integration Report Generator

This script validates the integration milestone by:
1. Loading and executing SQLite schema and integration test scripts
2. Validating JSON fixtures with structural checks
3. Querying the evidence database for summary statistics
4. Checking ESS governance isolation constraints
5. Producing a Markdown report

All values in fixtures are synthetic integration-test data.
No physical sensors, samples, field operations, or external systems are controlled.
"""

import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def get_default_paths():
    """Return default repository-relative paths."""
    repo_root = Path(__file__).parent.parent
    return {
        "repo_root": repo_root,
        "schema_evidence_registry": repo_root / "schemas/sql/periphyton_evidence_registry.sql",
        "schema_recovery_history": repo_root / "schemas/sql/biofilm_recovery_state_history.sql",
        "integration_evidence": repo_root / "tests/sql/periphyton_evidence_registry_integration.sql",
        "integration_recovery": repo_root / "tests/sql/biofilm_recovery_state_history_integration.sql",
        "fixtures_dir": repo_root / "tests/fixtures",
        "output_path": repo_root / "docs/periphyton-integration-milestone-report.md"
    }


def load_sql_script(path):
    """Load SQL script from file."""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def execute_sql_scripts(db_conn, scripts):
    """Execute a list of SQL scripts in order."""
    results = []
    for script_path, script_name in scripts:
        if not script_path.exists():
            results.append((script_name, False, f"File not found: {script_path}"))
            continue
        try:
            sql = load_sql_script(script_path)
            db_conn.executescript(sql)
            results.append((script_name, True, "OK"))
        except Exception as e:
            results.append((script_name, False, str(e)))
    return results


def validate_json_fixture(fixture_path):
    """Validate a JSON fixture with structural checks."""
    required_top_keys = [
        "packet_id", "packet_version", "hex_anchor_id", "corridor_segment_label",
        "event_window", "calibration_status", "provenance_status", "energyreq_j",
        "wall_shear_pa", "conservative_detachment_threshold_pa", "detachment_mode",
        "external_action_requested", "pfas_evidence", "maintenance_scenario"
    ]
    
    valid_pfas_statuses = {"DETECTED", "INDETERMINATE", "NOT_DETECTED"}
    valid_maintenance_statuses = {"MODELED", "NOT_MODELED"}
    
    errors = []
    
    try:
        with open(fixture_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return False, [f"JSON parse error: {e}"]
    except FileNotFoundError:
        return False, [f"File not found: {fixture_path}"]
    
    # Check required top-level keys
    for key in required_top_keys:
        if key not in data:
            errors.append(f"Missing required key: {key}")
    
    # Check packet_version
    if data.get("packet_version") != "1.0":
        errors.append(f"packet_version must be '1.0', got: {data.get('packet_version')}")
    
    # Check event_window structure
    event_window = data.get("event_window", {})
    if not isinstance(event_window, dict):
        errors.append("event_window must be an object")
    else:
        for ew_key in ["event_window_id", "start_utc", "end_utc"]:
            if ew_key not in event_window:
                errors.append(f"event_window missing required key: {ew_key}")
    
    # Check numeric constraints
    energyreq_j = data.get("energyreq_j")
    if energyreq_j is not None and (not isinstance(energyreq_j, (int, float)) or energyreq_j < 0):
        errors.append(f"energyreq_j must be >= 0, got: {energyreq_j}")
    
    wall_shear_pa = data.get("wall_shear_pa")
    if wall_shear_pa is not None and (not isinstance(wall_shear_pa, (int, float)) or wall_shear_pa < 0):
        errors.append(f"wall_shear_pa must be >= 0, got: {wall_shear_pa}")
    
    conservative_detachment_threshold_pa = data.get("conservative_detachment_threshold_pa")
    if conservative_detachment_threshold_pa is not None and (not isinstance(conservative_detachment_threshold_pa, (int, float)) or conservative_detachment_threshold_pa <= 0):
        errors.append(f"conservative_detachment_threshold_pa must be > 0, got: {conservative_detachment_threshold_pa}")
    
    # Check external_action_requested is boolean
    external_action = data.get("external_action_requested")
    if not isinstance(external_action, bool):
        errors.append(f"external_action_requested must be boolean, got: {type(external_action).__name__}")
    
    # Check pfas_evidence status
    pfas_evidence = data.get("pfas_evidence", {})
    if isinstance(pfas_evidence, dict):
        pfas_status = pfas_evidence.get("status")
        if pfas_status and pfas_status not in valid_pfas_statuses:
            errors.append(f"pfas_evidence.status must be one of {valid_pfas_statuses}, got: {pfas_status}")
    
    # Check maintenance_scenario status
    maintenance = data.get("maintenance_scenario", {})
    if isinstance(maintenance, dict):
        maint_status = maintenance.get("status")
        if maint_status and maint_status not in valid_maintenance_statuses:
            errors.append(f"maintenance_scenario.status must be one of {valid_maintenance_statuses}, got: {maint_status}")
    
    return len(errors) == 0, errors


def query_database_summary(db_conn):
    """Query the database for summary statistics."""
    summary = {}
    
    try:
        # Evidence packets by result_state
        cursor = db_conn.execute(
            "SELECT result_state, COUNT(*) FROM evidence_packet GROUP BY result_state ORDER BY result_state"
        )
        summary["evidence_packets_by_state"] = cursor.fetchall()
    except Exception as e:
        summary["evidence_packets_by_state"] = [("ERROR", str(e))]
    
    try:
        # Censoring status counts
        cursor = db_conn.execute(
            "SELECT censoring_status, COUNT(*) FROM evidence_packet GROUP BY censoring_status ORDER BY censoring_status"
        )
        summary["censoring_status_counts"] = cursor.fetchall()
    except Exception as e:
        summary["censoring_status_counts"] = [("ERROR", str(e))]
    
    try:
        # Contradiction status counts
        cursor = db_conn.execute(
            "SELECT contradiction_status, COUNT(*) FROM evidence_contradiction GROUP BY contradiction_status ORDER BY contradiction_status"
        )
        summary["contradiction_status_counts"] = cursor.fetchall()
    except Exception as e:
        summary["contradiction_status_counts"] = [("ERROR", str(e))]
    
    try:
        # Evidence sufficiency records
        cursor = db_conn.execute(
            "SELECT evidence_packet_id, namespace, ess FROM evidence_sufficiency"
        )
        summary["evidence_sufficiency_records"] = cursor.fetchall()
    except Exception as e:
        summary["evidence_sufficiency_records"] = [("ERROR", str(e))]
    
    try:
        # Recovery observations by state_name
        cursor = db_conn.execute(
            "SELECT state_name, COUNT(*) FROM recovery_observation GROUP BY state_name ORDER BY state_name"
        )
        summary["recovery_observations_by_state"] = cursor.fetchall()
    except Exception as e:
        summary["recovery_observations_by_state"] = [("ERROR", str(e))]
    
    return summary


def check_ess_isolation(db_conn):
    """Check ESS governance isolation constraints."""
    violations = []
    
    try:
        # Check for namespace other than INTERNAL_RESEARCH_QUALITY
        cursor = db_conn.execute(
            "SELECT evidence_packet_id, namespace FROM evidence_sufficiency WHERE namespace != 'INTERNAL_RESEARCH_QUALITY'"
        )
        rows = cursor.fetchall()
        if rows:
            for row in rows:
                violations.append(f"Invalid namespace: {row[0]} has namespace '{row[1]}'")
    except Exception as e:
        violations.append(f"Namespace check error: {e}")
    
    try:
        # Check for used_for_access_control = TRUE
        cursor = db_conn.execute(
            "SELECT evidence_packet_id FROM evidence_sufficiency WHERE used_for_access_control = TRUE"
        )
        rows = cursor.fetchall()
        if rows:
            violations.append(f"used_for_access_control violated by: {[r[0] for r in rows]}")
    except Exception as e:
        violations.append(f"Access control check error: {e}")
    
    try:
        # Check for used_for_identity_or_eligibility = TRUE
        cursor = db_conn.execute(
            "SELECT evidence_packet_id FROM evidence_sufficiency WHERE used_for_identity_or_eligibility = TRUE"
        )
        rows = cursor.fetchall()
        if rows:
            violations.append(f"used_for_identity_or_eligibility violated by: {[r[0] for r in rows]}")
    except Exception as e:
        violations.append(f"Identity eligibility check error: {e}")
    
    try:
        # Check for used_for_public_ranking = TRUE
        cursor = db_conn.execute(
            "SELECT evidence_packet_id FROM evidence_sufficiency WHERE used_for_public_ranking = TRUE"
        )
        rows = cursor.fetchall()
        if rows:
            violations.append(f"used_for_public_ranking violated by: {[r[0] for r in rows]}")
    except Exception as e:
        violations.append(f"Public ranking check error: {e}")
    
    try:
        # Check for used_for_external_action_authorization = TRUE
        cursor = db_conn.execute(
            "SELECT evidence_packet_id FROM evidence_sufficiency WHERE used_for_external_action_authorization = TRUE"
        )
        rows = cursor.fetchall()
        if rows:
            violations.append(f"used_for_external_action_authorization violated by: {[r[0] for r in rows]}")
    except Exception as e:
        violations.append(f"External action authorization check error: {e}")
    
    return violations


def generate_report(schema_results, fixture_results, db_summary, ess_violations, files_checked, output_path):
    """Generate the Markdown integration report."""
    all_schema_passed = all(r[1] for r in schema_results)
    all_fixtures_passed = all(r[0] for r in fixture_results)
    ess_passed = len(ess_violations) == 0
    
    overall_pass = all_schema_passed and all_fixtures_passed and ess_passed
    
    lines = [
        "# Periphyton/PFAS Integration Milestone Report",
        "",
        "**Generated by:** `python/periphyton_integration_report.py`",
        "",
        "---",
        "",
        "## Statement on Synthetic Data",
        "",
        "**All values in fixtures are synthetic integration-test data.**",
        "",
        "This report documents a local, non-actuating integration harness.",
        "No physical sensors, samples, field operations, or external systems were controlled.",
        "",
        "---",
        "",
        "## Schema Execution Status",
        "",
        "| Script | Status | Details |",
        "|--------|--------|---------|"
    ]
    
    for name, passed, details in schema_results:
        status = "PASS" if passed else "FAIL"
        lines.append(f"| {name} | {status} | {details} |")
    
    lines.extend([
        "",
        "## Fixture Validation Status",
        "",
        "| Fixture | Status | Details |",
        "|---------|--------|---------|"
    ])
    
    for fixture_path, passed, errors in fixture_results:
        status = "PASS" if passed else "FAIL"
        details = "; ".join(errors) if errors else "OK"
        lines.append(f"| {fixture_path.name} | {status} | {details} |")
    
    lines.extend([
        "",
        "## Database Summary",
        "",
        "### Evidence Packets by Result State",
        "",
        "| State | Count |",
        "|-------|-------|"
    ])
    
    for state, count in db_summary.get("evidence_packets_by_state", []):
        lines.append(f"| {state} | {count} |")
    
    lines.extend([
        "",
        "### Censoring Status Counts",
        "",
        "| Status | Count |",
        "|--------|-------|"
    ])
    
    for status, count in db_summary.get("censoring_status_counts", []):
        lines.append(f"| {status} | {count} |")
    
    lines.extend([
        "",
        "### Contradiction Status Counts",
        "",
        "| Status | Count |",
        "|--------|-------|"
    ])
    
    for status, count in db_summary.get("contradiction_status_counts", []):
        lines.append(f"| {status} | {count} |")
    
    lines.extend([
        "",
        "### Evidence Sufficiency Records",
        "",
        "| Packet ID | Namespace | ESS |",
        "|-----------|-----------|-----|"
    ])
    
    for packet_id, namespace, ess in db_summary.get("evidence_sufficiency_records", []):
        lines.append(f"| {packet_id} | {namespace} | {ess} |")
    
    lines.extend([
        "",
        "### Recovery Observations by State",
        "",
        "| State | Count |",
        "|-------|-------|"
    ])
    
    for state, count in db_summary.get("recovery_observations_by_state", []):
        lines.append(f"| {state} | {count} |")
    
    lines.extend([
        "",
        "## ESS Isolation Result",
        "",
        f"**Status:** {'PASS' if ess_passed else 'FAIL'}",
        ""
    ])
    
    if ess_violations:
        lines.append("**Violations:**")
        lines.append("")
        for v in ess_violations:
            lines.append(f"- {v}")
        lines.append("")
    else:
        lines.append("No ESS governance isolation violations detected.")
        lines.append("")
        lines.append("- All evidence_sufficiency records use namespace `INTERNAL_RESEARCH_QUALITY`")
        lines.append("- No `used_for_access_control` flags are true")
        lines.append("- No `used_for_identity_or_eligibility` flags are true")
        lines.append("- No `used_for_public_ranking` flags are true")
        lines.append("- No `used_for_external_action_authorization` flags are true")
    
    lines.extend([
        "",
        "## Files Checked",
        ""
    ])
    
    for f in files_checked:
        lines.append(f"- `{f}`")
    
    lines.extend([
        "",
        "## Limitations",
        "",
        "- ALN policy files were not executed by this Python script",
        "- Fixtures are synthetic and do not represent real field data",
        "- This is an integration harness, not laboratory, field, regulatory, or operational validation",
        "- JSON checks are structural integration checks, not full JSON Schema validation",
        "- No sensor actuation, canal action, or external system control was performed",
        "- No personal identity data, exact field coordinates, or governance credentials are included",
        "",
        "---",
        "",
        f"## Final Status: {'PASS' if overall_pass else 'FAIL'}",
        ""
    ])
    
    report_content = "\n".join(lines)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(report_content)
    
    return overall_pass


def main():
    paths = get_default_paths()
    
    # Allow command-line overrides
    if len(sys.argv) > 1:
        paths["repo_root"] = Path(sys.argv[1])
    if len(sys.argv) > 2:
        db_path_arg = Path(sys.argv[2])
    else:
        db_path_arg = None
    if len(sys.argv) > 3:
        paths["fixtures_dir"] = Path(sys.argv[3])
    if len(sys.argv) > 4:
        paths["output_path"] = Path(sys.argv[4])
    
    files_checked = []
    
    # Create temporary database
    tmp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
    tmp_db_path = tmp_db.name
    tmp_db.close()
    
    try:
        db_conn = sqlite3.connect(tmp_db_path)
        db_conn.execute("PRAGMA foreign_keys = ON;")
        
        # Execute schema and integration scripts
        schema_scripts = [
            (paths["schema_evidence_registry"], "periphyton_evidence_registry.sql"),
            (paths["schema_recovery_history"], "biofilm_recovery_state_history.sql"),
            (paths["integration_evidence"], "periphyton_evidence_registry_integration.sql"),
            (paths["integration_recovery"], "biofilm_recovery_state_history_integration.sql")
        ]
        
        schema_results = execute_sql_scripts(db_conn, schema_scripts)
        
        for s, _ in schema_scripts:
            files_checked.append(str(s))
        
        # Validate JSON fixtures
        fixture_files = [
            paths["fixtures_dir"] / "periphyton_pfas_decision_packet.valid.json",
            paths["fixtures_dir"] / "periphyton_pfas_decision_packet.invalid_external_action.json",
            paths["fixtures_dir"] / "periphyton_pfas_decision_packet.inconclusive.json"
        ]
        
        fixture_results = []
        for fixture_path in fixture_files:
            passed, errors = validate_json_fixture(fixture_path)
            fixture_results.append((fixture_path, passed, errors))
            files_checked.append(str(fixture_path))
        
        # Query database summary
        db_summary = query_database_summary(db_conn)
        
        # Check ESS isolation
        ess_violations = check_ess_isolation(db_conn)
        
        # Generate report
        overall_pass = generate_report(
            schema_results,
            fixture_results,
            db_summary,
            ess_violations,
            files_checked,
            paths["output_path"]
        )
        
        print(f"Report generated: {paths['output_path']}")
        print(f"Final Status: {'PASS' if overall_pass else 'FAIL'}")
        
        db_conn.close()
        
        return 0 if overall_pass else 1
        
    finally:
        # Clean up temporary database
        if os.path.exists(tmp_db_path):
            os.unlink(tmp_db_path)


if __name__ == "__main__":
    sys.exit(main())

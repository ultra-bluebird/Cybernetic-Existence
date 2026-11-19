"""Synthetic SQL dependency-review exercise.

Python 3.10 or newer; standard library sqlite3 only.

Uses an empty in-memory fictional schema and EXPLAIN QUERY PLAN.
Does not connect to production data or execute query result processing.

This is dependency triage, not a complete SQL privacy analyzer.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import sqlite3


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


def inspect_synthetic_query(sql):
    if type(sql) is not str or not sql.strip() or len(sql) > 20_000:
        raise ValueError("bounded_sql_text_required")

    connection = sqlite3.connect(":memory:")

    connection.executescript(
        """
        CREATE TABLE environment_samples(
            zone TEXT,
            window_label TEXT,
            indicator REAL
        );

        CREATE TABLE visit_patterns(
            zone TEXT,
            window_label TEXT,
            pattern_label TEXT
        );
        """
    )

    reads = set()
    blocked = []

    def authorize(action, first, second, database, trigger):
        if action == sqlite3.SQLITE_SELECT:
            return sqlite3.SQLITE_OK

        if action == sqlite3.SQLITE_READ:
            if first not in {"environment_samples", "visit_patterns"}:
                blocked.append("table_outside_synthetic_schema")
                return sqlite3.SQLITE_DENY

            reads.add((first, second or "*"))
            return sqlite3.SQLITE_OK

        if (
            action == sqlite3.SQLITE_FUNCTION
            and (second or "").lower()
            in {"count", "avg", "min", "max", "sum"}
        ):
            return sqlite3.SQLITE_OK

        blocked.append("operation_or_function_not_allowed")
        return sqlite3.SQLITE_DENY

    connection.set_authorizer(authorize)

    try:
        connection.execute(
            "EXPLAIN QUERY PLAN " + sql
        ).fetchall()
        compiled = True
    except sqlite3.Error:
        compiled = False
    finally:
        connection.close()

    review_inputs = {
        ("environment_samples", "zone"),
        ("environment_samples", "window_label"),
        ("visit_patterns", "zone"),
        ("visit_patterns", "window_label"),
    }

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "compile_result": (
            "compiled" if compiled else "rejected_or_unsupported"
        ),
        "source_fields": sorted(reads),
        "joint_location_window_review_trigger": (
            compiled and review_inputs <= reads
        ),
        "blocked_categories": sorted(set(blocked)),
        "scope": "empty synthetic schema only",
        "query_execution": "not_performed_against_data",
        "prohibited_inference": "not_determined",
        "production_pipeline_coverage": "not_established",
    }

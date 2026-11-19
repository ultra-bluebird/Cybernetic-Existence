"""Synthetic mixed-level planning example; no runtime injection.

Python 3.10 or newer.
SPDX-License-Identifier: MIT OR Apache-2.0
"""

from research.assurance.structured_campaign import (
    Coverage,
    Factor,
    Model,
    verify_reproduction,
)


def build_example():
    model = Model(
        version="mixed-example-1",
        factors=(
            Factor(
                name="clock",
                values=("available", "missing"),
                baseline="available",
            ),
            Factor(
                name="reading",
                values=("not_injected", "future", "stale"),
                baseline="not_injected",
                must_cover_values=("future",),
                applies_when=(("clock", "available"),),
                evidence_class="integration",
            ),
            Factor(
                name="network",
                values=("not_injected", "offline"),
                baseline="not_injected",
            ),
        ),
        forbidden=(
            (
                ("reading", "future"),
                ("network", "offline"),
            ),
        ),
        max_active=2,
    )

    coverage = Coverage(
        version="nested-example-1",
        strength=3,
    )

    return verify_reproduction(model, coverage)

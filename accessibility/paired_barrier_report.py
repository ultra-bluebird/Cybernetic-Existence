"""Paired barrier outcomes for one primary task pair per study unit.

Python 3.10 or newer; standard library only.

Pairs are (emulation, semantic), with 1=barrier, 0=no barrier,
and None=unknown. No participant identifiers are required.

The caller must establish the study design and independence assumptions.
No application, game, adapter, or anti-cheat system is operated.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


def paired_barriers(pairs):
    if type(pairs) is not tuple or len(pairs) > 10000:
        raise ValueError("bounded_pair_tuple_required")

    both_clear = emulation_only = semantic_only = both_barrier = 0
    difference_lower = difference_upper = 0

    for pair in pairs:
        if (
            type(pair) is not tuple
            or len(pair) != 2
            or any(
                value is not None
                and (type(value) is not int or value not in (0, 1))
                for value in pair
            )
        ):
            raise ValueError("binary_or_unknown_pair_required")

        emulation, semantic = pair
        possible_e = (0, 1) if emulation is None else (emulation,)
        possible_s = (0, 1) if semantic is None else (semantic,)

        differences = [
            s - e for e in possible_e for s in possible_s
        ]
        difference_lower += min(differences)
        difference_upper += max(differences)

        if emulation is None or semantic is None:
            continue

        if pair == (0, 0):
            both_clear += 1
        elif pair == (1, 0):
            emulation_only += 1
        elif pair == (0, 1):
            semantic_only += 1
        else:
            both_barrier += 1

    complete = (
        both_clear + emulation_only + semantic_only + both_barrier
    )
    discordant = emulation_only + semantic_only

    p_value = None
    p_status = "undefined_no_complete_pairs"

    if complete > 0 and discordant == 0:
        p_value = 1.0
        p_status = "calculated"
    elif 0 < discordant <= 1000:
        term = 1
        tail = 1

        for k in range(1, min(emulation_only, semantic_only) + 1):
            term = term * (discordant - k + 1) // k
            tail += term

        p_value = min(1.0, (2 * tail) / (1 << discordant))
        p_status = "calculated"
    elif discordant > 1000:
        p_status = "not_calculated_discordance_limit"

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "assigned_pairs": len(pairs),
        "complete_pairs": complete,
        "both_no_barrier": both_clear,
        "emulation_only_barrier": emulation_only,
        "semantic_only_barrier": semantic_only,
        "both_barrier": both_barrier,
        "complete_pair_difference": (
            None if complete == 0
            else (semantic_only - emulation_only) / complete
        ),
        "complete_pair_emulation_rate": (
            None if complete == 0
            else (emulation_only + both_barrier) / complete
        ),
        "complete_pair_semantic_rate": (
            None if complete == 0
            else (semantic_only + both_barrier) / complete
        ),
        "cohort_missing_outcome_bounds": (
            None if not pairs
            else [
                difference_lower / len(pairs),
                difference_upper / len(pairs),
            ]
        ),
        "mcnemar_exact_two_sided_p": p_value,
        "p_value_status": p_status,
        "effect_confidence_interval": "not_calculated",
        "study_validity": "not_evaluated",
    }

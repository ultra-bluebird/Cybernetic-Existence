"""Plain-text wording for scope-review vocabulary 1.0.0.

Python 3.10 or newer; standard library only.
No HTML generation, publication, or external action.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

MESSAGES = {
    "within_declared_envelope":
        "The proposal is within the supplied reviewed scope model.",
    "review_required_beyond_bounds":
        "A reviewed bound or condition is exceeded. Fresh review is required.",
    "review_required_renewal":
        "The supplied authorization-period status is expired. Renewal review is required.",
    "unknown_unresolved_evidence":
        "Required scope or dependency evidence remains unresolved.",
}

QUALIFIER = (
    "This is a record-scope assessment, not a guarantee about bodily "
    "irreversibility. It does not authorize future activities. "
    "You may request changes, explanation, or correction."
)


def render_scope_result(result):
    if type(result) is not dict:
        raise TypeError("scope_result_required")
    if result.get("schema_version") != "1.0.0":
        raise ValueError("unsupported_result_schema")
    if result.get("outcome_vocabulary_version") != "1.0.0":
        raise ValueError("unsupported_outcome_vocabulary")

    outcome = result.get("outcome")
    if type(outcome) is not str or outcome not in MESSAGES:
        raise ValueError("unsupported_scope_outcome")

    return MESSAGES[outcome] + "\n\n" + QUALIFIER

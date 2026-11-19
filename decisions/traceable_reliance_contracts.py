"""Research-only contracts for uncertainty, scale, and decision reliance.

Dependency:
    python -m pip install jsonschema

Run:
    python research/decisions/traceable_reliance_contracts.py

No signing, networking, persistence, or external actions.
References are controlled document paths and revisions, not public registries.
"""

from copy import deepcopy
import unittest

from jsonschema import Draft202012Validator


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def text():
    return {"type": "string", "minLength": 1, "pattern": r"\S"}


def choices(*values):
    return {"type": "string", "enum": list(values)}


def sequence(items, minimum=0):
    return {"type": "array", "minItems": minimum, "items": items}


def record(properties):
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties),
        "properties": properties,
    }


def reference():
    return record({
        "document_path": text(),
        "revision": text(),
        "named_passage": text(),
    })


def evidence_collection():
    return {
        "oneOf": [
            record({
                "state": {"const": "not_assessed"},
                "items": {"type": "array", "maxItems": 0},
            }),
            record({
                "state": {"const": "none_recorded"},
                "items": {"type": "array", "maxItems": 0},
                "assessment_basis": text(),
            }),
            record({
                "state": {"const": "recorded"},
                "items": sequence(reference(), 1),
            }),
        ]
    }


def envelope(version, properties):
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        **record({
            "contract_version": {"const": version},
            "revision": text(),
            "attribution": {"const": ATTRIBUTION},
            **properties,
        }),
    }


CATEGORIES = (
    "observation",
    "disputed_observation",
    "interpretation",
    "normative_assumption",
    "missing_information",
    "alternative_explanation",
)

EVIDENCE_CLASSES = (
    "direct_evidence",
    "authority_basis",
    "reviewed_interpretation",
    "aggregate_diagnostic",
)

CONCLUSIONS = (
    "standing",
    "restriction",
    "appeal_disposition",
    "reasoning",
)

UNCERTAINTY_SCHEMA = envelope(
    "uncertainty-research-v2",
    {
        "scope": reference(),
        "entries": sequence(record({
            "name": text(),
            "proposition": text(),
            "categories": {
                **sequence(choices(*CATEGORIES), 1),
                "uniqueItems": True,
            },
            "decision_dimensions": {
                **sequence(choices(
                    "change_trigger",
                    "waiting_consequence",
                    "irreversibility",
                    "other_declared_concern",
                )),
                "uniqueItems": True,
            },
            "lifecycle": choices(
                "draft", "active", "contested", "superseded", "retired"
            ),
            "support": evidence_collection(),
            "counterevidence": evidence_collection(),
            "remaining_uncertainty": text(),
            "origin_findings": sequence(reference()),
            "dependent_decisions": sequence(reference()),
            "change_triggers": sequence(record({
                "event_class": text(),
                "applicability_rule": reference(),
                "required_response": text(),
            })),
            "review": record({
                "timing_class": choices(
                    "immediate", "scheduled", "on_trigger",
                    "unspecified", "not_applicable",
                ),
                "timing_policy": reference(),
                "responsible_role": text(),
            }),
            "provenance": record({
                "author_role": text(),
                "authorship_record": reference(),
                "source_basis": text(),
                "conflict_assessment": reference(),
            }),
            "disclosure": record({
                "classification": choices(
                    "public_reviewed",
                    "restricted_governance",
                    "confidential_case",
                ),
                "reason": text(),
                "review_policy": reference(),
            }),
            "supersedes": sequence(reference()),
            "challenge_route": reference(),
            "notification_policy": reference(),
        }), 1),
        "limitations": sequence(text(), 1),
        "retention_policy": reference(),
    },
)

USE_POLICY_SCHEMA = envelope(
    "prohibited-use-research-v1",
    {
        "protected_conclusions": {
            **sequence(choices(*CONCLUSIONS), 1),
            "uniqueItems": True,
        },
        "required_nonaggregate_support": {"const": True},
        "worth_ranking": {"const": "not_supported"},
        "authority_approval": reference(),
        "challenge_route": reference(),
    },
)

SCALE_SCHEMA = envelope(
    "scale-declaration-research-v1",
    {
        "dimensions": sequence(record({
            "name": text(),
            "unit": text(),
            "interpretation": text(),
            "conversion_basis": reference(),
        }), 1),
        "common_loss_unit": text(),
        "valid_scope": reference(),
        "valid_range": text(),
        "accepted_transformations": sequence(text(), 1),
        "uncertainty_and_sensitivity": text(),
        "review_status": choices("pending", "accepted", "withdrawn"),
        "review_record": reference(),
        "effective_period_policy": reference(),
        "challenge_route": reference(),
        "disclosure_policy": reference(),
    },
)

RECEIPT_SCHEMA = envelope(
    "decision-receipt-research-v1",
    {
        "scope": reference(),
        "use_policy": reference(),
        "uncertainty_entries": sequence(reference()),
        "alternatives": sequence(record({
            "name": text(),
            "disposition": choices("considered", "excluded"),
            "reason": text(),
        }), 1),
        "method": choices(
            "qualitative",
            "dominance",
            "minimax_regret",
            "other_declared_method",
        ),
        "scale": {
            "oneOf": [reference(), {"type": "null"}]
        },
        "comparison_artifact": {
            "oneOf": [reference(), {"type": "null"}]
        },
        "conclusions": sequence(record({
            "kind": choices(*CONCLUSIONS),
            "statement": text(),
            "reasons": sequence(text(), 1),
            "support": sequence(record({
                "evidence_class": choices(*EVIDENCE_CLASSES),
                "source": reference(),
                "relevance_explanation": text(),
            }), 1),
        }), 1),
        "unreviewed_assumptions": sequence(text()),
        "review_policy": reference(),
        "challenge_route": reference(),
        "notification_policy": reference(),
    },
)


def validate_structure(schema, value):
    """Return validation errors without echoing confidential instance values."""
    errors = sorted(
        Draft202012Validator(schema).iter_errors(value),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    return tuple(
        {
            "path": tuple(error.absolute_path),
            "keyword": error.validator,
        }
        for error in errors
    )


def check_reliance(receipt, use_policy, resolved_scale=None):
    """Assess declared relationships, not evidence truth or legal authority."""
    structural = (
        validate_structure(RECEIPT_SCHEMA, receipt)
        + validate_structure(USE_POLICY_SCHEMA, use_policy)
    )
    if structural:
        return ("structural_validation_failed",)

    problems = []
    protected = set(use_policy["protected_conclusions"])

    for conclusion in receipt["conclusions"]:
        if conclusion["kind"] in protected:
            classes = {
                item["evidence_class"]
                for item in conclusion["support"]
            }
            if classes <= {"aggregate_diagnostic"}:
                problems.append("aggregate_diagnostic_is_sole_support")

    if receipt["method"] == "minimax_regret":
        if receipt["scale"] is None:
            problems.append("scale_reference_required")
        if receipt["comparison_artifact"] is None:
            problems.append("comparison_artifact_required")
        if resolved_scale is None:
            problems.append("scale_resolution_required")
        elif validate_structure(SCALE_SCHEMA, resolved_scale):
            problems.append("scale_structure_invalid")
        elif resolved_scale["review_status"] != "accepted":
            problems.append("scale_not_accepted")

    return tuple(problems)


def synthetic_reference(passage="synthetic passage"):
    return {
        "document_path": "research/fixtures/synthetic-record.md",
        "revision": "synthetic-revision",
        "named_passage": passage,
    }


def synthetic_receipt():
    return {
        "contract_version": "decision-receipt-research-v1",
        "revision": "synthetic-revision",
        "attribution": ATTRIBUTION,
        "scope": synthetic_reference(),
        "use_policy": synthetic_reference("synthetic use policy"),
        "uncertainty_entries": [],
        "alternatives": [{
            "name": "synthetic bounded review",
            "disposition": "considered",
            "reason": "Synthetic fixture only.",
        }],
        "method": "qualitative",
        "scale": None,
        "comparison_artifact": None,
        "conclusions": [{
            "kind": "restriction",
            "statement": "Synthetic proposed restriction.",
            "reasons": ["Synthetic reason, not a real determination."],
            "support": [{
                "evidence_class": "aggregate_diagnostic",
                "source": synthetic_reference(),
                "relevance_explanation": "Synthetic diagnostic reference.",
            }],
        }],
        "unreviewed_assumptions": [],
        "review_policy": synthetic_reference(),
        "challenge_route": synthetic_reference(),
        "notification_policy": synthetic_reference(),
    }


def synthetic_use_policy():
    return {
        "contract_version": "prohibited-use-research-v1",
        "revision": "synthetic-revision",
        "attribution": ATTRIBUTION,
        "protected_conclusions": list(CONCLUSIONS),
        "required_nonaggregate_support": True,
        "worth_ranking": "not_supported",
        "authority_approval": synthetic_reference(),
        "challenge_route": synthetic_reference(),
    }


class ContractTests(unittest.TestCase):
    def test_all_schemas_are_well_formed(self):
        for schema in (
            UNCERTAINTY_SCHEMA,
            USE_POLICY_SCHEMA,
            SCALE_SCHEMA,
            RECEIPT_SCHEMA,
        ):
            Draft202012Validator.check_schema(schema)

    def test_empty_evidence_states_are_honest(self):
        schema = evidence_collection()
        self.assertEqual(
            validate_structure(
                schema, {"state": "not_assessed", "items": []}
            ),
            (),
        )
        self.assertEqual(
            validate_structure(
                schema,
                {
                    "state": "none_recorded",
                    "items": [],
                    "assessment_basis": "Synthetic bounded assessment.",
                },
            ),
            (),
        )

    def test_recorded_state_requires_actual_reference(self):
        self.assertTrue(validate_structure(
            evidence_collection(),
            {"state": "recorded", "items": []},
        ))

    def test_aggregate_only_reliance_is_rejected(self):
        result = check_reliance(
            synthetic_receipt(), synthetic_use_policy()
        )
        self.assertIn("aggregate_diagnostic_is_sole_support", result)

    def test_numerical_method_requires_scale_resolution(self):
        receipt = deepcopy(synthetic_receipt())
        receipt["method"] = "minimax_regret"
        result = check_reliance(receipt, synthetic_use_policy())
        self.assertIn("scale_reference_required", result)
        self.assertIn("scale_resolution_required", result)

    def test_unknown_evidence_class_is_structurally_invalid(self):
        receipt = synthetic_receipt()
        receipt["conclusions"][0]["support"][0]["evidence_class"] = "trust_magic"
        self.assertTrue(validate_structure(RECEIPT_SCHEMA, receipt))


if __name__ == "__main__":
    unittest.main()

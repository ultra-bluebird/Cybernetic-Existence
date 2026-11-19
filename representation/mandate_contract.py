"""Research-only proxy mandate contract.

Dependency:
    python -m pip install jsonschema

Run tests:
    python research/representation/mandate_contract.py

No storage, networking, token issuance, or external actions are performed.
"""

from copy import deepcopy
from datetime import datetime
import unittest

from jsonschema import Draft202012Validator, FormatChecker


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def text():
    return {"type": "string", "minLength": 1, "maxLength": 1000}


def choice(*values):
    return {"type": "string", "enum": list(values)}


def closed_record(properties):
    return {
        "type": "object",
        "properties": properties,
        "required": list(properties),
        "additionalProperties": False,
    }


SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    **closed_record({
        "schema_version": {"const": "research-proposal"},
        "attribution": {"const": ATTRIBUTION},
        "authority": closed_record({
            "route": choice(
                "supported_participation",
                "authorized_proxy",
                "protective_appointment",
            ),
            "basis": text(),
            "appointment_authority": text(),
            "represented_party_record": text(),
            "representative_record": text(),
            "authorization_status": choice(
                "expressed_authorization",
                "not_required_for_support",
                "not_obtainable_currently",
            ),
            "basis_review": choice("pending", "reviewed"),
        }),
        "scope": closed_record({
            "matter": text(),
            "permitted_actions": {
                "type": "array",
                "minItems": 1,
                "maxItems": 10,
                "uniqueItems": True,
                "items": choice(
                    "assist_communication",
                    "submit_account",
                    "request_review",
                    "inspect_permitted_records",
                    "propose_remedy",
                ),
            },
            "exclusions": {
                "type": "array",
                "minItems": 1,
                "maxItems": 20,
                "uniqueItems": True,
                "items": text(),
            },
            "onward_delegation": {"const": "not_permitted"},
        }),
        "agency": closed_record({
            "preference_status": choice(
                "expressed", "partially_known", "unknown"
            ),
            "preference_record": text(),
            "communication_support": text(),
            "refusal_and_challenge_process": text(),
        }),
        "independence": closed_record({
            "funding_source": text(),
            "appointment_control": text(),
            "removal_control": text(),
            "information_access": text(),
            "assessment_status": choice(
                "pending", "no_concern_recorded", "concerns_recorded"
            ),
            "assessment_record": text(),
            "safeguards": text(),
            "assessor_independence": choice(
                "established_for_this_review", "unresolved"
            ),
        }),
        "review": closed_record({
            "independent_route": text(),
            "urgent_route": text(),
            "replacement_process": text(),
            "continuity_plan": text(),
            "effective_from": {"type": "string", "format": "date-time"},
            "effective_until": {"type": "string", "format": "date-time"},
            "review_due": {"type": "string", "format": "date-time"},
        }),
        "privacy": closed_record({
            "visibility": {"const": "confidential_case_record"},
            "custodian": text(),
            "access_rule": text(),
            "retention_rule": text(),
            "correction_and_history": text(),
        }),
    }),
}


VALIDATOR = Draft202012Validator(
    SCHEMA,
    format_checker=FormatChecker(),
)


def parse_time(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.utcoffset() is None:
        raise ValueError("Timezone information is required.")
    return parsed


def validate_mandate(record):
    """Return contract errors, not an appointment or authorization decision."""
    errors = []
    for error in sorted(
        VALIDATOR.iter_errors(record),
        key=lambda item: tuple(str(part) for part in item.absolute_path),
    ):
        location = ".".join(str(part) for part in error.absolute_path)
        errors.append(f"{location or 'record'}: {error.message}")

    if errors:
        return tuple(errors)

    def require_nonblank(value, path):
        if isinstance(value, str) and not value.strip():
            errors.append(f"{path}: whitespace-only text is not permitted")
        elif isinstance(value, dict):
            for key, item in value.items():
                require_nonblank(item, f"{path}.{key}")
        elif isinstance(value, list):
            for index, item in enumerate(value):
                require_nonblank(item, f"{path}[{index}]")

    require_nonblank(record, "record")

    authority = record["authority"]
    route = authority["route"]
    authorization = authority["authorization_status"]
    expected = {
        "supported_participation": "not_required_for_support",
        "authorized_proxy": "expressed_authorization",
        "protective_appointment": "not_obtainable_currently",
    }
    if authorization != expected[route]:
        errors.append("authority: route and authorization status conflict")

    actions = record["scope"]["permitted_actions"]
    if (
        route == "supported_participation"
        and actions != ["assist_communication"]
    ):
        errors.append(
            "scope: this support-only contract permits communication "
            "assistance, not proxy powers"
        )

    if authority["basis_review"] != "reviewed":
        errors.append("authority: appointment basis review remains pending")

    independence = record["independence"]
    if independence["assessment_status"] == "pending":
        errors.append("independence: conflict assessment remains pending")
    if (
        independence["assessor_independence"]
        != "established_for_this_review"
    ):
        errors.append("independence: assessor independence remains unresolved")

    try:
        review = record["review"]
        start = parse_time(review["effective_from"])
        end = parse_time(review["effective_until"])
        due = parse_time(review["review_due"])
        if not start < end:
            errors.append("review: effective interval must be nonempty")
        if not start <= due < end:
            errors.append("review: review must fall within the effective period")
    except ValueError:
        errors.append("review: timestamps could not be compared")

    return tuple(errors)


def synthetic_mandate():
    return {
        "schema_version": "research-proposal",
        "attribution": ATTRIBUTION,
        "authority": {
            "route": "authorized_proxy",
            "basis": "Synthetic expressed permission for a bounded review.",
            "appointment_authority": "Synthetic authorizing participant.",
            "represented_party_record": "Controlled synthetic party record.",
            "representative_record": "Controlled synthetic proxy record.",
            "authorization_status": "expressed_authorization",
            "basis_review": "reviewed",
        },
        "scope": {
            "matter": "Synthetic appeal about communication access.",
            "permitted_actions": ["submit_account", "request_review"],
            "exclusions": [
                "No settlement, waiver, hardware control, or unrelated disclosure."
            ],
            "onward_delegation": "not_permitted",
        },
        "agency": {
            "preference_status": "partially_known",
            "preference_record": "Synthetic preference account with uncertainty.",
            "communication_support": "Text with additional response time.",
            "refusal_and_challenge_process": "Accessible independent review.",
        },
        "independence": {
            "funding_source": "Synthetic protected review budget.",
            "appointment_control": "Participant selects the proxy.",
            "removal_control": "Participant can request replacement.",
            "information_access": "Purpose-limited case access.",
            "assessment_status": "concerns_recorded",
            "assessment_record": "Synthetic funding dependency assessment.",
            "safeguards": "Independent review and protected funding.",
            "assessor_independence": "established_for_this_review",
        },
        "review": {
            "independent_route": "Synthetic independent review desk.",
            "urgent_route": "Synthetic accessible urgent review channel.",
            "replacement_process": "Review request without adverse inference.",
            "continuity_plan": "Maintain communication assistance during review.",
            "effective_from": "2026-11-01T12:00:00Z",
            "effective_until": "2026-11-08T12:00:00Z",
            "review_due": "2026-11-03T12:00:00Z",
        },
        "privacy": {
            "visibility": "confidential_case_record",
            "custodian": "Synthetic confidential records service.",
            "access_rule": "Need-to-know access for the stated matter.",
            "retention_rule": "Purpose-limited review under an adopted schedule.",
            "correction_and_history": "Retain controlled amendment history.",
        },
    }


class MandateContractTests(unittest.TestCase):
    def test_schema_is_well_formed(self):
        Draft202012Validator.check_schema(SCHEMA)

    def test_complete_synthetic_contract(self):
        self.assertEqual(validate_mandate(synthetic_mandate()), ())

    def test_every_top_level_group_is_required(self):
        for field in SCHEMA["required"]:
            sample = synthetic_mandate()
            del sample[field]
            self.assertTrue(validate_mandate(sample))

    def test_unexpected_sensitive_field_is_rejected(self):
        sample = synthetic_mandate()
        sample["neural_inventory"] = "Not permitted by this contract."
        self.assertTrue(validate_mandate(sample))

    def test_protective_appointment_cannot_assert_proxy_consent(self):
        sample = synthetic_mandate()
        sample["authority"]["route"] = "protective_appointment"
        self.assertTrue(validate_mandate(sample))

    def test_review_after_expiry_is_rejected(self):
        sample = synthetic_mandate()
        sample["review"]["review_due"] = "2026-11-09T12:00:00Z"
        self.assertTrue(validate_mandate(sample))

    def test_unknown_preferences_do_not_erase_representation(self):
        sample = synthetic_mandate()
        sample["agency"]["preference_status"] = "unknown"
        self.assertEqual(validate_mandate(sample), ())

    def test_pending_assessment_is_incomplete_not_misconduct(self):
        sample = deepcopy(synthetic_mandate())
        sample["independence"]["assessment_status"] = "pending"
        errors = validate_mandate(sample)
        self.assertIn(
            "independence: conflict assessment remains pending",
            errors,
        )


if __name__ == "__main__":
    unittest.main()

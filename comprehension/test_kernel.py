"""Synthetic regression and differential tests; not participant research.
SPDX-License-Identifier: MIT OR Apache-2.0
"""
import copy
from fractions import Fraction
from pathlib import Path
import json
import unittest
from research.comprehension.kernel import ComprehensionKernel, CountError, TASKS, MAX_COUNT

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "schemas/comprehension_vector.schema.json").read_text(encoding="utf-8"))

def fixture():
    return {
        "schema_version": "1.0.0",
        "record_kind": "task_comprehension_counts",
        "provenance": {
            "sovereign_attribution": "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            "attribution_use": "document_credit_only_not_participant_identity",
        },
        "scope": {
            "instrument_revision": "synthetic-instrument-1",
            "study_condition": "non-operational synthetic test condition",
            "sample_type": "synthetic_fixture",
            "measurement_unit": "assigned_task_response",
            "scoring_target": "communication_or_service_not_person_competence",
        },
        "tasks": {task: {
            "assigned": 10, "correct": 8, "incorrect": 1,
            "explicit_uncertainty": 1, "missing": 0,
            "rubric_revision": "synthetic-rubric-1",
        } for task in TASKS},
    }

class VectorTests(unittest.TestCase):
    def setUp(self):
        self.kernel = ComprehensionKernel(SCHEMA)

    def test_inference_changes_do_not_change_consent(self):
        base = fixture()
        changed = copy.deepcopy(base)
        changed["tasks"]["inference"].update(correct=2, incorrect=7)
        first = self.kernel.summarize(base)
        second = self.kernel.summarize(changed)
        self.assertEqual(second["tasks"]["inference"]["correct_rate"], float(Fraction(2, 9)))
        self.assertEqual(first["tasks"]["consent"], second["tasks"]["consent"])
        for task in TASKS:
            if task != "inference":
                self.assertEqual(first["tasks"][task], second["tasks"][task])

    def test_consent_changes_do_not_change_inference(self):
        base = fixture()
        changed = copy.deepcopy(base)
        changed["tasks"]["consent"].update(correct=1, incorrect=8)
        first = self.kernel.summarize(base)
        second = self.kernel.summarize(changed)
        self.assertEqual(second["tasks"]["consent"]["correct_rate"], float(Fraction(1, 9)))
        self.assertEqual(first["tasks"]["inference"], second["tasks"]["inference"])

    def test_high_consent_does_not_mask_zero_inference(self):
        data = fixture()
        data["tasks"]["inference"].update(correct=0, incorrect=10, explicit_uncertainty=0)
        data["tasks"]["consent"].update(correct=10, incorrect=0, explicit_uncertainty=0)
        result = self.kernel.summarize(data)
        self.assertEqual(result["comprehension_vector"]["inference"], 0)
        self.assertEqual(result["comprehension_vector"]["consent"], 1)
        self.assertEqual(result["composite"], "not_calculated")

    def test_small_count_space_against_fraction_oracle(self):
        compositions = 0
        for assigned in range(6):
            for correct in range(assigned + 1):
                for incorrect in range(assigned - correct + 1):
                    for uncertainty in range(assigned - correct - incorrect + 1):
                        missing = assigned - correct - incorrect - uncertainty
                        for task in TASKS:
                            data = fixture()
                            data["tasks"][task].update(
                                assigned=assigned, correct=correct, incorrect=incorrect,
                                explicit_uncertainty=uncertainty, missing=missing,
                            )
                            result = self.kernel.summarize(data)
                            expected = None if correct + incorrect == 0 else float(Fraction(correct, correct + incorrect))
                            self.assertEqual(result["comprehension_vector"][task], expected)
                        compositions += 1
        self.assertEqual(compositions, 126)

    def test_zero_denominator_is_not_zero_comprehension(self):
        data = fixture()
        data["tasks"]["meaning"].update(correct=0, incorrect=0, explicit_uncertainty=10)
        result = self.kernel.summarize(data)
        self.assertIsNone(result["comprehension_vector"]["meaning"])
        self.assertEqual(result["tasks"]["meaning"]["scorable_coverage"], 0)

    def test_partition_mismatch_rejected(self):
        data = fixture()
        data["tasks"]["meaning"]["assigned"] = 9
        with self.assertRaises(CountError): self.kernel.summarize(data)

    def test_boolean_float_negative_and_overflow_rejected(self):
        for bad in (True, 1.0, -1, MAX_COUNT + 1):
            data = fixture()
            data["tasks"]["meaning"]["correct"] = bad
            with self.subTest(value_type=type(bad).__name__):
                with self.assertRaises(CountError): self.kernel.summarize(data)

    def test_total_overflow_rejected(self):
        data = fixture()
        data["tasks"]["meaning"].update(assigned=MAX_COUNT, correct=MAX_COUNT, incorrect=1, explicit_uncertainty=0)
        with self.assertRaises(CountError): self.kernel.summarize(data)

    def test_task_omission_and_extra_task_rejected(self):
        for action in ("omit", "add"):
            data = fixture()
            if action == "omit": del data["tasks"]["inference"]
            else: data["tasks"]["exit_plan"] = copy.deepcopy(data["tasks"]["meaning"])
            with self.assertRaises(CountError): self.kernel.summarize(data)

    def test_exit_and_preference_records_rejected(self):
        for wrong in ({"information": "P", "continuity": "P"}, {"format_version": "1.0.0", "preferences": {}}):
            with self.assertRaises(CountError): self.kernel.summarize(wrong)

    def test_private_field_and_unknown_version_rejected(self):
        for key, value in (("neural_data", "excluded"), ("schema_version", "2.0.0")):
            data = fixture()
            data[key] = value
            with self.assertRaises(CountError): self.kernel.summarize(data)

    def test_policy_schema_rejects_composite_substitution(self):
        from jsonschema import Draft202012Validator, ValidationError
        policy = json.loads((ROOT / "governance/comprehension_vector_policy.json").read_text(encoding="utf-8"))
        definition = json.loads((ROOT / "schemas/comprehension_vector_policy.schema.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(definition)
        validator.validate(policy)
        changed = copy.deepcopy(policy)
        changed["composite"] = "arithmetic_mean"
        with self.assertRaises(ValidationError):
            validator.validate(changed)

    def test_input_not_mutated_and_results_repeat(self):
        data = fixture()
        saved = copy.deepcopy(data)
        self.assertEqual(self.kernel.summarize(data), self.kernel.summarize(data))
        self.assertEqual(data, saved)

if __name__ == "__main__":
    unittest.main()

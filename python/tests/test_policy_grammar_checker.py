import unittest

from policy_grammar_checker import (
    FindingSeverity,
    check_policy,
)


COMPLIANT_POLICY = """
A person using assistive technology or making a voluntary self-description
shall not be denied service, charged a differential rate, excluded from a
benefit, or retaliated against.

A violation triggers an accessible investigation, review process, and appeal.
The affected party may request correction, service restoration, a human review,
an accessible communication format, and a non-digital alternative.

The organization provides non-retaliation safeguards, minimum disclosure,
data minimization, and purpose limitation.
"""


class PolicyGrammarCheckerTests(unittest.TestCase):
    def test_complete_policy_passes_structural_checks(self) -> None:
        report = check_policy(COMPLIANT_POLICY)

        self.assertTrue(report.compliant_structure)
        self.assertEqual(report.error_count, 0)

    def test_missing_remediation_is_reported(self) -> None:
        report = check_policy(
            """
            A person shall not be denied service.
            A violation triggers an investigation and review process.
            The organization provides minimum disclosure and accessible communication.
            """
        )

        self.assertFalse(report.compliant_structure)
        self.assertTrue(
            any(finding.rule_id == "missing_remediation" for finding in report.findings)
        )

    def test_disclosure_pressure_is_an_error(self) -> None:
        report = check_policy(
            COMPLIANT_POLICY
            + "\nApplicants must disclose medical device information before service.\n"
        )

        self.assertFalse(report.compliant_structure)
        self.assertTrue(
            any(
                finding.rule_id == "exclusionary_language_review"
                and finding.severity is FindingSeverity.ERROR
                for finding in report.findings
            )
        )

    def test_proxy_language_requires_human_review(self) -> None:
        report = check_policy(
            COMPLIANT_POLICY
            + "\nA device usage profile may be considered during evaluation.\n"
        )

        self.assertTrue(
            any(
                finding.rule_id == "proxy_variable_review"
                and finding.severity is FindingSeverity.WARNING
                for finding in report.findings
            )
        )

    def test_empty_policy_is_rejected(self) -> None:
        report = check_policy("")

        self.assertFalse(report.compliant_structure)
        self.assertEqual(report.findings[0].rule_id, "policy_text_required")


if __name__ == "__main__":
    unittest.main()

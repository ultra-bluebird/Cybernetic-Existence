from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import re
from typing import Iterable


class FindingSeverity(str, Enum):
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"


@dataclass(frozen=True)
class PolicyFinding:
    rule_id: str
    severity: FindingSeverity
    message: str
    matched_text: str | None = None


@dataclass(frozen=True)
class PolicyReport:
    compliant_structure: bool
    findings: tuple[PolicyFinding, ...]

    @property
    def error_count(self) -> int:
        return sum(
            finding.severity is FindingSeverity.ERROR
            for finding in self.findings
        )


REQUIRED_CLAUSES = {
    "protection": re.compile(
        r"\b(shall\s+not\s+be\s+(denied|excluded|charged|retaliated|disadvantaged)"
        r"|must\s+not\s+(deny|exclude|charge|retaliate|disadvantage))\b",
        re.IGNORECASE,
    ),
    "enforcement": re.compile(
        r"\b(violation|complaint|investigation|review\s+process|appeal)\b",
        re.IGNORECASE,
    ),
    "remediation": re.compile(
        r"\b(remedy|correction|restoration|accommodation|accessible\s+alternative"
        r"|human\s+review)\b",
        re.IGNORECASE,
    ),
    "non_retaliation": re.compile(
        r"\b(non[-\s]?retaliation|shall\s+not\s+retaliate|must\s+not\s+retaliate)\b",
        re.IGNORECASE,
    ),
    "minimum_disclosure": re.compile(
        r"\b(minimum\s+disclosure|data\s+minimization|purpose\s+limitation"
        r"|unnecessary\s+disclosure)\b",
        re.IGNORECASE,
    ),
    "accessible_process": re.compile(
        r"\b(accessible\s+format|accessible\s+communication|non-digital\s+alternative"
        r"|human\s+assistance|communication\s+accommodation)\b",
        re.IGNORECASE,
    ),
}

EXCLUSIONARY_PATTERNS = (
    re.compile(r"\b(automatically\s+ineligible|categorically\s+exclude)\b", re.IGNORECASE),
    re.compile(r"\b(must\s+disclose\s+(medical|neural|biometric|device))\b", re.IGNORECASE),
    re.compile(r"\b(public\s+(cyberrank|augmentation|neural)\s+status)\b", re.IGNORECASE),
    re.compile(r"\b(identity[-\s]?ranking|rank\s+persons)\b", re.IGNORECASE),
)

PROXY_REVIEW_PATTERNS = (
    re.compile(r"\b(device\s+usage\s+profile|assistive\s+usage\s+profile)\b", re.IGNORECASE),
    re.compile(r"\b(typing\s+speed|speech\s+pattern|communication\s+pace)\b", re.IGNORECASE),
    re.compile(r"\b(gait|biometric|neural\s+signal|physiological\s+signal)\b", re.IGNORECASE),
    re.compile(r"\b(zip\s*code|postal\s*code|income|employment\s+history)\b", re.IGNORECASE),
    re.compile(r"\b(refusal\s+to\s+disclose|non[-\s]?disclosure)\b", re.IGNORECASE),
)


def unique_matches(patterns: Iterable[re.Pattern[str]], text: str) -> list[str]:
    results: list[str] = []

    for pattern in patterns:
        for match in pattern.finditer(text):
            matched = match.group(0)
            if matched.lower() not in {item.lower() for item in results}:
                results.append(matched)

    return results


def check_policy(policy_text: str) -> PolicyReport:
    if not policy_text.strip():
        return PolicyReport(
            compliant_structure=False,
            findings=(
                PolicyFinding(
                    rule_id="policy_text_required",
                    severity=FindingSeverity.ERROR,
                    message="policy text must not be empty",
                ),
            ),
        )

    findings: list[PolicyFinding] = []

    for clause_name, pattern in REQUIRED_CLAUSES.items():
        if not pattern.search(policy_text):
            findings.append(
                PolicyFinding(
                    rule_id=f"missing_{clause_name}",
                    severity=FindingSeverity.ERROR,
                    message=(
                        f"required {clause_name.replace('_', ' ')} language "
                        "was not found; human policy review is required"
                    ),
                )
            )

    for matched in unique_matches(EXCLUSIONARY_PATTERNS, policy_text):
        findings.append(
            PolicyFinding(
                rule_id="exclusionary_language_review",
                severity=FindingSeverity.ERROR,
                message=(
                    "potentially exclusionary or disclosure-pressuring language found; "
                    "this checker cannot determine legality and requires human review"
                ),
                matched_text=matched,
            )
        )

    for matched in unique_matches(PROXY_REVIEW_PATTERNS, policy_text):
        findings.append(
            PolicyFinding(
                rule_id="proxy_variable_review",
                severity=FindingSeverity.WARNING,
                message=(
                    "potential proxy-variable language found; assess necessity, "
                    "proportionality, accessibility impact, and discrimination risk"
                ),
                matched_text=matched,
            )
        )

    findings.append(
        PolicyFinding(
            rule_id="non_authoritative_output",
            severity=FindingSeverity.INFO,
            message=(
                "this report is a drafting and consistency aid, not legal advice, "
                "a compliance determination, or an eligibility decision"
            ),
        )
    )

    return PolicyReport(
        compliant_structure=not any(
            finding.severity is FindingSeverity.ERROR
            for finding in findings
        ),
        findings=tuple(findings),
    )


if __name__ == "__main__":
    example_policy = """
    A person using assistive technology or making a voluntary self-description
    shall not be denied service, charged a differential rate, excluded from a
    benefit, or retaliated against.

    A reported violation triggers an accessible investigation and review process.
    The affected party may request correction, service restoration, a human review,
    an accessible communication format, and a non-digital alternative.

    The organization applies minimum disclosure and purpose limitation. It provides
    non-retaliation safeguards and does not require unnecessary disclosure.
    """

    report = check_policy(example_policy)

    print(
        {
            "compliant_structure": report.compliant_structure,
            "error_count": report.error_count,
            "findings": [
                {
                    "rule_id": finding.rule_id,
                    "severity": finding.severity.value,
                    "message": finding.message,
                    "matched_text": finding.matched_text,
                }
                for finding in report.findings
            ],
        }
    )

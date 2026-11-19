"""Pure research summaries. No I/O, file generation, or external actions.

One Experience record per task episode.
One Attempt record per tested task episode and selected arrangement.
Deduplication, consent, retention, and comparison approval are upstream.
"""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction


class ContractError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContractError(message)


def text(value):
    require(
        isinstance(value, str) and bool(value.strip())
        and value == value.strip(),
        "Expected trimmed nonempty text."
    )


def records(value):
    require(type(value) is tuple, "Expected a tuple.")


def rate(numerator, denominator):
    return Fraction(numerator, denominator) if denominator else None


class Nonresponse(str, Enum):
    NOT_APPLICABLE = "not_applicable"
    DECLINED = "declined"
    SKIPPED = "skipped"
    NOT_OFFERED = "not_offered"


@dataclass(frozen=True)
class Experience:
    instrument_version: str
    administration_format: str
    # Integer positions 1..5 or an explicit nonresponse value.
    clarity: int | Nonresponse
    control: int | Nonresponse
    effort: int | Nonresponse
    respect: int | Nonresponse


def summarize_experience(experiences):
    records(experiences)
    groups = {}
    for item in experiences:
        require(isinstance(item, Experience), "Expected Experience.")
        text(item.instrument_version)
        text(item.administration_format)
        key = (item.instrument_version, item.administration_format)
        group = groups.setdefault(key, {
            name: {
                "distribution": {position: 0 for position in range(1, 6)},
                "nonresponse": {reason.value: 0 for reason in Nonresponse},
                "substantive_count": 0,
            }
            for name in ("clarity", "control", "effort", "respect")
        })
        for name in group:
            value = getattr(item, name)
            if type(value) is int and 1 <= value <= 5:
                group[name]["distribution"][value] += 1
                group[name]["substantive_count"] += 1
            else:
                require(isinstance(value, Nonresponse),
                        "Expected scale position 1..5 or explicit nonresponse.")
                group[name]["nonresponse"][value.value] += 1
    return groups


class Outcome(str, Enum):
    CORRECTLY_COMPLETED = "correctly_completed"
    INCORRECTLY_COMPLETED = "incorrectly_completed"
    STOPPED = "stopped"
    PENDING = "pending"
    UNKNOWN = "unknown"


class Correction(str, Enum):
    NOT_ATTEMPTED = "not_attempted"
    SUCCESS = "success"
    FAILED = "failed"
    PENDING = "pending"
    UNKNOWN = "unknown"


class Disclosure(str, Enum):
    YES = "yes"
    NO = "no"
    UNSURE = "not_sure"
    DECLINED = "declined"
    SKIPPED = "skipped"
    NOT_OFFERED = "not_offered"


@dataclass(frozen=True)
class Attempt:
    task_version: str
    arrangement: str
    methods: tuple[str, ...]
    channel: str
    offline: bool
    human_assisted: bool
    necessary_support_preserved: bool
    comparison_admissible: bool
    outcome: Outcome
    correction: Correction
    disclosure: Disclosure


def validate_attempt(item):
    require(isinstance(item, Attempt), "Expected Attempt.")
    for value in (item.task_version, item.arrangement, item.channel):
        text(value)
    records(item.methods)
    require(bool(item.methods), "Declare at least one communication method.")
    for method in item.methods:
        text(method)
    require(len(set(item.methods)) == len(item.methods),
            "Duplicate method label.")
    for value in (
        item.offline, item.human_assisted,
        item.necessary_support_preserved, item.comparison_admissible
    ):
        require(type(value) is bool, "Expected boolean metadata.")
    require(isinstance(item.outcome, Outcome), "Invalid outcome.")
    require(isinstance(item.correction, Correction),
            "Invalid correction outcome.")
    require(isinstance(item.disclosure, Disclosure),
            "Invalid disclosure response.")


def summarize_battery(attempts):
    records(attempts)
    groups = {}
    definitions = {}

    for item in attempts:
        validate_attempt(item)
        key = (item.task_version, item.arrangement)
        definition = (
            tuple(sorted(item.methods)), item.channel,
            item.offline, item.human_assisted
        )
        require(key not in definitions or definitions[key] == definition,
                "One arrangement label has incompatible definitions.")
        definitions[key] = definition

        group = groups.setdefault(key, {
            "attempted": 0,
            "outcomes": {value.value: 0 for value in Outcome},
            "corrections": {value.value: 0 for value in Correction},
            "disclosure": {value.value: 0 for value in Disclosure},
            "support_not_preserved": 0,
            "comparability_limited": 0,
        })
        group["attempted"] += 1
        group["outcomes"][item.outcome.value] += 1
        group["corrections"][item.correction.value] += 1
        group["disclosure"][item.disclosure.value] += 1
        group["support_not_preserved"] += int(
            not item.necessary_support_preserved
        )
        group["comparability_limited"] += int(
            not item.comparison_admissible
        )

    for key, group in groups.items():
        correction = group["corrections"]
        correction_attempted = sum(
            count for name, count in correction.items()
            if name != Correction.NOT_ATTEMPTED.value
        )
        correction_resolved = (
            correction[Correction.SUCCESS.value]
            + correction[Correction.FAILED.value]
        )
        disclosure = group["disclosure"]
        substantive = (
            disclosure[Disclosure.YES.value]
            + disclosure[Disclosure.NO.value]
            + disclosure[Disclosure.UNSURE.value]
        )
        group["arrangement_definition"] = definitions[key]
        group["correct_completion_fraction"] = rate(
            group["outcomes"][Outcome.CORRECTLY_COMPLETED.value],
            group["attempted"]
        )
        group["correction_attempted"] = correction_attempted
        group["correction_success_among_attempted"] = rate(
            correction[Correction.SUCCESS.value], correction_attempted
        )
        group["correction_success_among_resolved"] = rate(
            correction[Correction.SUCCESS.value], correction_resolved
        )
        group["unwanted_disclosure_report_fraction"] = rate(
            disclosure[Disclosure.YES.value], substantive
        )
        group["comparison_ready"] = (
            group["support_not_preserved"] == 0
            and group["comparability_limited"] == 0
        )
        group["interpretation"] = (
            "Task-arrangement description; not a person score, "
            "demographic-equity finding, or proof of equivalence."
        )
    return groups

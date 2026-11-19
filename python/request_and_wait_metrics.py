"""Pure research metrics. No I/O, files, telemetry, or external actions.

Request collections must contain one record per atomic request item.
Submission collections must contain one record per first submission.
Time values are integer seconds on one declared episode-relative scale.
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
    require(isinstance(value, str) and bool(value.strip())
            and value == value.strip(), "Expected trimmed nonempty text.")


def sequence(value):
    require(type(value) is tuple, "Expected a tuple.")


def ratio(numerator, denominator):
    return Fraction(numerator, denominator) if denominator else None


class Necessity(str, Enum):
    NEW = "new_request"
    UNNECESSARY = "unnecessary_repeat"
    UPDATE = "legitimate_update"
    CORRECTION = "legitimate_correction"
    PURPOSE_LIMITED = "justified_purpose_limited_request"
    UNRESOLVED = "unresolved"


@dataclass(frozen=True)
class Rating:
    classification: Necessity
    reason: str
    source: str
    protocol_version: str


@dataclass(frozen=True)
class RequestReview:
    # Positions refer to two fixed, independent reviewer roles.
    ratings: tuple[Rating | None, Rating | None]


def validate_review(review):
    require(isinstance(review, RequestReview), "Expected RequestReview.")
    sequence(review.ratings)
    require(len(review.ratings) == 2, "Exactly two reviewer slots required.")
    for rating in review.ratings:
        if rating is not None:
            require(isinstance(rating, Rating), "Expected Rating.")
            require(isinstance(rating.classification, Necessity),
                    "Invalid necessity classification.")
            for value in (rating.reason, rating.source,
                          rating.protocol_version):
                text(value)


def summarize_requests(reviews):
    sequence(reviews)
    confirmed = unresolved = 0
    for review in reviews:
        validate_review(review)
        left, right = review.ratings
        resolved = (
            left is not None and right is not None
            and left.protocol_version == right.protocol_version
            and left.classification == right.classification
            and left.classification != Necessity.UNRESOLVED
        )
        if not resolved:
            unresolved += 1
        elif left.classification == Necessity.UNNECESSARY:
            confirmed += 1

    total = len(reviews)
    return {
        "request_items": total,
        "confirmed_unnecessary": confirmed,
        "unresolved": unresolved,
        "confirmed_fraction": ratio(confirmed, total),
        "classification_lower_bound": ratio(confirmed, total),
        "classification_upper_bound": ratio(confirmed + unresolved, total),
    }


def reviewer_agreement(reviews):
    sequence(reviews)
    categories = tuple(Necessity)
    table = {(a, b): 0 for a in categories for b in categories}
    missing_pairs = mismatched_protocol_pairs = 0

    for review in reviews:
        validate_review(review)
        left, right = review.ratings
        if left is None or right is None:
            missing_pairs += 1
        elif left.protocol_version != right.protocol_version:
            mismatched_protocol_pairs += 1
        else:
            table[left.classification, right.classification] += 1

    n = sum(table.values())
    observed = ratio(sum(table[c, c] for c in categories), n)
    expected = (
        sum(
            Fraction(sum(table[c, b] for b in categories), n)
            * Fraction(sum(table[a, c] for a in categories), n)
            for c in categories
        ) if n else None
    )
    kappa = (
        (observed - expected) / (1 - expected)
        if expected is not None and expected != 1 else None
    )
    return {
        "paired_ratings": n,
        "missing_pairs": missing_pairs,
        "mismatched_protocol_pairs": mismatched_protocol_pairs,
        "cross_tabulation": table,
        "observed_agreement": observed,
        "expected_agreement": expected,
        "kappa": kappa,
        "kappa_unavailable": n == 0 or expected == 1,
    }


class Completeness(str, Enum):
    COMPLETE = "complete_without_correction"
    CORRECTION = "correction_required"
    PENDING = "assessment_pending"
    UNASSESSED = "not_assessed"


class Eligibility(str, Enum):
    MET = "conditions_met"
    NOT_MET = "conditions_not_met"
    UNDETERMINED = "undetermined"


class Decision(str, Enum):
    APPROVED = "approved"
    DENIED = "denied"
    UNDECIDED = "undecided"


@dataclass(frozen=True)
class FirstSubmission:
    completeness: Completeness
    eligibility: Eligibility
    decision: Decision


def summarize_first_submissions(submissions):
    sequence(submissions)
    counts = {value: 0 for value in Completeness}
    for submission in submissions:
        require(isinstance(submission, FirstSubmission),
                "Expected FirstSubmission.")
        require(isinstance(submission.completeness, Completeness),
                "Invalid completeness state.")
        require(isinstance(submission.eligibility, Eligibility),
                "Invalid eligibility state.")
        require(isinstance(submission.decision, Decision),
                "Invalid decision state.")
        counts[submission.completeness] += 1

    assessed = counts[Completeness.COMPLETE] + counts[Completeness.CORRECTION]
    return {
        "first_submissions_recorded": len(submissions),
        "completeness_assessments_finished": assessed,
        "complete_without_correction": counts[Completeness.COMPLETE],
        "correction_required": counts[Completeness.CORRECTION],
        "pending": counts[Completeness.PENDING],
        "unassessed": counts[Completeness.UNASSESSED],
        "completeness_acceptance_fraction":
            ratio(counts[Completeness.COMPLETE], assessed),
        "interpretation": "Not an eligibility or approval rate.",
    }


def seconds(value):
    require(type(value) is int and value >= 0,
            "Expected nonnegative integer seconds.")


def union_intervals(intervals, start, cutoff):
    sequence(intervals)
    normalized = []
    for interval in intervals:
        require(type(interval) is tuple and len(interval) == 2,
                "Expected a start/end pair.")
        left, right = interval
        seconds(left)
        seconds(right)
        require(start <= left < right <= cutoff,
                "Interval must lie within the declared episode window.")
        normalized.append((left, right))

    merged = []
    for left, right in sorted(normalized):
        if merged and left <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(right, merged[-1][1]))
        else:
            merged.append((left, right))
    return tuple(merged)


def duration(intervals):
    return sum(right - left for left, right in intervals)


def waiting_report(start, cutoff, waiting, active, *,
                   resolved, waiting_observation_complete,
                   active_observation_complete):
    seconds(start)
    seconds(cutoff)
    require(cutoff >= start, "Cutoff precedes episode start.")
    for value in (resolved, waiting_observation_complete,
                  active_observation_complete):
        require(type(value) is bool, "Expected boolean metadata.")

    w = union_intervals(waiting, start, cutoff)
    a = union_intervals(active, start, cutoff)
    overlap = sum(
        max(0, min(w_end, a_end) - max(w_start, a_start))
        for w_start, w_end in w for a_start, a_end in a
    )
    return {
        "unit": "second",
        "calendar_elapsed": cutoff - start,
        "calendar_endpoint": "resolution" if resolved else "observation_cutoff",
        "recorded_occupied_waiting": duration(w),
        "recorded_active_work": duration(a),
        "recorded_waiting_active_overlap": overlap,
        "recorded_waiting_only": duration(w) - overlap,
        "recorded_active_or_waiting": duration(w) + duration(a) - overlap,
        "waiting_observation_complete": waiting_observation_complete,
        "active_observation_complete": active_observation_complete,
        "allocation_rule": "Active work first for exclusive accounting.",
    }

"""Pure task-level research metrics.

No I/O, telemetry, file generation, legal determinations, or external actions.
Inputs use semantic descriptions, not personal identifiers.
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


def count(value):
    require(type(value) is int and value >= 0,
            "Expected a nonnegative integer.")


def records(value):
    require(type(value) is tuple, "Expected a tuple.")


def fraction(numerator, denominator):
    return Fraction(numerator, denominator) if denominator else None


class EpisodeStatus(str, Enum):
    COMPLETED = "completed"
    IN_PROGRESS = "in_progress"
    WITHDRAWN = "withdrawn"
    LOST = "lost_to_followup"
    UNKNOWN = "unknown"


class Review(str, Enum):
    REMOVABLE = "requirement_removable"
    NECESSARY = "requirement_necessary_under_reviewed_rules"
    UNRESOLVED = "unresolved"


class Choice(str, Enum):
    CHOSEN = "chosen_visit"
    NOT_CHOSEN = "not_chosen"
    UNKNOWN = "choice_unknown"


@dataclass(frozen=True)
class Visit:
    choice: Choice
    requirement_review: Review
    alternative_supported: bool
    assistance_preserved: bool
    independent_review_completed: bool
    review_basis: str


@dataclass(frozen=True)
class Episode:
    status: EpisodeStatus
    visits: tuple[Visit, ...]


def summarize_visits(episodes):
    records(episodes)
    total_visits = completed_visits = completed = 0
    chosen = avoidable = review_limited = 0

    for episode in episodes:
        require(isinstance(episode, Episode), "Expected Episode.")
        require(isinstance(episode.status, EpisodeStatus),
                "Invalid episode status.")
        records(episode.visits)
        total_visits += len(episode.visits)
        if episode.status == EpisodeStatus.COMPLETED:
            completed += 1
            completed_visits += len(episode.visits)

        for visit in episode.visits:
            require(isinstance(visit, Visit), "Expected Visit.")
            require(isinstance(visit.choice, Choice), "Invalid choice.")
            require(isinstance(visit.requirement_review, Review),
                    "Invalid review.")
            text(visit.review_basis)
            for flag in (
                visit.alternative_supported,
                visit.assistance_preserved,
                visit.independent_review_completed
            ):
                require(type(flag) is bool, "Expected boolean flags.")

            if visit.choice == Choice.CHOSEN:
                chosen += 1

            confirmed = (
                visit.choice == Choice.NOT_CHOSEN
                and visit.requirement_review == Review.REMOVABLE
                and visit.alternative_supported
                and visit.assistance_preserved
                and visit.independent_review_completed
            )
            avoidable += int(confirmed)
            review_limited += int(
                visit.choice == Choice.UNKNOWN
                or visit.requirement_review == Review.UNRESOLVED
                or not visit.independent_review_completed
            )

    return {
        "initiated_episodes": len(episodes),
        "completed_episodes": completed,
        "all_recorded_visits": total_visits,
        "visits_in_completed_episodes": completed_visits,
        "visits_per_initiated_episode":
            fraction(total_visits, len(episodes)),
        "visits_per_completed_episode":
            fraction(completed_visits, completed),
        "chosen_visits": chosen,
        "confirmed_avoidable_visits": avoidable,
        "visits_with_limited_choice_or_review_evidence": review_limited,
    }


class Flow(str, Enum):
    EXPENSE = "expense_paid"
    REFUND = "refund_received"
    REIMBURSEMENT = "reimbursement_received"
    COMPENSATION = "research_compensation_received"


@dataclass(frozen=True)
class Currency:
    code: str
    decimal_places: int


@dataclass(frozen=True)
class Payment:
    currency: str
    category: str
    flow: Flow
    amount_minor: int
    allocation_basis: str


def summarize_costs(currencies, payments, *, cutoff, observation_complete):
    records(currencies)
    records(payments)
    text(cutoff)
    require(type(observation_complete) is bool, "Expected completeness flag.")

    definitions = {}
    for currency in currencies:
        require(isinstance(currency, Currency), "Expected Currency.")
        text(currency.code)
        count(currency.decimal_places)
        require(currency.decimal_places <= 6,
                "Research schema supports at most six decimal places.")
        require(currency.code not in definitions,
                "Duplicate currency declaration.")
        definitions[currency.code] = currency.decimal_places

    totals = {}
    categories = {}
    for payment in payments:
        require(isinstance(payment, Payment), "Expected Payment.")
        require(payment.currency in definitions, "Undeclared currency.")
        require(isinstance(payment.flow, Flow), "Invalid payment flow.")
        text(payment.category)
        text(payment.allocation_basis)
        count(payment.amount_minor)

        bucket = totals.setdefault(
            payment.currency, {flow.value: 0 for flow in Flow}
        )
        bucket[payment.flow.value] += payment.amount_minor
        key = (payment.currency, payment.category, payment.flow.value)
        categories[key] = categories.get(key, 0) + payment.amount_minor

    for currency, bucket in totals.items():
        bucket["decimal_places"] = definitions[currency]
        bucket["outstanding_balance_minor"] = (
            bucket[Flow.EXPENSE.value]
            - bucket[Flow.REFUND.value]
            - bucket[Flow.REIMBURSEMENT.value]
        )

    return {
        "cutoff": cutoff,
        "observation_complete": observation_complete,
        "recorded_payment_count": len(payments),
        "totals_by_currency_minor_units": totals,
        "category_totals_minor_units": categories,
        "empty_ledger_interpretation":
            "No recorded payments; not automatically confirmed zero expense.",
        "compensation_is_separate": True,
    }


class DisclosureResponse(str, Enum):
    YES = "yes"
    NO = "no"
    UNSURE = "not_sure"
    DECLINED = "prefer_not_to_answer"
    SKIPPED = "skipped"
    NOT_OFFERED = "not_offered"


def summarize_disclosure(responses):
    # Exactly one coded question outcome per included task episode.
    records(responses)
    counts = {response.value: 0 for response in DisclosureResponse}
    for response in responses:
        require(isinstance(response, DisclosureResponse),
                "Invalid disclosure-question outcome.")
        counts[response.value] += 1

    yes, no, unsure = counts["yes"], counts["no"], counts["not_sure"]
    substantive = yes + no + unsure
    offered = len(responses) - counts["not_offered"]

    return {
        "included_episodes": len(responses),
        "counts": counts,
        "question_offered": offered,
        "substantive_responses": substantive,
        "affirmative_fraction_among_substantive":
            fraction(yes, substantive),
        "affirmative_fraction_among_definite":
            fraction(yes, yes + no),
        "substantive_response_fraction_among_offered":
            fraction(substantive, offered),
        "interpretation":
            "Reported experience, not a legal determination or "
            "an estimate for nonrespondents.",
    }

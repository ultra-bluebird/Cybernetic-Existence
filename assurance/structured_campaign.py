"""Bounded mixed-level constrained campaign generation.

Python 3.10 or newer; standard library only.

Coverage is relative to a declared finite model.
No runtime tests, external actions, or commitments are executed.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import asdict, dataclass
from itertools import combinations, product
from math import ceil, prod
import re


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


class CampaignError(Exception):
    def __init__(self, details):
        self.details = details
        super().__init__(type(self).__name__)


class InvalidSpecification(CampaignError):
    pass


class InfeasibleTarget(CampaignError):
    pass


class CoverageStalled(CampaignError):
    pass


class BudgetExceeded(CampaignError):
    pass


class MustIncludeConflict(CampaignError):
    pass


class NondeterministicResult(CampaignError):
    pass


@dataclass(frozen=True)
class Factor:
    name: str
    values: tuple[str, ...]
    baseline: str
    must_cover_values: tuple[str, ...] = ()
    applies_when: tuple[tuple[str, str], ...] = ()
    evidence_class: str = "unit"


@dataclass(frozen=True)
class Model:
    version: str
    factors: tuple[Factor, ...]
    forbidden: tuple = ()
    requires: tuple = ()
    max_active: int | None = None
    schema_version: str = "2.0.0"


@dataclass(frozen=True)
class Coverage:
    version: str
    strength: int
    must_include: tuple = ()
    required_patterns: tuple = ()
    max_suite_rows: int = 512
    max_candidates_examined: int = 4096
    schema_version: str = "2.0.0"


def generate(model, policy):
    def invalid(reason):
        raise InvalidSpecification({"reason": reason})

    if (
        type(model) is not Model
        or type(policy) is not Coverage
        or model.schema_version != "2.0.0"
        or policy.schema_version != "2.0.0"
    ):
        invalid("schema")

    if any(
        type(value) is not str or not 1 <= len(value.strip()) <= 128
        for value in (model.version, policy.version)
    ):
        invalid("versions")

    if type(model.factors) is not tuple or not 1 <= len(model.factors) <= 12:
        invalid("factor_count")

    for factor in model.factors:
        if (
            type(factor) is not Factor
            or type(factor.name) is not str
            or len(factor.name) > 64
            or not re.fullmatch("[a-z][a-z0-9_]*", factor.name)
        ):
            invalid("factor_name")

        if (
            type(factor.values) is not tuple
            or not 2 <= len(factor.values) <= 4
            or any(
                type(value) is not str or not 1 <= len(value) <= 128
                for value in factor.values
            )
            or len(set(factor.values)) != len(factor.values)
        ):
            invalid("domain")

        if (
            type(factor.baseline) is not str
            or factor.baseline not in factor.values
            or type(factor.must_cover_values) is not tuple
            or len(factor.must_cover_values) > 4
            or any(
                type(value) is not str or value not in factor.values
                for value in factor.must_cover_values
            )
            or type(factor.applies_when) is not tuple
        ):
            invalid("baseline_floor_or_applicability")

        if (
            type(factor.evidence_class) is not str
            or factor.evidence_class not in {
                "unit", "integration", "adversarial", "offline"
            }
        ):
            invalid("evidence_class")

    factors = tuple(sorted(model.factors, key=lambda factor: factor.name))
    names = tuple(factor.name for factor in factors)
    k = len(factors)

    if len(set(names)) != k:
        invalid("duplicate_factor")

    domains = {factor.name: factor.values for factor in factors}

    def pattern(value, full=False):
        if type(value) is not tuple or not value or len(value) > k:
            invalid("pattern_shape")

        for term in value:
            if (
                type(term) is not tuple
                or len(term) != 2
                or type(term[0]) is not str
                or type(term[1]) is not str
                or term[0] not in domains
                or term[1] not in domains[term[0]]
            ):
                invalid("pattern_term")

        if len({name for name, _ in value}) != len(value):
            invalid("duplicate_pattern_factor")
        if full and {name for name, _ in value} != set(names):
            invalid("incomplete_seed")
        return tuple(sorted(value))

    containers = (
        (model.forbidden, 256),
        (model.requires, 256),
        (policy.must_include, 4096),
        (policy.required_patterns, 4096),
    )
    if any(type(value) is not tuple or len(value) > limit
           for value, limit in containers):
        invalid("constraint_container")

    forbidden = tuple(pattern(value) for value in model.forbidden)
    requires = []

    for rule in model.requires:
        if type(rule) is not tuple or len(rule) != 2:
            invalid("requires_rule")
        requires.append((pattern(rule[0]), pattern(rule[1])))

    applicability = {
        factor.name: (
            pattern(factor.applies_when) if factor.applies_when else ()
        )
        for factor in factors
    }

    if (
        type(policy.strength) is not int
        or not 1 <= policy.strength <= min(3, k)
    ):
        invalid("strength")

    if model.max_active is not None and (
        type(model.max_active) is not int
        or not 0 <= model.max_active <= k
    ):
        invalid("max_active")

    for value in (
        policy.max_suite_rows,
        policy.max_candidates_examined,
    ):
        if type(value) is not int or not 1 <= value <= 4096:
            invalid("budget")

    explicit = tuple(pattern(value) for value in policy.required_patterns)
    if any(len(value) > policy.strength for value in explicit):
        invalid("pattern_exceeds_strength")

    def assignment(row):
        return dict(zip(names, row))

    def matches(row, partial):
        values = assignment(row)
        return all(values[name] == value for name, value in partial)

    def violations(row):
        values = assignment(row)
        reasons = []

        if model.max_active is not None:
            active = sum(
                values[factor.name] != factor.baseline
                for factor in factors
            )
            if active > model.max_active:
                reasons.append("max_active")

        for partial in forbidden:
            if matches(row, partial):
                reasons.append({"forbidden": partial})

        for when, then in requires:
            if matches(row, when) and not matches(row, then):
                reasons.append({"requires": (when, then)})

        for factor in factors:
            condition = applicability[factor.name]
            if (
                values[factor.name] != factor.baseline
                and condition
                and not matches(row, condition)
            ):
                reasons.append({"applicability": factor.name})

        return reasons

    examinations = prod(len(factor.values) for factor in factors)

    if examinations > policy.max_candidates_examined:
        raise BudgetExceeded({
            "phase": "candidate_enumeration",
            "required_candidate_examinations": examinations,
            "limit": policy.max_candidates_examined,
            "residual_uncovered": None,
            "residual_status": "not_computed",
        })

    candidates = tuple(
        row
        for row in product(*(factor.values for factor in factors))
        if not violations(row)
    )

    if not candidates:
        raise InfeasibleTarget({
            "reason": "empty_feasible_model",
            "model": asdict(model),
        })

    seeds = []
    for value in policy.must_include:
        values = dict(pattern(value, full=True))
        row = tuple(values[name] for name in names)

        if row in seeds:
            raise MustIncludeConflict({
                "reason": "duplicate_seed",
                "assignment": assignment(row),
            })

        conflicts = violations(row)
        if conflicts:
            raise MustIncludeConflict({
                "reason": "infeasible_seed",
                "assignment": assignment(row),
                "violations": conflicts,
            })
        seeds.append(row)

    floors = {
        ((factor.name, value),)
        for factor in factors
        for value in factor.must_cover_values
    }

    for partial in floors | set(explicit):
        if not any(matches(row, partial) for row in candidates):
            raise InfeasibleTarget({
                "reason": "required_pattern_infeasible",
                "pattern": partial,
                "model": asdict(model),
            })

    stages = []
    cumulative = set()

    for strength in range(1, policy.strength + 1):
        for row in candidates:
            for columns in combinations(range(k), strength):
                cumulative.add(tuple(
                    (names[column], row[column])
                    for column in columns
                ))

        cumulative.update(floors)
        cumulative.update(
            partial for partial in explicit
            if len(partial) <= strength
        )
        stages.append(frozenset(cumulative))

    targets = stages[-1]
    coverage = {
        row: frozenset(
            partial for partial in targets if matches(row, partial)
        )
        for row in candidates
    }

    seed_covered = (
        set().union(*(coverage[row] for row in seeds))
        if seeds else set()
    )
    residual = targets - seed_covered

    groups = {}
    for partial in targets:
        key = tuple(name for name, _ in partial)
        groups.setdefault(key, set()).add(partial)

    projection_bound = max(len(group) for group in groups.values())
    counting_bound = ceil(
        len(targets) / max(len(value) for value in coverage.values())
    )
    maximum_new = max(
        (
            len(coverage[row] & residual)
            for row in candidates if row not in seeds
        ),
        default=0,
    )

    if residual and maximum_new == 0:
        raise CoverageStalled({
            "phase": "lower_bound",
            "residual_uncovered": sorted(residual),
        })

    seed_bound = len(seeds) + (
        ceil(len(residual) / maximum_new) if residual else 0
    )
    lower_bound = max(
        projection_bound, counting_bound, seed_bound
    )

    selected = list(seeds)
    reasons = {row: "seed" for row in seeds}
    covered = set(seed_covered)
    prefixes = []

    for strength, required in enumerate(stages, 1):
        uncovered = required - covered

        while uncovered:
            remaining = [
                row for row in candidates if row not in reasons
            ]

            if not remaining:
                raise CoverageStalled({
                    "residual_uncovered": sorted(targets - covered),
                    "selected_assignments": [
                        assignment(row) for row in selected
                    ],
                })

            best = max(
                remaining,
                key=lambda row: len(coverage[row] & uncovered),
            )
            gain = coverage[best] & uncovered

            if not gain:
                raise CoverageStalled({
                    "residual_uncovered": sorted(targets - covered),
                    "candidate_next_assignment": assignment(best),
                })

            if len(selected) >= policy.max_suite_rows:
                raise BudgetExceeded({
                    "phase": "selection",
                    "limit": policy.max_suite_rows,
                    "selected_assignments": [
                        assignment(row) for row in selected
                    ],
                    "residual_uncovered": sorted(targets - covered),
                    "next_greedy_assignment": assignment(best),
                })

            selected.append(best)
            reasons[best] = f"strength_{strength}_coverage"
            covered.update(coverage[best])
            uncovered = required - covered

        if len(selected) > policy.max_suite_rows:
            raise BudgetExceeded({
                "phase": "mandatory_seeds",
                "required_rows": len(selected),
                "limit": policy.max_suite_rows,
                "residual_uncovered": sorted(targets - covered),
            })

        prefixes.append({
            "strength": strength,
            "prefix_length": len(selected),
            "required_patterns": len(required),
        })

    witnesses = []

    for partial in sorted(targets):
        witness = next(
            (
                row for row in selected
                if all(
                    row[names.index(name)] == value
                    for name, value in partial
                )
            ),
            None,
        )
        if witness is None:
            raise CoverageStalled({
                "phase": "independent_verification",
                "residual_uncovered": [partial],
            })
        witnesses.append({
            "pattern": dict(partial),
            "witness_assignment": assignment(witness),
        })

    multiplicity = {
        partial: sum(matches(row, partial) for row in selected)
        for partial in targets
    }

    rows = []
    for row in selected:
        rows.append({
            "assignments": assignment(row),
            "sovereign_attribution": ATTRIBUTION,
            "selection_reason": reasons[row],
            "covered_patterns": [
                dict(partial) for partial in sorted(coverage[row])
            ],
            "uniquely_covered_patterns": [
                dict(partial)
                for partial in sorted(coverage[row])
                if multiplicity[partial] == 1
            ],
            "expected_classification": None,
            "oracle_status": "not_bound",
            "execution_plan": "not_configured",
        })

    return {
        "schema_version": "2.0.0",
        "generator_version": "2.0.0",
        "factor_model_version": model.version,
        "coverage_policy_version": policy.version,
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "supplied_specification": {
            "model": asdict(model),
            "coverage": asdict(policy),
        },
        "ordering": {
            "factor_order": "name_ascending_ASCII",
            "value_order": "domain_declaration_order",
            "candidate_enumeration": "cartesian_product_rightmost_fastest",
            "tie_break": "first_maximum_in_candidate_order",
            "randomness": "not_used",
        },
        "candidate_examinations": examinations,
        "feasible_candidate_count": len(candidates),
        "seed_count": len(seeds),
        "greedy_added_count": len(selected) - len(seeds),
        "suite_count": len(selected),
        "lower_bound": {
            "value": lower_bound,
            "projection": projection_bound,
            "counting": counting_bound,
            "mandatory_seed_residual": seed_bound,
            "scope": "final_target_with_declared_mandatory_seeds",
        },
        "nested_prefixes": prefixes,
        "rows": rows,
        "coverage_witnesses": witnesses,
        "residual_uncovered": [],
        "commitment_status": "not_created",
        "runtime_execution": "not_performed",
        "model_coverage_only": True,
    }


def verify_reproduction(model, policy):
    first = generate(model, policy)
    second = generate(model, policy)

    if first != second:
        raise NondeterministicResult({
            "reason": "same_specification_produced_different_structure",
        })

    return first

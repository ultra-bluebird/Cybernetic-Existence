"""Research-only manifest routing and interval accounting.

Dependency:
    python -m pip install PyYAML

Run tests:
    python research/governance/manifest_routing.py \
        config/research/protective_handoff_policy.yaml

No networking, persistence, signing, or external actions.
"""

from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from types import MappingProxyType
from collections.abc import Mapping
import re
import sys
import unittest

import yaml


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)

MAX_BYTES = 65536
MAX_DEPTH = 12
MAX_NODES = 2000


class Result(Enum):
    CONSISTENT = "consistent"
    INCOMPLETE = "incomplete"
    REVIEW_REQUIRED = "review_required"
    BLOCKED = "blocked"


class Finding(Enum):
    STATUS_STALE = "status_stale"
    GRANT_EXPIRED = "grant_expired"
    APPLICABLE_HOLD = "applicable_hold"
    HOLD_UNRESOLVED = "hold_unresolved"
    UNKNOWN_ACTION = "unknown_action"
    RENEWAL_LIMIT = "renewal_limit_exceeded"
    CUMULATIVE_LIMIT = "cumulative_limit_exceeded"


FIXED_ROUTES = {
    Finding.STATUS_STALE: Result.INCOMPLETE,
    Finding.GRANT_EXPIRED: Result.BLOCKED,
    Finding.APPLICABLE_HOLD: Result.BLOCKED,
    Finding.HOLD_UNRESOLVED: Result.REVIEW_REQUIRED,
    Finding.UNKNOWN_ACTION: Result.INCOMPLETE,
    Finding.RENEWAL_LIMIT: Result.BLOCKED,
    Finding.CUMULATIVE_LIMIT: Result.BLOCKED,
}

PRIORITY = {
    Result.CONSISTENT: 0,
    Result.INCOMPLETE: 1,
    Result.REVIEW_REQUIRED: 2,
    Result.BLOCKED: 3,
}


def exact_fields(value, expected):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise ValueError("Unexpected or missing policy fields.")


def bounded_text(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 2000:
        raise ValueError("Expected bounded nonempty text.")
    return value


def natural(value):
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ValueError("Expected an explicit nonnegative integer string.")
    if len(value) > 10:
        raise ValueError("Policy integer exceeds the research input limit.")
    return int(value)


class StrictLoader(yaml.BaseLoader):
    pass


def construct_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        if not isinstance(key_node, yaml.ScalarNode):
            raise ValueError("Mapping keys must be scalar strings.")
        key = loader.construct_scalar(key_node)
        if key == "<<" or key in result:
            raise ValueError("Merge keys and duplicate keys are prohibited.")
        result[key] = loader.construct_object(value_node)
    return result


StrictLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)


@dataclass(frozen=True)
class ActionPolicy:
    max_status_age: int
    notification_within: int
    review_within: int
    maximum_measure_duration: int
    maximum_cumulative_duration: int
    maximum_renewals: int


@dataclass(frozen=True)
class Policy:
    version: str
    clock_domain: str
    actions: Mapping[str, ActionPolicy]
    duties: Mapping[Finding, tuple[str, ...]]
    duty_text: Mapping[str, str]
    locale: str
    notice: str


def load_policy(text):
    if not isinstance(text, str):
        raise TypeError("Policy input must be text.")
    if len(text.encode("utf-8")) > MAX_BYTES:
        raise ValueError("Policy document is too large.")

    depth = 0
    nodes = 0
    for token in yaml.scan(text, Loader=StrictLoader):
        if isinstance(token, (
            yaml.tokens.AnchorToken,
            yaml.tokens.AliasToken,
            yaml.tokens.TagToken,
            yaml.tokens.DirectiveToken,
        )):
            raise ValueError("Unsupported YAML feature.")
        if isinstance(token, (
            yaml.tokens.BlockMappingStartToken,
            yaml.tokens.BlockSequenceStartToken,
            yaml.tokens.FlowMappingStartToken,
            yaml.tokens.FlowSequenceStartToken,
        )):
            depth += 1
            nodes += 1
        elif isinstance(token, (
            yaml.tokens.BlockEndToken,
            yaml.tokens.FlowMappingEndToken,
            yaml.tokens.FlowSequenceEndToken,
        )):
            depth -= 1
        elif isinstance(token, yaml.tokens.ScalarToken):
            nodes += 1
        if depth > MAX_DEPTH or nodes > MAX_NODES:
            raise ValueError("Policy structure exceeds research limits.")

    raw = yaml.load(text, Loader=StrictLoader)
    exact_fields(raw, (
        "schema_version", "policy_version", "attribution", "status",
        "clock", "actions", "finding_routes", "duty_text", "notice",
    ))
    if raw["schema_version"] != "research-policy-v1":
        raise ValueError("Unsupported policy schema.")
    if raw["status"] != "research_only" or raw["attribution"] != ATTRIBUTION:
        raise ValueError("Invalid status or attribution.")

    exact_fields(raw["clock"], ("domain", "unit"))
    if raw["clock"]["unit"] != "seconds":
        raise ValueError("This research interpreter uses seconds.")

    if not isinstance(raw["actions"], dict) or not raw["actions"]:
        raise ValueError("At least one action is required.")
    action_fields = tuple(ActionPolicy.__dataclass_fields__)
    actions = {}
    for name, values in raw["actions"].items():
        bounded_text(name)
        exact_fields(values, action_fields)
        action = ActionPolicy(**{
            field: natural(values[field]) for field in action_fields
        })
        if not (
            action.notification_within <= action.maximum_measure_duration
            and action.review_within <= action.maximum_measure_duration
            and 0 < action.maximum_measure_duration
            <= action.maximum_cumulative_duration
        ):
            raise ValueError("Inconsistent action timing.")
        actions[name] = action

    if not isinstance(raw["duty_text"], dict) or not raw["duty_text"]:
        raise ValueError("Duty catalogue is required.")
    duty_text = {
        bounded_text(key): bounded_text(value)
        for key, value in raw["duty_text"].items()
    }

    exact_fields(raw["finding_routes"], [item.value for item in Finding])
    duties = {}
    for finding in Finding:
        route = raw["finding_routes"][finding.value]
        exact_fields(route, ("result", "duties"))
        if route["result"] != FIXED_ROUTES[finding].value:
            raise ValueError("Manifest cannot redefine result semantics.")
        names = route["duties"]
        if (
            not isinstance(names, list)
            or not names
            or any(not isinstance(name, str) for name in names)
            or len(names) != len(set(names))
            or any(name not in duty_text for name in names)
        ):
            raise ValueError("Invalid duty references.")
        duties[finding] = tuple(names)

    exact_fields(raw["notice"], ("locale", "text"))
    return Policy(
        version=bounded_text(raw["policy_version"]),
        clock_domain=bounded_text(raw["clock"]["domain"]),
        actions=MappingProxyType(actions),
        duties=MappingProxyType(duties),
        duty_text=MappingProxyType(duty_text),
        locale=bounded_text(raw["notice"]["locale"]),
        notice=bounded_text(raw["notice"]["text"]),
    )


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self):
        bounded_text(self.domain)
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Invalid clock tick.")


@dataclass(frozen=True)
class Interval:
    start: Tick
    end: Tick

    def __post_init__(self):
        if not isinstance(self.start, Tick) or not isinstance(self.end, Tick):
            raise TypeError("Interval endpoints must be Tick values.")
        if (
            self.start.domain != self.end.domain
            or self.start.value >= self.end.value
        ):
            raise ValueError("Invalid half-open interval.")


def union_duration(intervals, now):
    if not isinstance(now, Tick) or not isinstance(intervals, tuple):
        raise TypeError("Expected a Tick and an interval tuple.")
    segments = []
    for interval in intervals:
        if not isinstance(interval, Interval):
            raise TypeError("Invalid interval.")
        if interval.start.domain != now.domain:
            raise ValueError("Clock-domain mismatch.")
        end = min(interval.end.value, now.value)
        if interval.start.value < end:
            segments.append((interval.start.value, end))
    segments.sort()

    total = 0
    left = right = None
    for start, end in segments:
        if left is None:
            left, right = start, end
        elif start <= right:
            right = max(right, end)
        else:
            total += right - left
            left, right = start, end
    return total + (0 if left is None else right - left)


@dataclass(frozen=True)
class Observation:
    action: str
    findings: frozenset[Finding]
    renewal_count: int
    intervals: tuple[Interval, ...]

    def __post_init__(self):
        bounded_text(self.action)
        if not isinstance(self.findings, frozenset):
            raise TypeError("findings must be a frozenset.")
        if any(not isinstance(item, Finding) for item in self.findings):
            raise TypeError("Unsupported finding.")
        if type(self.renewal_count) is not int or self.renewal_count < 0:
            raise ValueError("Invalid renewal count.")
        if not isinstance(self.intervals, tuple):
            raise TypeError("intervals must be a tuple.")


@dataclass(frozen=True)
class Assessment:
    result: Result
    findings: frozenset[Finding]
    duties: tuple[str, ...]
    policy_version: str
    notice: str


def assess(policy, observation, now):
    if not isinstance(policy, Policy) or not isinstance(observation, Observation):
        raise TypeError("Expected validated policy and typed observation.")
    if not isinstance(now, Tick) or now.domain != policy.clock_domain:
        raise ValueError("Clock-domain mismatch.")

    elapsed = union_duration(observation.intervals, now)
    findings = set(observation.findings)
    action = policy.actions.get(observation.action)
    if action is None:
        findings.add(Finding.UNKNOWN_ACTION)
    else:
        if observation.renewal_count > action.maximum_renewals:
            findings.add(Finding.RENEWAL_LIMIT)
        if elapsed > action.maximum_cumulative_duration:
            findings.add(Finding.CUMULATIVE_LIMIT)

    result = max(
        (FIXED_ROUTES[item] for item in findings),
        key=PRIORITY.__getitem__,
        default=Result.CONSISTENT,
    )
    duties = sorted({
        duty for finding in findings for duty in policy.duties[finding]
    })
    return Assessment(
        result, frozenset(findings), tuple(duties),
        policy.version, policy.notice,
    )


class RoutingTests(unittest.TestCase):
    policy = None

    def tick(self, value):
        return Tick(self.policy.clock_domain, value)

    def observation(self, findings=frozenset(), renewals=0, intervals=()):
        return Observation("disclosure", findings, renewals, intervals)

    def test_stale_is_incomplete_with_refresh_duty(self):
        result = assess(
            self.policy,
            self.observation(frozenset({Finding.STATUS_STALE})),
            self.tick(5),
        )
        self.assertIs(result.result, Result.INCOMPLETE)
        self.assertIn("refresh_status", result.duties)

    def test_hold_and_stale_preserve_both_findings(self):
        findings = frozenset({
            Finding.APPLICABLE_HOLD, Finding.STATUS_STALE
        })
        result = assess(self.policy, self.observation(findings), self.tick(5))
        self.assertIs(result.result, Result.BLOCKED)
        self.assertEqual(result.findings, findings)
        self.assertIn("refresh_status", result.duties)
        self.assertIn("provide_hold_review", result.duties)

    def test_union_does_not_double_count_overlap(self):
        intervals = (
            Interval(self.tick(0), self.tick(5)),
            Interval(self.tick(3), self.tick(8)),
        )
        self.assertEqual(union_duration(intervals, self.tick(10)), 8)

    def test_renewal_limit_requires_independent_determination(self):
        limit = self.policy.actions["disclosure"].maximum_renewals
        result = assess(
            self.policy, self.observation(renewals=limit + 1), self.tick(1)
        )
        self.assertIs(result.result, Result.BLOCKED)

    def test_cross_domain_rejected(self):
        with self.assertRaises(ValueError):
            assess(self.policy, self.observation(), Tick("other", 1))

    def test_unknown_action_is_not_consistent(self):
        observation = Observation("unlisted", frozenset(), 0, ())
        result = assess(self.policy, observation, self.tick(1))
        self.assertIs(result.result, Result.INCOMPLETE)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Provide exactly one research policy YAML path.")
    source = Path(sys.argv[1]).read_text(encoding="utf-8")
    RoutingTests.policy = load_policy(source)
    unittest.main(argv=[sys.argv[0]])

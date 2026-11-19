# SPDX-License-Identifier: MIT OR Apache-2.0
"""Ordinary correction intake without identity or contribution gates."""

from dataclasses import dataclass
from enum import Enum
from itertools import product


ENGINE_VERSION = "1.0.0"


class Topic(Enum):
    RECORD_ERROR = "record_error"
    SUPPORT_GAP = "support_gap"
    UNCLEAR = "unclear"


class Route(Enum):
    ASSISTED_DIGITAL = "assisted_digital"
    HUMAN_SUPPORTED = "human_supported"
    OFFLINE = "offline"


@dataclass(frozen=True)
class Request:
    topic: Topic
    route: Route
    message: str | None


def intake(request):
    """Accept ordinary intake for human review, not a merits determination.

    The selected route is a requested route, not confirmed service delivery.
    Message presentation is not used to assess competence or standing.
    """
    if (
        type(request) is not Request
        or type(request.topic) is not Topic
        or type(request.route) is not Route
    ):
        raise ValueError("typed request, topic, and route required")
    if request.message is not None and type(request.message) is not str:
        raise ValueError("message must be plain text or absent")

    needs_clarification = (
        request.topic is Topic.UNCLEAR
        or request.message is None
        or not request.message.strip()
    )

    return {
        "engine_version": ENGINE_VERSION,
        "ordinary_intake": "accepted_for_human_review",
        "selected_route": request.route.value,
        "clarification": (
            "offer_without_removing_intake"
            if needs_clarification
            else "available_if_requested"
        ),
        "merits": "not_determined",
        "proof_of_self_description": "not_required",
        "standing": "not_scored",
        "ordinary_support": "not_conditioned_on_contribution",
        "external_action_authorized": False,
    }


@dataclass(frozen=True)
class Fixture:
    """Synthetic test context only; not an operational intake envelope."""
    request: Request
    private_self_description: str
    contribution_kind: str


def baseline(fixture):
    return intake(fixture.request)


def grammar_mutant(fixture):
    result = baseline(fixture)
    message = fixture.request.message
    if message and message.startswith("fix fix"):
        result["ordinary_intake"] = "rejected"
    return result


def identity_mutant(fixture):
    result = baseline(fixture)
    if (
        fixture.private_self_description
        == "voluntary cybernetic-host description"
    ):
        result["proof_of_self_description"] = "required"
    return result


def contribution_mutant(fixture):
    result = baseline(fixture)
    if fixture.contribution_kind == "no_contribution":
        result["ordinary_support"] = "reduced"
    return result


def run_checks():
    messages = (
        "Please correct this record.",
        "fix fix record wrong please",
        "record correction ... please",
        None,
    )
    descriptions = (
        "not_supplied",
        "voluntary cybernetic-host description",
        "another voluntary description",
    )
    forms = ("no_contribution", "time", "knowledge", "access")
    combinations = 0

    for topic, route, message, description, form in product(
        Topic, Route, messages, descriptions, forms
    ):
        request = Request(topic, route, message)
        fixture = Fixture(request, description, form)
        result = baseline(fixture)

        if result != intake(request):
            raise RuntimeError("private context altered baseline intake")
        if result["ordinary_intake"] != "accepted_for_human_review":
            raise RuntimeError("ordinary intake was denied")
        if result["standing"] != "not_scored":
            raise RuntimeError("person-level standing was introduced")
        if (
            description != "not_supplied"
            and description in str(result)
        ):
            raise RuntimeError("private self-description leaked")

        combinations += 1

    detected = {}
    candidates = (
        ("grammar_penalty", grammar_mutant),
        ("self_description_proof_gate", identity_mutant),
        ("contribution_gate", contribution_mutant),
    )
    for name, candidate in candidates:
        found = False
        for message, description, form in product(
            messages, descriptions, forms
        ):
            fixture = Fixture(
                Request(Topic.RECORD_ERROR, Route.OFFLINE, message),
                description,
                form,
            )
            if candidate(fixture) != baseline(fixture):
                found = True
                break
        detected[name] = found

    if not all(detected.values()):
        raise RuntimeError("a supplied negative control survived")

    return {
        "engine_version": ENGINE_VERSION,
        "fixture_combinations": combinations,
        "negative_controls_detected": detected,
        "human_triage_bias_measured": False,
        "route_delivery_validated": False,
        "external_action_authorized": False,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run_checks(), sort_keys=True, indent=2))

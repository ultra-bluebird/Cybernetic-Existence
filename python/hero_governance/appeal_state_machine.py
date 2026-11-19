from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from enum import Enum


class AppealState(str, Enum):
    NOTICE_ISSUED = "notice_issued"
    EVIDENCE_ACCESS_OPEN = "evidence_access_open"
    APPEAL_FILED = "appeal_filed"
    CONFLICT_SCREENING = "conflict_screening"
    PANEL_CONSTITUTED = "panel_constituted"
    EVIDENCE_EXCHANGE = "evidence_exchange"
    ACCESSIBLE_HEARING = "accessible_hearing"
    DELIBERATION = "deliberation"
    DECISION_ISSUED = "decision_issued"
    SECONDARY_APPEAL_FILED = "secondary_appeal_filed"
    INDEPENDENT_REVIEW = "independent_review"
    CORRECTION_IMPLEMENTED = "correction_implemented"
    CLOSED = "closed"


class ActionType(str, Enum):
    REVOCATION = "revocation"
    DOWNGRADE = "downgrade"
    MISREPRESENTATION_CORRECTION = "misrepresentation_correction"


@dataclass(frozen=True)
class PanelMember:
    role: str
    conflict_disclosed: bool
    conflict_requires_recusal: bool
    accessibility_training_complete: bool
    was_involved_in_initial_action: bool


@dataclass
class AppealCase:
    case_reference: str
    action_type: ActionType
    opened_at: datetime
    state: AppealState = AppealState.NOTICE_ISSUED
    evidence_access_provided: bool = False
    appeal_received_at: datetime | None = None
    accessible_accommodations_confirmed: bool = False
    panel: list[PanelMember] = field(default_factory=list)
    decision_reason_provided: bool = False
    correction_completed: bool = False
    history: list[str] = field(default_factory=list)


class AppealWorkflow:
    def issue_notice(
        self,
        case: AppealCase,
        now: datetime,
        plain_language_reason_present: bool,
        evidence_index_present: bool,
        accessible_format_available: bool,
    ) -> None:
        self._require_state(case, AppealState.NOTICE_ISSUED)
        self._require_aware(now)

        if not plain_language_reason_present:
            raise ValueError("Notice requires a plain-language reason.")
        if not evidence_index_present:
            raise ValueError("Notice requires an evidence index.")
        if not accessible_format_available:
            raise ValueError("Notice requires an accessible format.")

        case.state = AppealState.EVIDENCE_ACCESS_OPEN
        case.history.append(
            f"{now.isoformat()}: notice validated and evidence access opened."
        )

    def file_appeal(
        self,
        case: AppealCase,
        now: datetime,
        accessible_submission_confirmed: bool,
        extension_granted: bool = False,
    ) -> None:
        self._require_state(case, AppealState.EVIDENCE_ACCESS_OPEN)
        self._require_aware(now)

        deadline = case.opened_at + timedelta(days=30)
        if now > deadline and not extension_granted:
            raise ValueError(
                "Appeal filing is outside the configured window and has no approved extension."
            )
        if not accessible_submission_confirmed:
            raise ValueError("Appeal intake must be accessible.")

        case.appeal_received_at = now
        case.state = AppealState.APPEAL_FILED
        case.history.append(f"{now.isoformat()}: appeal filed.")

    def screen_conflicts(
        self,
        case: AppealCase,
        now: datetime,
        proposed_panel: list[PanelMember],
    ) -> None:
        self._require_state(case, AppealState.APPEAL_FILED)
        self._require_aware(now)

        if len(proposed_panel) < 3:
            raise ValueError("A neutral review panel requires at least three members.")

        for member in proposed_panel:
            if not member.role.strip():
                raise ValueError("Each panel member requires a stated role.")
            if not member.conflict_disclosed:
                raise ValueError("Each panel member must disclose conflicts.")
            if member.conflict_requires_recusal:
                raise ValueError("A conflicted panel member must be recused.")
            if member.was_involved_in_initial_action:
                raise ValueError(
                    "A person involved in the initial action may not review the appeal."
                )
            if not member.accessibility_training_complete:
                raise ValueError(
                    "Panel members must complete accessibility-process training."
                )

        case.panel = list(proposed_panel)
        case.state = AppealState.PANEL_CONSTITUTED
        case.history.append(
            f"{now.isoformat()}: conflict screen completed and neutral panel constituted."
        )

    def exchange_evidence(
        self,
        case: AppealCase,
        now: datetime,
        evidence_access_provided: bool,
        accommodations_confirmed: bool,
    ) -> None:
        self._require_state(case, AppealState.PANEL_CONSTITUTED)
        self._require_aware(now)

        if not evidence_access_provided:
            raise ValueError("Evidence access is required before review.")
        if not accommodations_confirmed:
            raise ValueError("Accessible accommodations must be confirmed.")

        case.evidence_access_provided = True
        case.accessible_accommodations_confirmed = True
        case.state = AppealState.EVIDENCE_EXCHANGE
        case.history.append(f"{now.isoformat()}: evidence exchange completed.")

    def begin_hearing_or_written_review(
        self,
        case: AppealCase,
        now: datetime,
    ) -> None:
        self._require_state(case, AppealState.EVIDENCE_EXCHANGE)
        self._require_aware(now)

        if not case.evidence_access_provided:
            raise ValueError("Evidence access is required.")
        if not case.accessible_accommodations_confirmed:
            raise ValueError("Accessible review conditions are required.")

        case.state = AppealState.ACCESSIBLE_HEARING
        case.history.append(
            f"{now.isoformat()}: accessible hearing or written review began."
        )

    def issue_decision(
        self,
        case: AppealCase,
        now: datetime,
        decision_reason_provided: bool,
        rule_basis_provided: bool,
        evidence_basis_provided: bool,
        further_review_route_provided: bool,
    ) -> None:
        self._require_state(case, AppealState.ACCESSIBLE_HEARING)
        self._require_aware(now)

        if not all(
            (
                decision_reason_provided,
                rule_basis_provided,
                evidence_basis_provided,
                further_review_route_provided,
            )
        ):
            raise ValueError(
                "A decision requires reasons, rule basis, evidence basis, and review route."
            )

        case.decision_reason_provided = True
        case.state = AppealState.DECISION_ISSUED
        case.history.append(f"{now.isoformat()}: reasoned decision issued.")

    def implement_correction(
        self,
        case: AppealCase,
        now: datetime,
        correction_completed: bool,
    ) -> None:
        self._require_state(case, AppealState.DECISION_ISSUED)
        self._require_aware(now)

        if not correction_completed:
            raise ValueError("Case cannot close before required correction is completed.")

        case.correction_completed = True
        case.state = AppealState.CORRECTION_IMPLEMENTED
        case.history.append(f"{now.isoformat()}: correction implemented.")

        case.state = AppealState.CLOSED
        case.history.append(f"{now.isoformat()}: case closed.")

    @staticmethod
    def _require_state(case: AppealCase, expected: AppealState) -> None:
        if case.state is not expected:
            raise ValueError(
                f"Expected state '{expected.value}', found '{case.state.value}'."
            )

    @staticmethod
    def _require_aware(value: datetime) -> None:
        if value.tzinfo is None:
            raise ValueError("All workflow timestamps must be timezone-aware.")
        value.astimezone(timezone.utc)

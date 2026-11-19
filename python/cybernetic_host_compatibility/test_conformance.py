import unittest

from conformance import (
    CompatibilitySession,
    ConformanceAttempt,
    IntentRequest,
    IntentStatus,
    SessionStatus,
    compatibility_score,
    fallback_score,
    meets_baseline_conformance,
)


class CompatibilitySessionTests(unittest.TestCase):
    def test_allowlisted_intent_is_accepted(self) -> None:
        session = CompatibilitySession.begin(now=0.0)

        response = session.handle(
            IntentRequest(
                protocol="chcs.intent.v1",
                session_nonce=session.nonce,
                intent="focus-next",
                sequence=0,
                issued_at_monotonic_ms=1,
            ),
            now=0.1,
        )

        self.assertEqual(response.status, IntentStatus.ACCEPTED)

    def test_unallowlisted_intent_is_rejected(self) -> None:
        session = CompatibilitySession.begin(now=0.0)

        response = session.handle(
            IntentRequest(
                protocol="chcs.intent.v1",
                session_nonce=session.nonce,
                intent="host-stimulation",
                sequence=0,
                issued_at_monotonic_ms=1,
            ),
            now=0.1,
        )

        self.assertEqual(response.status, IntentStatus.REJECTED)

    def test_replayed_sequence_is_rejected(self) -> None:
        session = CompatibilitySession.begin(now=0.0)

        request = IntentRequest(
            protocol="chcs.intent.v1",
            session_nonce=session.nonce,
            intent="activate",
            sequence=0,
            issued_at_monotonic_ms=1,
        )

        self.assertEqual(
            session.handle(request, now=0.1).status,
            IntentStatus.ACCEPTED,
        )

        self.assertEqual(
            session.handle(request, now=0.2).status,
            IntentStatus.REJECTED,
        )

    def test_start_over_clears_session(self) -> None:
        session = CompatibilitySession.begin(now=0.0)

        response = session.handle(
            IntentRequest(
                protocol="chcs.intent.v1",
                session_nonce=session.nonce,
                intent="start-over",
                sequence=0,
                issued_at_monotonic_ms=1,
            ),
            now=0.1,
        )

        self.assertEqual(response.status, IntentStatus.SESSION_ENDED)
        self.assertEqual(session.status, SessionStatus.ENDED)
        self.assertEqual(session.nonce, "")

    def test_timeout_returns_to_fallback(self) -> None:
        session = CompatibilitySession.begin(now=0.0)

        response = session.handle(
            IntentRequest(
                protocol="chcs.intent.v1",
                session_nonce=session.nonce,
                intent="activate",
                sequence=0,
                issued_at_monotonic_ms=61_000,
            ),
            now=61.0,
        )

        self.assertEqual(response.status, IntentStatus.FALLBACK_AVAILABLE)
        self.assertEqual(session.status, SessionStatus.ENDED)


class ConformanceMetricTests(unittest.TestCase):
    def test_scores_are_computed(self) -> None:
        attempts = [
            ConformanceAttempt(
                mode="touch",
                task="activate-control",
                successful=True,
            ),
            ConformanceAttempt(
                mode="keyboard",
                task="activate-control",
                successful=True,
            ),
            ConformanceAttempt(
                mode="optional-assistive-intent",
                task="activate-control",
                successful=True,
            ),
            ConformanceAttempt(
                mode="standard-controls-after-link-loss",
                task="restart-with-standard-controls",
                successful=True,
                augmentation_failure_case=True,
                fallback_successful=True,
            ),
        ]

        self.assertEqual(compatibility_score(attempts), 1.0)
        self.assertEqual(fallback_score(attempts), 1.0)
        self.assertTrue(meets_baseline_conformance(attempts))

    def test_failed_fallback_fails_conformance(self) -> None:
        attempts = [
            ConformanceAttempt(
                mode="touch",
                task="reach-home",
                successful=True,
            ),
            ConformanceAttempt(
                mode="standard-controls-after-link-loss",
                task="restart-with-standard-controls",
                successful=False,
                augmentation_failure_case=True,
                fallback_successful=False,
            ),
        ]

        self.assertEqual(fallback_score(attempts), 0.0)
        self.assertFalse(meets_baseline_conformance(attempts))


if __name__ == "__main__":
    unittest.main()

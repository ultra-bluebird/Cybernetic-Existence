package org.augmentedhub.biocompatibility;

import java.util.List;

public final class PrivateBiocompatibilityLedgerAcceptanceTest {
    private PrivateBiocompatibilityLedgerAcceptanceTest() {
    }

    public static void main(final String[] args) {
        testLocalAppendAndRead();
        testCorrectionCreatesSuccessor();
        testDeletionControl();
        testNoCloudDependency();
        testNoExternalExport();
        testNoGovernanceIdentifierStorage();
        testNoMedicalInference();
        testNoMachineControl();
        testProhibitedContentRejected();
        System.out.println("private biocompatibility ledger acceptance tests passed");
    }

    private static void testLocalAppendAndRead() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        final LedgerResult result = ledger.append(
            "Prepare a clinician discussion question.",
            "general_reference",
            "An externally observable warning was recorded after a documented material exposure.",
            EvidencePolarity.INCONCLUSIVE,
            EvidenceQuality.PROVISIONAL,
            null
        );

        require(result instanceof LedgerResult.Accepted,
            "local append must accept a bounded non-diagnostic entry");

        final List<EvidenceEntry> entries = ledger.readLocalEntries();
        require(entries.size() == 1, "accepted entry must remain locally readable");
    }

    private static void testCorrectionCreatesSuccessor() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        final LedgerResult first = ledger.append(
            "Document an observable concern.",
            "user_observation",
            "Observed external redness in the documented contact area.",
            EvidencePolarity.DETECTED,
            EvidenceQuality.PROVISIONAL,
            null
        );

        require(first instanceof LedgerResult.Accepted,
            "initial observation must be accepted");

        final EvidenceEntry original = ((LedgerResult.Accepted) first).getEntry();

        final LedgerResult correction = ledger.correct(
            original.getEntryId(),
            "Correct the observation timing.",
            "user_observation",
            "Observed external redness in the documented contact area on a corrected date.",
            EvidencePolarity.DETECTED,
            EvidenceQuality.PROVISIONAL
        );

        require(correction instanceof LedgerResult.Accepted,
            "correction must create a successor entry");

        final EvidenceEntry corrected = ((LedgerResult.Accepted) correction).getEntry();
        require(original.getEntryId().equals(corrected.getCorrectedByEntryId()),
            "correction must retain predecessor linkage");
    }

    private static void testDeletionControl() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        ledger.append(
            "Temporary private note.",
            "user_observation",
            "A non-diagnostic observation for local review.",
            EvidencePolarity.NOT_MEASURED,
            EvidenceQuality.PROVISIONAL,
            null
        );

        require(ledger.deleteLocally(), "local deletion control must succeed");
        require(ledger.readLocalEntries().isEmpty(),
            "local deletion must remove locally held entries");

        final LedgerResult afterDeletion = ledger.append(
            "Attempt after deletion.",
            "general_reference",
            "No new record should be accepted after local deletion.",
            EvidencePolarity.NOT_APPLICABLE,
            EvidenceQuality.ACCEPTED,
            null
        );

        require(afterDeletion instanceof LedgerResult.Rejected,
            "deleted ledger must reject further writes until explicitly recreated");
    }

    private static void testNoCloudDependency() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        require(!ledger.supportsCloudExport(),
            "critical path must not require cloud export");
    }

    private static void testNoExternalExport() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        require(!ledger.supportsTelemetryExport(),
            "telemetry export must be disabled");
        require(!ledger.supportsTrainingExport(),
            "training export must be disabled");
    }

    private static void testNoGovernanceIdentifierStorage() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        require(!ledger.storesGovernanceIdentifier(),
            "ledger must not store governance identifiers");
    }

    private static void testNoMedicalInference() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        require(!ledger.generatesMedicalInference(),
            "ledger must not generate medical inference");
    }

    private static void testNoMachineControl() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        require(!ledger.supportsMachineControl(),
            "ledger must not support machine control");
    }

    private static void testProhibitedContentRejected() {
        final PrivateBiocompatibilityLedger ledger =
            new PrivateBiocompatibilityLedger();

        final LedgerResult result = ledger.append(
            "Attempt to add prohibited content.",
            "user_observation",
            "This content attempts to reference a governance identifier.",
            EvidencePolarity.INCONCLUSIVE,
            EvidenceQuality.PROVISIONAL,
            null
        );

        require(result instanceof LedgerResult.Rejected,
            "identity or governance reference content must be rejected");
    }

    private static void require(final boolean condition, final String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}

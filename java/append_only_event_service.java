package org.augmentedhub.events;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Objects;
import java.util.UUID;

public final class AppendOnlyEventService {
    public interface ValidationGate {
        ValidationOutcome validate(EventCommand command);
    }

    public interface EventLedger {
        EventHead loadHead(String aggregateReference);
        StoredEvent append(AppendRequest request);
    }

    public interface AuditWriter {
        String record(AuditEntry entry);
    }

    public record EventCommand(
            String aggregateReference,
            long expectedSequence,
            String eventType,
            byte[] canonicalPayload,
            String purposeReference,
            String policyRevision,
            Instant clientObservedAt
    ) {
        public EventCommand {
            Objects.requireNonNull(aggregateReference, "aggregateReference");
            Objects.requireNonNull(eventType, "eventType");
            Objects.requireNonNull(canonicalPayload, "canonicalPayload");
            Objects.requireNonNull(purposeReference, "purposeReference");
            Objects.requireNonNull(policyRevision, "policyRevision");

            if (aggregateReference.isBlank()
                    || eventType.isBlank()
                    || canonicalPayload.length == 0
                    || canonicalPayload.length > 65_536
                    || purposeReference.isBlank()
                    || policyRevision.isBlank()
                    || expectedSequence < 0) {
                throw new IllegalArgumentException("Event command contains invalid values.");
            }
        }
    }

    public record ValidationOutcome(
            Decision decision,
            String code,
            String accessibleExplanation,
            String policyDecisionDigest
    ) {
        public ValidationOutcome {
            Objects.requireNonNull(decision, "decision");
            Objects.requireNonNull(code, "code");
            Objects.requireNonNull(accessibleExplanation, "accessibleExplanation");
            Objects.requireNonNull(policyDecisionDigest, "policyDecisionDigest");
        }
    }

    public enum Decision {
        ACCEPT,
        REJECT,
        HUMAN_REVIEW_REQUIRED
    }

    public record EventHead(long sequence, String eventDigest) {
        public EventHead {
            if (sequence < -1) {
                throw new IllegalArgumentException("Head sequence must be at least -1.");
            }
        }
    }

    public record AppendRequest(
            String eventReference,
            String aggregateReference,
            long sequence,
            String eventType,
            byte[] canonicalPayload,
            String previousEventDigest,
            String eventDigest,
            String purposeReference,
            String policyRevision,
            String policyDecisionDigest,
            Instant clientObservedAt,
            Instant recordedAt
    ) {}

    public record StoredEvent(
            String eventReference,
            long sequence,
            String eventDigest,
            Instant recordedAt
    ) {}

    public record AuditEntry(
            String aggregateReference,
            String eventReference,
            String eventType,
            Decision validationDecision,
            String policyDecisionDigest,
            Instant recordedAt
    ) {}

    public record ServiceResult(
            Decision decision,
            String eventReference,
            String eventDigest,
            String auditRecordReference,
            String code,
            String accessibleExplanation
    ) {}

    private final ValidationGate validationGate;
    private final EventLedger ledger;
    private final AuditWriter auditWriter;

    public AppendOnlyEventService(
            ValidationGate validationGate,
            EventLedger ledger,
            AuditWriter auditWriter) {

        this.validationGate = Objects.requireNonNull(validationGate, "validationGate");
        this.ledger = Objects.requireNonNull(ledger, "ledger");
        this.auditWriter = Objects.requireNonNull(auditWriter, "auditWriter");
    }

    public ServiceResult append(EventCommand command, Instant now) {
        Objects.requireNonNull(command, "command");
        Objects.requireNonNull(now, "now");

        ValidationOutcome validation = validationGate.validate(command);

        if (validation.decision() != Decision.ACCEPT) {
            String auditReference = auditWriter.record(new AuditEntry(
                    command.aggregateReference(),
                    null,
                    command.eventType(),
                    validation.decision(),
                    validation.policyDecisionDigest(),
                    now));

            return new ServiceResult(
                    validation.decision(),
                    null,
                    null,
                    auditReference,
                    validation.code(),
                    validation.accessibleExplanation());
        }

        EventHead head = ledger.loadHead(command.aggregateReference());

        if (head.sequence() != command.expectedSequence() - 1) {
            String auditReference = auditWriter.record(new AuditEntry(
                    command.aggregateReference(),
                    null,
                    command.eventType(),
                    Decision.HUMAN_REVIEW_REQUIRED,
                    validation.policyDecisionDigest(),
                    now));

            return new ServiceResult(
                    Decision.HUMAN_REVIEW_REQUIRED,
                    null,
                    null,
                    auditReference,
                    "SEQUENCE_CONFLICT",
                    "The correction record changed before this update was saved. "
                            + "Please review the current case state and try again.");
        }

        String eventReference = UUID.randomUUID().toString();
        String previousDigest = head.sequence() < 0 ? null : head.eventDigest();

        String digest = digestEvent(
                eventReference,
                command.aggregateReference(),
                command.expectedSequence(),
                command.eventType(),
                command.canonicalPayload(),
                previousDigest,
                command.purposeReference(),
                command.policyRevision(),
                validation.policyDecisionDigest());

        StoredEvent stored = ledger.append(new AppendRequest(
                eventReference,
                command.aggregateReference(),
                command.expectedSequence(),
                command.eventType(),
                command.canonicalPayload(),
                previousDigest,
                digest,
                command.purposeReference(),
                command.policyRevision(),
                validation.policyDecisionDigest(),
                command.clientObservedAt(),
                now));

        String auditReference = auditWriter.record(new AuditEntry(
                command.aggregateReference(),
                stored.eventReference(),
                command.eventType(),
                Decision.ACCEPT,
                validation.policyDecisionDigest(),
                now));

        return new ServiceResult(
                Decision.ACCEPT,
                stored.eventReference(),
                stored.eventDigest(),
                auditReference,
                "EVENT_ACCEPTED",
                "The correction event was recorded in the append-only case history.");
    }

    private static String digestEvent(
            String eventReference,
            String aggregateReference,
            long sequence,
            String eventType,
            byte[] payload,
            String previousDigest,
            String purposeReference,
            String policyRevision,
            String policyDecisionDigest) {

        String canonical = String.join("\u001f",
                eventReference,
                aggregateReference,
                Long.toString(sequence),
                eventType,
                HexFormat.of().formatHex(payload),
                previousDigest == null ? "" : previousDigest,
                purposeReference,
                policyRevision,
                policyDecisionDigest);

        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(canonical.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable.", exception);
        }
    }
}

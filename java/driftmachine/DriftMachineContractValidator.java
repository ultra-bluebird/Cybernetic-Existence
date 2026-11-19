package driftmachine;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

public final class DriftMachineContractValidator {
    private static final Pattern SEMVER = Pattern.compile(
        "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
    );

    private static final Pattern TOKEN = Pattern.compile("^[A-Za-z0-9._:-]+$");

    private static final Set<String> STATES = Set.of(
        "INITIALIZING",
        "OPERATIONAL",
        "REVIEW_REQUIRED",
        "LOCKED_OUT",
        "MAINTENANCE_HOLD"
    );

    private static final Set<String> REVIEW_STATUSES = Set.of(
        "NOT_REQUIRED",
        "PENDING",
        "IN_REVIEW",
        "COMPLETE",
        "APPEALED"
    );

    private static final Set<String> DECISION_CODES = Set.of(
        "INITIALIZATION_SUCCESS",
        "INITIALIZATION_FAILURE",
        "EVIDENCE_ACCEPTED",
        "EVIDENCE_VALIDATION_REVIEW",
        "LOW_CONFIDENCE_REVIEW",
        "UNSUPPORTED_EVENT_REVIEW",
        "CRITICAL_FAILURE_LOCKOUT",
        "REVIEW_ESCALATED_TO_LOCKOUT",
        "REVIEW_TIMEOUT_LOCKOUT",
        "REVIEW_APPROVED",
        "REVIEW_NOT_APPROVED",
        "EVENT_DEFERRED_PENDING_REVIEW",
        "RECOVERY_CASE_OPENED",
        "SYSTEM_RESTORED",
        "LOCKOUT_RETAINED",
        "MAINTENANCE_HOLD_ENTERED",
        "MAINTENANCE_HOLD_RETAINED",
        "MAINTENANCE_RELEASED",
        "STATE_MISMATCH"
    );

    private static final Set<String> INTEGRITY_STATUSES = Set.of(
        "VALID",
        "INVALID",
        "STALE",
        "UNVERIFIABLE",
        "SCHEMA_MISMATCH"
    );

    private DriftMachineContractValidator() {
    }

    public record ContractResult(boolean accepted, String reasonCode, String explanation) {
    }

    public static ContractResult validate(Map<String, Object> payload) {
        if (payload == null) {
            return reject("CONTRACT_NULL", "The transition output is missing.");
        }

        String eventId = string(payload, "event_id");
        String transitionId = string(payload, "transition_id");
        String timestampUtc = string(payload, "timestamp_utc");
        String inputSchemaVersion = string(payload, "input_schema_version");
        String policyVersion = string(payload, "policy_version");
        String currentState = string(payload, "current_state");
        String nextState = string(payload, "next_state");
        String decisionCode = string(payload, "decision_code");
        String reviewStatus = string(payload, "human_review_status");

        if (!uuid(eventId) || !uuid(transitionId)) {
            return reject("CONTRACT_INVALID_IDENTIFIER", "The event or transition identifier is invalid.");
        }
        if (!timestamp(timestampUtc)) {
            return reject("CONTRACT_INVALID_TIMESTAMP", "The transition timestamp is invalid.");
        }
        if (!semver(inputSchemaVersion) || !semver(policyVersion)) {
            return reject("CONTRACT_INCOMPATIBLE_VERSION", "The schema or policy version is invalid.");
        }
        if (!STATES.contains(currentState) || !STATES.contains(nextState)) {
            return reject("CONTRACT_UNKNOWN_STATE", "The transition contains an unknown state.");
        }
        if (!DECISION_CODES.contains(decisionCode)) {
            return reject("CONTRACT_UNKNOWN_DECISION", "The transition contains an unknown advisory decision code.");
        }
        if (!REVIEW_STATUSES.contains(reviewStatus)) {
            return reject("CONTRACT_UNKNOWN_REVIEW_STATUS", "The transition contains an unknown review status.");
        }
        if (!(payload.get("external_action_authorized") instanceof Boolean authorized) || authorized) {
            return reject("CONTRACT_ACTUATION_PROHIBITED", "The output must not authorize an external action.");
        }

        Object explanationValue = payload.get("explanation");
        if (!(explanationValue instanceof Map<?, ?> rawExplanation)) {
            return reject("CONTRACT_MISSING_EXPLANATION", "The output lacks a valid explanation.");
        }
        if (!boundedReason(rawExplanation.get("reason_code")) || !boundedText(rawExplanation.get("plain_language"), 240)) {
            return reject("CONTRACT_INVALID_EXPLANATION", "The explanation code or plain-language text is invalid.");
        }

        Object provenanceValue = payload.get("provenance");
        if (!(provenanceValue instanceof Map<?, ?> rawProvenance)) {
            return reject("CONTRACT_MISSING_PROVENANCE", "The output lacks required provenance.");
        }

        if (!uuid(asString(rawProvenance.get("audit_event_id"))) ||
            !nullableToken(rawProvenance.get("evidence_reference"), 128) ||
            !token(asString(rawProvenance.get("policy_id")), 3, 128) ||
            !token(asString(rawProvenance.get("input_schema_id")), 3, 128) ||
            !nullableToken(rawProvenance.get("review_case_id"), 128) ||
            !INTEGRITY_STATUSES.contains(asString(rawProvenance.get("input_integrity_status")))) {
            return reject("CONTRACT_INVALID_PROVENANCE", "The output provenance is missing or invalid.");
        }

        if ("LOCKED_OUT".equals(nextState) &&
            "NOT_REQUIRED".equals(reviewStatus)) {
            return reject("CONTRACT_LOCKOUT_REVIEW_REQUIRED", "A lockout output requires a review status.");
        }

        if ("SYSTEM_RESTORED".equals(decisionCode) &&
            (!"LOCKED_OUT".equals(currentState) ||
             !"OPERATIONAL".equals(nextState) ||
             !"COMPLETE".equals(reviewStatus))) {
            return reject("CONTRACT_INVALID_RECOVERY", "A restoration output requires verified recovery from lockout.");
        }

        return new ContractResult(true, "CONTRACT_ACCEPTED", "The DriftMachine transition output is contract-valid.");
    }

    private static ContractResult reject(String reasonCode, String explanation) {
        return new ContractResult(false, reasonCode, explanation);
    }

    private static String string(Map<String, Object> payload, String key) {
        Object value = payload.get(key);
        return value instanceof String text ? text : "";
    }

    private static String asString(Object value) {
        return value instanceof String text ? text : "";
    }

    private static boolean uuid(String value) {
        try {
            UUID.fromString(value);
            return true;
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    private static boolean timestamp(String value) {
        try {
            Instant.parse(value);
            return true;
        } catch (DateTimeParseException exception) {
            return false;
        }
    }

    private static boolean semver(String value) {
        return SEMVER.matcher(value).matches();
    }

    private static boolean token(String value, int minimum, int maximum) {
        return value.length() >= minimum &&
            value.length() <= maximum &&
            TOKEN.matcher(value).matches();
    }

    private static boolean nullableToken(Object value, int maximum) {
        return value == null ||
            (value instanceof String text &&
             text.length() <= maximum &&
             (text.isEmpty() || TOKEN.matcher(text).matches()));
    }

    private static boolean boundedReason(Object value) {
        return value instanceof String text &&
            text.length() >= 3 &&
            text.length() <= 80 &&
            text.matches("^[A-Z][A-Z0-9_]{2,79}$");
    }

    private static boolean boundedText(Object value, int maximum) {
        return value instanceof String text &&
            !text.isBlank() &&
            text.length() <= maximum;
    }
}

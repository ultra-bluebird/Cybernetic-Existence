const RETENTION_MODES = Object.freeze([
  "disabled",
  "session_only",
  "local_expiring",
  "until_deleted"
]);

const CURRENT_FEELINGS = Object.freeze([
  "comfortable",
  "uncertain",
  "giving_more_than_i_want",
  "receiving_more_than_i_want",
  "mutual_enough_for_me",
  "not_sure",
  "prefer_not_to_answer"
]);

const NEXT_STEPS = Object.freeze([
  "continue_as_is",
  "ask_for_clarity",
  "set_a_boundary",
  "pause",
  "exit",
  "reflect_later",
  "none"
]);

const MAXIMUM_LABEL_LENGTH = 120;
const MAXIMUM_NOTE_LENGTH = 2400;

function assertOneOf(value, allowedValues, fieldName) {
  if (!allowedValues.includes(value)) {
    throw new RangeError(
      `${fieldName} must be one of: ${allowedValues.join(", ")}.`
    );
  }

  return value;
}

function normalizeOptionalString(value, fieldName, maximumLength) {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be a string when provided.`);
  }

  if (value.length > maximumLength) {
    throw new RangeError(
      `${fieldName} cannot exceed ${maximumLength} characters.`
    );
  }

  return value;
}

function normalizeExpiry(expiresAt) {
  if (expiresAt === null || expiresAt === undefined) {
    return null;
  }

  const parsed = new Date(expiresAt);

  if (Number.isNaN(parsed.valueOf())) {
    throw new RangeError("expiresAt must be a valid ISO-8601 date-time.");
  }

  return parsed.toISOString();
}

function freezeClone(value) {
  return Object.freeze(structuredClone(value));
}

export class MutualityReflection {
  #clock;
  #entries = new Map();

  constructor({ clock = () => new Date() } = {}) {
    if (typeof clock !== "function") {
      throw new TypeError("clock must be a function.");
    }

    this.#clock = clock;
  }

  create({
    entryId,
    connectionLabel = "",
    currentFeeling = "prefer_not_to_answer",
    desiredChange = "",
    nextStep = "none",
    privateNote = "",
    retentionMode = "session_only",
    expiresAt = null
  }) {
    const normalizedRetentionMode = assertOneOf(
      retentionMode,
      RETENTION_MODES,
      "retentionMode"
    );

    if (normalizedRetentionMode === "disabled") {
      return Object.freeze({
        localOnly: true,
        saved: false,
        reminder: "Reflection is disabled. Nothing was stored."
      });
    }

    const normalizedEntryId = normalizeOptionalString(
      entryId,
      "entryId",
      MAXIMUM_LABEL_LENGTH
    );

    if (normalizedEntryId.length === 0) {
      throw new TypeError("entryId must be a non-empty string.");
    }

    if (this.#entries.has(normalizedEntryId)) {
      throw new Error(`A reflection entry already exists for "${normalizedEntryId}".`);
    }

    const normalizedExpiresAt = normalizeExpiry(expiresAt);

    if (
      normalizedRetentionMode === "local_expiring" &&
      normalizedExpiresAt === null
    ) {
      throw new Error("local_expiring reflections require expiresAt.");
    }

    if (
      normalizedRetentionMode !== "local_expiring" &&
      normalizedExpiresAt !== null
    ) {
      throw new Error("expiresAt is permitted only for local_expiring reflections.");
    }

    const entry = Object.freeze({
      entryId: normalizedEntryId,
      connectionLabel: normalizeOptionalString(
        connectionLabel,
        "connectionLabel",
        MAXIMUM_LABEL_LENGTH
      ),
      currentFeeling: assertOneOf(
        currentFeeling,
        CURRENT_FEELINGS,
        "currentFeeling"
      ),
      desiredChange: normalizeOptionalString(
        desiredChange,
        "desiredChange",
        MAXIMUM_NOTE_LENGTH
      ),
      nextStep: assertOneOf(nextStep, NEXT_STEPS, "nextStep"),
      privateNote: normalizeOptionalString(
        privateNote,
        "privateNote",
        MAXIMUM_NOTE_LENGTH
      ),
      createdAt: this.#clock().toISOString(),
      expiresAt: normalizedExpiresAt,
      localOnly: true,
      networkDisabled: true,
      counterpartReference: null,
      interactionReference: null,
      exportOnlyByUser: true
    });

    this.#entries.set(entry.entryId, entry);

    return this.summary(entry.entryId);
  }

  read(entryId) {
    const entry = this.#requireActiveEntry(entryId);
    return freezeClone(entry);
  }

  summary(entryId) {
    const entry = this.#requireActiveEntry(entryId);

    return freezeClone({
      entryId: entry.entryId,
      createdAt: entry.createdAt,
      expiresAt: entry.expiresAt,
      localOnly: true,
      networkDisabled: true,
      reminder:
        "This reflection is private to you. Hearthline does not receive it, compare it, score it, or use it to change discovery."
    });
  }

  delete(entryId) {
    const normalizedEntryId = normalizeOptionalString(
      entryId,
      "entryId",
      MAXIMUM_LABEL_LENGTH
    );

    const existed = this.#entries.delete(normalizedEntryId);

    return Object.freeze({
      entryId: normalizedEntryId,
      deleted: existed,
      deletedAt: this.#clock().toISOString(),
      localOnly: true
    });
  }

  clearAll() {
    const deletedCount = this.#entries.size;
    this.#entries.clear();

    return Object.freeze({
      deletedCount,
      deletedAt: this.#clock().toISOString(),
      localOnly: true
    });
  }

  #requireActiveEntry(entryId) {
    const normalizedEntryId = normalizeOptionalString(
      entryId,
      "entryId",
      MAXIMUM_LABEL_LENGTH
    );

    const entry = this.#entries.get(normalizedEntryId);

    if (!entry) {
      throw new Error(`No reflection entry exists for "${normalizedEntryId}".`);
    }

    if (
      entry.expiresAt !== null &&
      new Date(entry.expiresAt) <= this.#clock()
    ) {
      this.#entries.delete(normalizedEntryId);
      throw new Error(`Reflection entry "${normalizedEntryId}" has expired.`);
    }

    return entry;
  }
}

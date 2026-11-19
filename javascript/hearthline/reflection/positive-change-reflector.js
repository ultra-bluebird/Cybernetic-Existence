const RETENTION_MODES = Object.freeze([
  "disabled",
  "session_only",
  "local_expiring",
  "until_deleted",
  "export_only"
]);

const OPTIONAL_THEMES = Object.freeze([
  "communication",
  "boundaries",
  "connection",
  "activity",
  "privacy",
  "access",
  "pace",
  "rest",
  "other",
  "prefer_not_to_label"
]);

const OPTIONAL_NEXT_PREFERENCES = Object.freeze([
  "keep_current_approach",
  "try_something_small",
  "pause_for_now",
  "set_a_boundary",
  "ask_for_clarity",
  "seek_public_activity",
  "use_virtual_first",
  "reflect_later",
  "none",
  "prefer_not_to_label"
]);

const MAXIMUM_LABEL_LENGTH = 120;
const MAXIMUM_NOTE_LENGTH = 2400;

function assertOneOf(value, values, fieldName) {
  if (!values.includes(value)) {
    throw new RangeError(
      `${fieldName} must be one of: ${values.join(", ")}.`
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

function normalizeOptionalExpiry(expiresAt) {
  if (expiresAt === undefined || expiresAt === null) {
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

export class PositiveChangeReflector {
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
    dateLabel = "",
    changeNote = "",
    theme = "prefer_not_to_label",
    nextPreference = "none",
    futureNote = "",
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
        saved: false,
        localOnly: true,
        networkDisabled: true,
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
      throw new Error(`An entry already exists for "${normalizedEntryId}".`);
    }

    const normalizedExpiry = normalizeOptionalExpiry(expiresAt);

    if (
      normalizedRetentionMode === "local_expiring" &&
      normalizedExpiry === null
    ) {
      throw new Error("local_expiring entries require expiresAt.");
    }

    if (
      normalizedRetentionMode !== "local_expiring" &&
      normalizedExpiry !== null
    ) {
      throw new Error(
        "expiresAt is permitted only when retentionMode is local_expiring."
      );
    }

    const entry = Object.freeze({
      entryId: normalizedEntryId,
      dateLabel: normalizeOptionalString(
        dateLabel,
        "dateLabel",
        MAXIMUM_LABEL_LENGTH
      ),
      changeNote: normalizeOptionalString(
        changeNote,
        "changeNote",
        MAXIMUM_NOTE_LENGTH
      ),
      theme: assertOneOf(theme, OPTIONAL_THEMES, "theme"),
      nextPreference: assertOneOf(
        nextPreference,
        OPTIONAL_NEXT_PREFERENCES,
        "nextPreference"
      ),
      futureNote: normalizeOptionalString(
        futureNote,
        "futureNote",
        MAXIMUM_NOTE_LENGTH
      ),
      createdAt: this.#clock().toISOString(),
      expiresAt: normalizedExpiry,
      localOnly: true,
      networkDisabled: true,
      counterpartReference: null,
      profileReference: null,
      corridorReference: null,
      encounterReference: null,
      exportOnlyByUser: true
    });

    if (normalizedRetentionMode === "export_only") {
      return Object.freeze({
        saved: false,
        localOnly: true,
        networkDisabled: true,
        exportPayload: JSON.stringify(entry, null, 2),
        reminder:
          "This export is user-controlled. Hearthline does not retain a copy."
      });
    }

    this.#entries.set(entry.entryId, entry);

    return this.summary(entry.entryId);
  }

  read(entryId) {
    return freezeClone(this.#requireActiveEntry(entryId));
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
        "This is your private note. Hearthline does not receive it, compare it, score it, or use it to change discovery."
    });
  }

  delete(entryId) {
    const normalizedEntryId = normalizeOptionalString(
      entryId,
      "entryId",
      MAXIMUM_LABEL_LENGTH
    );

    const deleted = this.#entries.delete(normalizedEntryId);

    return Object.freeze({
      entryId: normalizedEntryId,
      deleted,
      deletedAt: this.#clock().toISOString(),
      localOnly: true,
      networkDisabled: true
    });
  }

  clearAll() {
    const deletedCount = this.#entries.size;
    this.#entries.clear();

    return Object.freeze({
      deletedCount,
      deletedAt: this.#clock().toISOString(),
      localOnly: true,
      networkDisabled: true
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

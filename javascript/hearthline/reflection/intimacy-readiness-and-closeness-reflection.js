const RETENTION_MODES = Object.freeze([
  "disabled",
  "session_only",
  "local_expiring",
  "until_deleted",
  "export_only"
]);

const CONNECTION_READINESS_STATES = Object.freeze([
  "private_reflection",
  "open_to_conversation",
  "exploring_in_my_own_time",
  "resting_from_connection",
  "not_discussing_now",
  "prefer_not_to_label"
]);

const CLOSENESS_REFLECTION_STATES = Object.freeze([
  "wanting_more_warmth",
  "wanting_quiet_company",
  "wanting_nonsexual_affection",
  "not_sure",
  "resting",
  "not_reflecting_now",
  "prefer_not_to_label"
]);

const MAXIMUM_NOTE_LENGTH = 1600;

function assertOneOf(value, allowedValues, fieldName) {
  if (!allowedValues.includes(value)) {
    throw new RangeError(
      `${fieldName} must be one of: ${allowedValues.join(", ")}.`
    );
  }

  return value;
}

function assertNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${fieldName} must be a non-empty string.`);
  }

  return value.trim();
}

function normalizeOptionalText(value, fieldName) {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be a string when provided.`);
  }

  if (value.length > MAXIMUM_NOTE_LENGTH) {
    throw new RangeError(
      `${fieldName} cannot exceed ${MAXIMUM_NOTE_LENGTH} characters.`
    );
  }

  return value;
}

function normalizeOptionalExpiry(value) {
  if (value === undefined || value === null) {
    return null;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.valueOf())) {
    throw new RangeError("expiresAt must be a valid ISO-8601 date-time.");
  }

  return parsed.toISOString();
}

function freezeClone(value) {
  return Object.freeze(structuredClone(value));
}

class LocalPrivateReflectionStore {
  #clock;
  #entries = new Map();

  constructor({ clock = () => new Date() } = {}) {
    if (typeof clock !== "function") {
      throw new TypeError("clock must be a function.");
    }

    this.#clock = clock;
  }

  save({
    entryId,
    state,
    stateVocabulary,
    note = "",
    retentionMode = "session_only",
    expiresAt = null,
    reminder
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
        reminder: "Private reflection is disabled. Nothing was stored."
      });
    }

    const normalizedEntryId = assertNonEmptyString(entryId, "entryId");
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
      state: assertOneOf(state, stateVocabulary, "state"),
      note: normalizeOptionalText(note, "note"),
      createdAt: this.#clock().toISOString(),
      expiresAt: normalizedExpiry,
      localOnly: true,
      networkDisabled: true,
      profileReference: null,
      counterpartReference: null,
      corridorReference: null,
      encounterReference: null,
      exportOnlyByUser: true,
      reminder
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

    this.#entries.set(normalizedEntryId, entry);
    return this.summary(normalizedEntryId);
  }

  read(entryId) {
    return freezeClone(this.#requireActiveEntry(entryId));
  }

  summary(entryId) {
    const entry = this.#requireActiveEntry(entryId);

    return freezeClone({
      entryId: entry.entryId,
      state: entry.state,
      createdAt: entry.createdAt,
      expiresAt: entry.expiresAt,
      localOnly: true,
      networkDisabled: true,
      reminder: entry.reminder
    });
  }

  delete(entryId) {
    const normalizedEntryId = assertNonEmptyString(entryId, "entryId");
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
    const normalizedEntryId = assertNonEmptyString(entryId, "entryId");
    const entry = this.#entries.get(normalizedEntryId);

    if (!entry) {
      throw new Error(`No private reflection entry exists for "${normalizedEntryId}".`);
    }

    if (
      entry.expiresAt !== null &&
      new Date(entry.expiresAt) <= this.#clock()
    ) {
      this.#entries.delete(normalizedEntryId);
      throw new Error(`Private reflection entry "${normalizedEntryId}" has expired.`);
    }

    return entry;
  }
}

export class IntimacyModeSelector {
  #store;

  constructor(options = {}) {
    this.#store = new LocalPrivateReflectionStore(options);
  }

  saveReadinessNote({
    entryId,
    state = "prefer_not_to_label",
    note = "",
    retentionMode = "session_only",
    expiresAt = null
  }) {
    return this.#store.save({
      entryId,
      state,
      stateVocabulary: CONNECTION_READINESS_STATES,
      note,
      retentionMode,
      expiresAt,
      reminder:
        "This is a private connection readiness note. It is not public availability, a match signal, consent, or a request for contact."
    });
  }

  read(entryId) {
    return this.#store.read(entryId);
  }

  delete(entryId) {
    return this.#store.delete(entryId);
  }

  clearAll() {
    return this.#store.clearAll();
  }
}

export class TouchHungerIndex {
  #store;

  constructor(options = {}) {
    this.#store = new LocalPrivateReflectionStore(options);
  }

  saveClosenessReflection({
    entryId,
    state = "prefer_not_to_label",
    note = "",
    retentionMode = "session_only",
    expiresAt = null
  }) {
    return this.#store.save({
      entryId,
      state,
      stateVocabulary: CLOSENESS_REFLECTION_STATES,
      note,
      retentionMode,
      expiresAt,
      reminder:
        "This is a private closeness reflection. It is not a score, diagnosis, match signal, consent record, or invitation for touch."
    });
  }

  read(entryId) {
    return this.#store.read(entryId);
  }

  delete(entryId) {
    return this.#store.delete(entryId);
  }

  clearAll() {
    return this.#store.clearAll();
  }
}

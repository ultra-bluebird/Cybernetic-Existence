const RETENTION_MODES = Object.freeze([
  "disabled",
  "session_only",
  "local_expiring",
  "until_deleted",
  "export_only"
]);

const PRIVACY_COMFORT_STATES = Object.freeze([
  "open_to_choose",
  "cautious",
  "private",
  "quiet_mode",
  "reconsidering",
  "not_reflecting_now",
  "prefer_not_to_label"
]);

const CHECK_IN_PREFERENCES = Object.freeze([
  "ask_directly",
  "text_first",
  "quiet_check_in",
  "i_will_raise_it",
  "not_discussing_now",
  "prefer_not_to_label"
]);

const EXIT_PREFERENCES = Object.freeze([
  "leave_independently",
  "public_place_first",
  "pause_and_reassess",
  "not_discussing_now",
  "prefer_not_to_label"
]);

const MAXIMUM_TEXT_LENGTH = 1600;

function assertNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new TypeError(`${fieldName} must be a non-empty string.`);
  }

  return value.trim();
}

function assertOneOf(value, allowedValues, fieldName) {
  if (!allowedValues.includes(value)) {
    throw new RangeError(
      `${fieldName} must be one of: ${allowedValues.join(", ")}.`
    );
  }

  return value;
}

function normalizeOptionalText(value, fieldName) {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be a string when provided.`);
  }

  if (value.length > MAXIMUM_TEXT_LENGTH) {
    throw new RangeError(
      `${fieldName} cannot exceed ${MAXIMUM_TEXT_LENGTH} characters.`
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

class LocalPrivateStore {
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
    payload,
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
      payload: structuredClone(payload),
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
      throw new Error(`No local private entry exists for "${normalizedEntryId}".`);
    }

    if (
      entry.expiresAt !== null &&
      new Date(entry.expiresAt) <= this.#clock()
    ) {
      this.#entries.delete(normalizedEntryId);
      throw new Error(`Local private entry "${normalizedEntryId}" has expired.`);
    }

    return entry;
  }
}

export class SafeWordRegistry {
  #store;

  constructor(options = {}) {
    this.#store = new LocalPrivateStore(options);
  }

  savePrivateCheckInPlan({
    entryId,
    checkInPhrase = "",
    pausePhrase = "",
    stopPhrase = "",
    nonverbalSignal = "",
    checkInPreference = "prefer_not_to_label",
    exitPreference = "prefer_not_to_label",
    privateReminder = "",
    retentionMode = "session_only",
    expiresAt = null
  }) {
    return this.#store.save({
      entryId,
      retentionMode,
      expiresAt,
      payload: {
        checkInPhrase: normalizeOptionalText(checkInPhrase, "checkInPhrase"),
        pausePhrase: normalizeOptionalText(pausePhrase, "pausePhrase"),
        stopPhrase: normalizeOptionalText(stopPhrase, "stopPhrase"),
        nonverbalSignal: normalizeOptionalText(nonverbalSignal, "nonverbalSignal"),
        checkInPreference: assertOneOf(
          checkInPreference,
          CHECK_IN_PREFERENCES,
          "checkInPreference"
        ),
        exitPreference: assertOneOf(
          exitPreference,
          EXIT_PREFERENCES,
          "exitPreference"
        ),
        privateReminder: normalizeOptionalText(
          privateReminder,
          "privateReminder"
        )
      },
      reminder:
        "This is your private check-in plan. Hearthline does not monitor it, recognize it, alert anyone from it, or know whether another person has seen or agreed to it."
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

export class PrivacyWeather {
  #store;

  constructor(options = {}) {
    this.#store = new LocalPrivateStore(options);
  }

  savePrivacyComfortNote({
    entryId,
    state = "prefer_not_to_label",
    privateNote = "",
    retentionMode = "session_only",
    expiresAt = null
  }) {
    return this.#store.save({
      entryId,
      retentionMode,
      expiresAt,
      payload: {
        state: assertOneOf(
          state,
          PRIVACY_COMFORT_STATES,
          "state"
        ),
        privateNote: normalizeOptionalText(privateNote, "privateNote")
      },
      reminder:
        "This is your private privacy comfort note. It does not change what others see, your discovery eligibility, or your platform visibility unless you separately choose an action."
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

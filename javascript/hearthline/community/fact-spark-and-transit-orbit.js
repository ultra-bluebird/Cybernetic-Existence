const FACT_SPARK_CATEGORIES = Object.freeze([
  "small_joy",
  "learning",
  "games_media",
  "making_repairing",
  "place_atmosphere",
  "food_drink",
  "public_activity",
  "conversation_style",
  "imagination",
  "no_answer_needed"
]);

const TRANSIT_PLACE_CATEGORIES = Object.freeze([
  "library",
  "cafe",
  "park",
  "community_center",
  "museum",
  "public_plaza",
  "board_game_shop",
  "bookstore",
  "restaurant",
  "public_event_space"
]);

const COST_CONTEXTS = Object.freeze([
  "free",
  "low_cost",
  "varies",
  "unknown"
]);

const ACCESSIBILITY_CONTEXTS = Object.freeze([
  "step_free_entry_reported",
  "seating_reported",
  "accessible_restroom_reported",
  "quiet_area_reported",
  "unknown"
]);

const SENSORY_CONTEXTS = Object.freeze([
  "quiet_often",
  "moderate_noise",
  "lively",
  "varies_by_time",
  "unknown"
]);

const PUBLIC_ACCESS_TYPES = Object.freeze([
  "public",
  "semi_public",
  "ticketed_public",
  "members_only",
  "unknown"
]);

const MAXIMUM_DRAFT_LENGTH = 800;

const PROMPT_LIBRARY = Object.freeze([
  Object.freeze({
    id: "spark-small-joy-v1",
    category: "small_joy",
    prompt: "What is one small thing you enjoyed recently?"
  }),
  Object.freeze({
    id: "spark-learning-v1",
    category: "learning",
    prompt: "What is something you have been curious about lately?"
  }),
  Object.freeze({
    id: "spark-games-media-v1",
    category: "games_media",
    prompt: "What game, book, film, or song has stayed with you?"
  }),
  Object.freeze({
    id: "spark-making-v1",
    category: "making_repairing",
    prompt: "What is something you would like to make, repair, or learn?"
  }),
  Object.freeze({
    id: "spark-place-v1",
    category: "place_atmosphere",
    prompt: "What kind of public place helps you feel comfortable talking?"
  }),
  Object.freeze({
    id: "spark-food-v1",
    category: "food_drink",
    prompt: "What is a simple drink, snack, or meal you enjoy?"
  }),
  Object.freeze({
    id: "spark-activity-v1",
    category: "public_activity",
    prompt: "What is a low-pressure activity you would enjoy doing with someone?"
  }),
  Object.freeze({
    id: "spark-style-v1",
    category: "conversation_style",
    prompt: "What helps a first conversation feel easier for you?"
  }),
  Object.freeze({
    id: "spark-imagination-v1",
    category: "imagination",
    prompt: "If you had a free afternoon, what would you enjoy doing?"
  }),
  Object.freeze({
    id: "spark-skip-v1",
    category: "no_answer_needed",
    prompt: "You can skip this. What would you rather talk about?"
  })
]);

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

function normalizeOptionalDraft(value) {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new TypeError("draft must be a string when provided.");
  }

  if (value.length > MAXIMUM_DRAFT_LENGTH) {
    throw new RangeError(
      `draft cannot exceed ${MAXIMUM_DRAFT_LENGTH} characters.`
    );
  }

  return value;
}

function freezeClone(value) {
  return Object.freeze(structuredClone(value));
}

export class FactSparkGenerator {
  #drafts = new Map();

  listPrompts(category = null) {
    if (category === null) {
      return PROMPT_LIBRARY;
    }

    assertOneOf(category, FACT_SPARK_CATEGORIES, "category");

    return Object.freeze(
      PROMPT_LIBRARY.filter((prompt) => prompt.category === category)
    );
  }

  saveLocalDraft({
    draftId,
    promptId,
    userAuthoredText = ""
  }) {
    const normalizedDraftId = assertNonEmptyString(draftId, "draftId");
    const prompt = PROMPT_LIBRARY.find(
      (entry) => entry.id === assertNonEmptyString(promptId, "promptId")
    );

    if (!prompt) {
      throw new Error(`Unknown prompt "${promptId}".`);
    }

    const draft = Object.freeze({
      draftId: normalizedDraftId,
      promptId: prompt.id,
      category: prompt.category,
      userAuthoredText: normalizeOptionalDraft(userAuthoredText),
      localOnly: true,
      networkDisabled: true,
      autoPublish: false,
      profileUseAllowed: false,
      discoveryUseAllowed: false,
      rankingUseAllowed: false,
      inferenceAllowed: false
    });

    this.#drafts.set(normalizedDraftId, draft);

    return freezeClone({
      draftId: draft.draftId,
      promptId: draft.promptId,
      localOnly: true,
      reminder:
        "This is your local draft. Hearthline does not invent facts, infer meaning, publish it, or use it for discovery."
    });
  }

  readLocalDraft(draftId) {
    const draft = this.#drafts.get(
      assertNonEmptyString(draftId, "draftId")
    );

    if (!draft) {
      throw new Error(`No local draft exists for "${draftId}".`);
    }

    return freezeClone(draft);
  }

  deleteLocalDraft(draftId) {
    const normalizedDraftId = assertNonEmptyString(draftId, "draftId");

    return Object.freeze({
      draftId: normalizedDraftId,
      deleted: this.#drafts.delete(normalizedDraftId),
      localOnly: true,
      networkDisabled: true
    });
  }
}

export function validateTransitOrbitRequest({
  selectedTransitLine,
  selectedBroadArea,
  placeCategory = null,
  costContext = null,
  accessibilityContext = null,
  sensoryContext = null
}) {
  const output = {
    selectedTransitLine: assertNonEmptyString(
      selectedTransitLine,
      "selectedTransitLine"
    ),
    selectedBroadArea: assertNonEmptyString(
      selectedBroadArea,
      "selectedBroadArea"
    ),
    placeCategory: placeCategory === null
      ? null
      : assertOneOf(
          placeCategory,
          TRANSIT_PLACE_CATEGORIES,
          "placeCategory"
        ),
    costContext: costContext === null
      ? null
      : assertOneOf(costContext, COST_CONTEXTS, "costContext"),
    accessibilityContext: accessibilityContext === null
      ? null
      : assertOneOf(
          accessibilityContext,
          ACCESSIBILITY_CONTEXTS,
          "accessibilityContext"
        ),
    sensoryContext: sensoryContext === null
      ? null
      : assertOneOf(
          sensoryContext,
          SENSORY_CONTEXTS,
          "sensoryContext"
        ),
    noUserLocation: true,
    noRouteHistory: true,
    noMeetingIntentInference: true,
    noAccountLinkedSelectionHistory: true,
    externalActionAuthorized: false
  };

  return freezeClone(output);
}

export function validateTransitPlaceEntry(entry) {
  if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
    throw new TypeError("entry must be an object.");
  }

  return freezeClone({
    placeId: assertNonEmptyString(entry.placeId, "placeId"),
    placeName: assertNonEmptyString(entry.placeName, "placeName"),
    placeCategory: assertOneOf(
      entry.placeCategory,
      TRANSIT_PLACE_CATEGORIES,
      "placeCategory"
    ),
    transitContext: assertNonEmptyString(
      entry.transitContext,
      "transitContext"
    ),
    costContext: assertOneOf(
      entry.costContext,
      COST_CONTEXTS,
      "costContext"
    ),
    accessibilityContext: Array.isArray(entry.accessibilityContext)
      ? Object.freeze(
          [...new Set(
            entry.accessibilityContext.map((value) =>
              assertOneOf(
                value,
                ACCESSIBILITY_CONTEXTS,
                "accessibilityContext"
              )
            )
          )]
        )
      : Object.freeze(["unknown"]),
    sensoryContext: assertOneOf(
      entry.sensoryContext,
      SENSORY_CONTEXTS,
      "sensoryContext"
    ),
    publicAccess: assertOneOf(
      entry.publicAccess,
      PUBLIC_ACCESS_TYPES,
      "publicAccess"
    ),
    sourceRetrievedAt: assertNonEmptyString(
      entry.sourceRetrievedAt,
      "sourceRetrievedAt"
    ),
    userLocationStored: false,
    userRouteStored: false,
    userVisitHistoryStored: false,
    externalActionAuthorized: false
  });
}

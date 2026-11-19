"use strict";

const express = require("express");
const crypto = require("crypto");

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "32kb", strict: true }));

const allowedIntents = new Set([
  "find_cooling_center",
  "find_water_service",
  "find_accessible_transit",
  "find_public_restroom",
  "find_shelter",
  "find_city_service",
  "read_heat_alert",
  "read_emergency_guidance",
  "repeat_response",
  "privacy_notice"
]);

const allowedModes = new Set(["text", "speech", "sign"]);
const offlineResponses = new Map([
  ["read_emergency_guidance", {
    answer_type: "emergency_guidance",
    title: "Emergency guidance",
    plain_language_text: "For an immediate emergency, contact local emergency services. This panel can show local safety and support information.",
    speech_text: "For an immediate emergency, contact local emergency services. This panel can show local safety and support information.",
    sign_response_key: "emergency_guidance",
    source_updated_at: null,
    offline: true
  }],
  ["privacy_notice", {
    answer_type: "privacy_notice",
    title: "Privacy notice",
    plain_language_text: "Voice input requires pressing the talk button. Gesture input uses a shutter-gated camera. The panel does not retain audio, video, face data, or identity records.",
    speech_text: "Voice input requires pressing the talk button. Gesture input uses a shutter-gated camera. The panel does not retain audio, video, face data, or identity records.",
    sign_response_key: "privacy_notice",
    source_updated_at: null,
    offline: true
  }]
]);

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeRequest(body) {
  if (!isPlainObject(body)) {
    throw new Error("request must be an object");
  }

  const keys = Object.keys(body);
  const allowedKeys = new Set(["intent", "language", "response_modes", "offline_available", "request_class"]);
  if (keys.some((key) => !allowedKeys.has(key))) {
    throw new Error("request contains prohibited fields");
  }

  if (!allowedIntents.has(body.intent)) {
    throw new Error("unsupported civic-information intent");
  }

  const language = typeof body.language === "string" && /^[a-z]{2}(-[A-Z]{2})?$/.test(body.language)
    ? body.language
    : "en";

  const responseModes = Array.isArray(body.response_modes)
    ? [...new Set(body.response_modes.filter((mode) => allowedModes.has(mode)))]
    : ["text"];

  if (responseModes.length === 0) {
    throw new Error("at least one supported response mode is required");
  }

  if (body.request_class !== "public_information") {
    throw new Error("only public-information requests are supported");
  }

  return {
    intent: body.intent,
    language,
    response_modes: responseModes,
    offline_available: body.offline_available === true,
    request_class: "public_information"
  };
}

function validateGraphResponse(response) {
  if (!isPlainObject(response)) {
    throw new Error("knowledge graph response must be an object");
  }

  const required = ["answer_type", "title", "plain_language_text", "speech_text", "sign_response_key"];
  for (const key of required) {
    if (typeof response[key] !== "string" || response[key].length === 0 || response[key].length > 4000) {
      throw new Error(`invalid knowledge graph response field: ${key}`);
    }
  }

  return {
    answer_type: response.answer_type,
    title: response.title,
    plain_language_text: response.plain_language_text,
    speech_text: response.speech_text,
    sign_response_key: response.sign_response_key,
    source_updated_at: typeof response.source_updated_at === "string" ? response.source_updated_at : null,
    offline: false
  };
}

async function queryCityKnowledgeGraph(request) {
  const endpoint = process.env.CITY_KNOWLEDGE_GRAPH_URL;
  const token = process.env.CITY_KNOWLEDGE_GRAPH_TOKEN;

  if (!endpoint || !token) {
    throw new Error("live knowledge graph is unavailable");
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 1500);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "content-type": "application/json",
        "authorization": `Bearer ${token}`
      },
      body: JSON.stringify(request)
    });

    if (!response.ok) {
      throw new Error("city knowledge graph returned an error");
    }

    return validateGraphResponse(await response.json());
  } finally {
    clearTimeout(timeout);
  }
}

function operationalEvent(kind) {
  return {
    event_id: crypto.randomUUID(),
    kind,
    occurred_at: new Date().toISOString()
  };
}

app.post("/v1/public-information", async (request, response) => {
  try {
    const normalized = normalizeRequest(request.body);

    if (normalized.offline_available && offlineResponses.has(normalized.intent)) {
      response.status(200).json({
        response: offlineResponses.get(normalized.intent),
        operational_event: operationalEvent("offline_response")
      });
      return;
    }

    const graphResponse = await queryCityKnowledgeGraph(normalized);
    response.status(200).json({
      response: graphResponse,
      operational_event: operationalEvent("live_response")
    });
  } catch (error) {
    const fallback = offlineResponses.get(request.body?.intent);
    if (fallback) {
      response.status(200).json({
        response: fallback,
        operational_event: operationalEvent("offline_fallback")
      });
      return;
    }

    response.status(503).json({
      error: "public information is temporarily unavailable",
      accessible_fallback: "Use the physical home button to view offline emergency, heat, water, transit, and city-contact information."
    });
  }
});

module.exports = app;

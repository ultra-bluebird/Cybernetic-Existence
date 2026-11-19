"use strict";

const allowedStates = new Set([
  "SENSOR_DATA_UNAVAILABLE",
  "PRELIMINARY_ELEVATED_READING",
  "VALIDATED_ZONE_ALERT",
  "ALERT_UPDATED",
  "ALERT_CLEARED",
  "NO_ALERT",
]);

function assertSafeAlert(alert) {
  if (!alert || typeof alert !== "object") {
    throw new TypeError("alert must be an object.");
  }

  if (typeof alert.zone_id !== "string" || alert.zone_id.trim() === "") {
    throw new TypeError("alert.zone_id must be a non-empty string.");
  }

  if (!allowedStates.has(alert.state)) {
    throw new TypeError("alert.state is not recognized.");
  }

  if (typeof alert.message !== "string" || alert.message.trim() === "") {
    throw new TypeError("alert.message must be a non-empty string.");
  }

  if (alert.includes_personal_data === true ||
      alert.includes_health_records === true ||
      alert.includes_precise_location_tracking === true) {
    throw new TypeError("The dashboard accepts only aggregate, non-personal alert data.");
  }
}

export function renderZoneAlert(container, alert) {
  if (!(container instanceof HTMLElement)) {
    throw new TypeError("container must be an HTMLElement.");
  }

  assertSafeAlert(alert);

  const section = document.createElement("section");
  section.className = "zone-alert";
  section.setAttribute("aria-live", "polite");
  section.setAttribute("aria-atomic", "true");

  const heading = document.createElement("h2");
  heading.textContent = `Air-quality update: ${alert.zone_id}`;

  const state = document.createElement("p");
  state.textContent = `Status: ${alert.state.replaceAll("_", " ")}`;

  const message = document.createElement("p");
  message.textContent = alert.message;

  const privacy = document.createElement("p");
  privacy.textContent =
    "This public notice uses zone-level information. It does not use personal health records, individual tracking, or identity data.";

  section.append(heading, state, message, privacy);
  container.replaceChildren(section);
}

export function renderUnavailableState(container) {
  renderZoneAlert(container, {
    zone_id: "public alert zone",
    state: "SENSOR_DATA_UNAVAILABLE",
    message:
      "Current validated air-quality data are unavailable. Check official local public-health information and use your usual precautions.",
    includes_personal_data: false,
    includes_health_records: false,
    includes_precise_location_tracking: false,
  });
}

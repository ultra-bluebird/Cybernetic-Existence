const SENSOR_TYPES = Object.freeze([
  "AIR_QUALITY",
  "TRAFFIC_FLOW",
  "AMBIENT_NOISE",
  "URBAN_HEAT",
  "WATER_QUALITY",
  "EQUIPMENT_SAFETY"
]);

function requireStringArray(value, name) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new TypeError(`${name} must be a non-empty array`);
  }

  for (const item of value) {
    if (typeof item !== "string" || item.trim().length === 0) {
      throw new TypeError(`${name} must contain non-empty strings`);
    }
  }
}

function requireSensorType(value) {
  if (!SENSOR_TYPES.includes(value)) {
    throw new RangeError("Unsupported sensor type");
  }
}

export class PublicSensorDisclosure extends HTMLElement {
  #contract = null;

  set contract(value) {
    requireSensorType(value.sensorType);
    requireStringArray(value.measures, "measures");
    requireStringArray(value.notMeasures, "notMeasures");
    requireStringArray(value.dataRecipients, "dataRecipients");

    if (typeof value.retention !== "string" || value.retention.trim().length === 0) {
      throw new TypeError("retention must be a non-empty string");
    }

    if (typeof value.safeFallback !== "string" || value.safeFallback.trim().length === 0) {
      throw new TypeError("safeFallback must be a non-empty string");
    }

    if (value.identityCollectionRequired !== false
      || value.biometricCollectionRequired !== false
      || value.healthInferenceAllowed !== false
      || value.behavioralProfilingAllowed !== false
      || value.externalActionAuthorized !== false) {
      throw new Error("Sensor disclosure contract contains prohibited data or authority flags");
    }

    this.#contract = Object.freeze({
      sensorType: value.sensorType,
      title: value.title ?? "What this sensor measures",
      measures: Object.freeze([...value.measures]),
      notMeasures: Object.freeze([...value.notMeasures]),
      dataRecipients: Object.freeze([...value.dataRecipients]),
      retention: value.retention,
      userInspectable: value.userInspectable === true,
      safeFallback: value.safeFallback,
      identityCollectionRequired: false,
      biometricCollectionRequired: false,
      healthInferenceAllowed: false,
      behavioralProfilingAllowed: false,
      externalActionAuthorized: false
    });

    this.#render();
  }

  get contract() {
    return this.#contract;
  }

  connectedCallback() {
    if (this.#contract !== null) {
      this.#render();
    }
  }

  #render() {
    if (this.#contract === null) {
      return;
    }

    const details = document.createElement("details");
    const summary = document.createElement("summary");
    const list = document.createElement("dl");

    summary.textContent = this.#contract.title;

    this.#appendDefinition(list, "Measures", this.#contract.measures.join("; "));
    this.#appendDefinition(
      list,
      "Does not measure",
      this.#contract.notMeasures.join("; ")
    );
    this.#appendDefinition(
      list,
      "Who can see the data",
      this.#contract.dataRecipients.join("; ")
    );
    this.#appendDefinition(list, "Retention", this.#contract.retention);
    this.#appendDefinition(list, "Fallback", this.#contract.safeFallback);

    details.append(summary, list);
    this.replaceChildren(details);
  }

  #appendDefinition(list, term, definition) {
    const dt = document.createElement("dt");
    const dd = document.createElement("dd");

    dt.textContent = term;
    dd.textContent = definition;

    list.append(dt, dd);
  }
}

customElements.define(
  "public-sensor-disclosure",
  PublicSensorDisclosure
);

"use strict";

const express = require("express");
const { graphql, buildSchema } = require("graphql");

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "32kb", strict: true }));

const schema = buildSchema(`
  type CivicAnswer {
    answerType: String!
    title: String!
    plainLanguageText: String!
    speechText: String!
    signResponseKey: String!
    sourceUpdatedAt: String
    expiresAt: String
    offlineAvailable: Boolean!
    accessibilityNotices: [String!]!
  }

  type Query {
    coolingCenters(language: String!): [CivicAnswer!]!
    accessibleFacilities(category: String!, language: String!): [CivicAnswer!]!
    transitStatus(route: String!, language: String!): [CivicAnswer!]!
    emergencyNotices(language: String!): [CivicAnswer!]!
  }
`);

const allowedLanguages = new Set(["en", "es"]);
const allowedFacilityCategories = new Set([
  "library",
  "cooling_center",
  "public_restroom",
  "shelter",
  "water_service",
  "city_service"
]);

function validateLanguage(language) {
  if (!allowedLanguages.has(language)) {
    throw new Error("unsupported language");
  }
  return language;
}

function validateRoute(route) {
  if (typeof route !== "string" || !/^[A-Za-z0-9 -]{1,32}$/.test(route)) {
    throw new Error("invalid route");
  }
  return route;
}

function validateCategory(category) {
  if (!allowedFacilityCategories.has(category)) {
    throw new Error("unsupported facility category");
  }
  return category;
}

async function sparqlSelect(query, bindings) {
  const endpoint = process.env.CITY_SPARQL_ENDPOINT;
  const token = process.env.CITY_SPARQL_TOKEN;

  if (!endpoint || !token) {
    throw new Error("city knowledge graph is unavailable");
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/sparql-query",
      "accept": "application/sparql-results+json",
      "authorization": `Bearer ${token}`
    },
    body: bindings.reduce(
      (expanded, binding) => expanded.replace(binding.token, binding.value),
      query
    )
  });

  if (!response.ok) {
    throw new Error("knowledge graph query failed");
  }

  return response.json();
}

function escapeSparqlString(value) {
  return value.replace(/["\\\n\r]/g, (character) => {
    const escaped = {
      "\"": "\\\"",
      "\\": "\\\\",
      "\n": "\\n",
      "\r": "\\r"
    };
    return escaped[character];
  });
}

function bindingValue(binding, key) {
  return binding[key]?.value ?? "";
}

function buildAnswer(answerType, binding) {
  const title = bindingValue(binding, "name") || bindingValue(binding, "title");
  const summary = bindingValue(binding, "summary") || "Current civic information is available.";
  const updatedAt = bindingValue(binding, "updatedAt");
  const expiresAt = bindingValue(binding, "expiresAt");

  return {
    answerType,
    title,
    plainLanguageText: summary,
    speechText: summary,
    signResponseKey: answerType,
    sourceUpdatedAt: updatedAt || null,
    expiresAt: expiresAt || null,
    offlineAvailable: true,
    accessibilityNotices: []
  };
}

const root = {
  coolingCenters: async ({ language }) => {
    validateLanguage(language);

    const query = `
      PREFIX civic: <https://augmented-hub.example/ns/civic#>
      SELECT ?name ?summary ?updatedAt ?expiresAt
      WHERE {
        ?facility a civic:CoolingCenter ;
                  civic:hasName ?name ;
                  civic:hasCurrentStatus "open" ;
                  civic:hasPlainLanguageSummary ?summary ;
                  civic:updatedAt ?updatedAt ;
                  civic:expiresAt ?expiresAt .
      }
      ORDER BY DESC(?updatedAt)
      LIMIT 20
    `;

    const result = await sparqlSelect(query, []);
    return result.results.bindings.map((binding) =>
      buildAnswer("cooling_center", binding)
    );
  },

  accessibleFacilities: async ({ category, language }) => {
    validateLanguage(language);
    validateCategory(category);

    const query = `
      PREFIX civic: <https://augmented-hub.example/ns/civic#>
      SELECT ?name ?summary ?updatedAt ?expiresAt
      WHERE {
        ?facility a civic:Facility ;
                  civic:hasServiceCategory "__CATEGORY__" ;
                  civic:hasName ?name ;
                  civic:hasAccessibleEntrance true ;
                  civic:hasPlainLanguageSummary ?summary ;
                  civic:updatedAt ?updatedAt ;
                  civic:expiresAt ?expiresAt .
      }
      ORDER BY DESC(?updatedAt)
      LIMIT 50
    `;

    const result = await sparqlSelect(query, [{
      token: "__CATEGORY__",
      value: escapeSparqlString(category)
    }]);

    return result.results.bindings.map((binding) =>
      buildAnswer("accessible_facility", binding)
    );
  },

  transitStatus: async ({ route, language }) => {
    validateLanguage(language);
    validateRoute(route);

    const query = `
      PREFIX civic: <https://augmented-hub.example/ns/civic#>
      SELECT ?name ?summary ?updatedAt ?expiresAt
      WHERE {
        ?service a civic:TransitRoute ;
                 civic:hasName ?name ;
                 civic:hasRouteCode "__ROUTE__" ;
                 civic:hasPlainLanguageSummary ?summary ;
                 civic:updatedAt ?updatedAt ;
                 civic:expiresAt ?expiresAt .
      }
      ORDER BY DESC(?updatedAt)
      LIMIT 10
    `;

    const result = await sparqlSelect(query, [{
      token: "__ROUTE__",
      value: escapeSparqlString(route)
    }]);

    return result.results.bindings.map((binding) =>
      buildAnswer("transit_status", binding)
    );
  },

  emergencyNotices: async ({ language }) => {
    validateLanguage(language);

    const query = `
      PREFIX civic: <https://augmented-hub.example/ns/civic#>
      SELECT ?title ?summary ?updatedAt ?expiresAt
      WHERE {
        ?notice a civic:EmergencyNotice ;
                civic:hasName ?title ;
                civic:hasPlainLanguageSummary ?summary ;
                civic:updatedAt ?updatedAt ;
                civic:expiresAt ?expiresAt .
      }
      ORDER BY DESC(?updatedAt)
      LIMIT 20
    `;

    const result = await sparqlSelect(query, []);
    return result.results.bindings.map((binding) =>
      buildAnswer("emergency_notice", binding)
    );
  }
};

app.post("/graphql", async (request, response) => {
  const result = await graphql({
    schema,
    source: request.body?.query ?? "",
    rootValue: root,
    variableValues: request.body?.variables ?? {}
  });

  response.status(result.errors ? 400 : 200).json(result);
});

module.exports = app;

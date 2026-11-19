#![forbid(unsafe_code)]

use core::fmt;
use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};

pub const CLI_CRATE_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CliError {
    InvalidCommand(String),
    InvalidArgument(String),
    ScenarioSyntax(String),
    ScenarioValidation(Vec<String>),
    Serialization(String),
}

impl fmt::Display for CliError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidCommand(message)
            | Self::InvalidArgument(message)
            | Self::ScenarioSyntax(message)
            | Self::Serialization(message) => formatter.write_str(message),
            Self::ScenarioValidation(errors) => {
                formatter.write_str("scenario validation failed")?;

                for error in errors {
                    write!(formatter, "\n- {error}")?;
                }

                Ok(())
            }
        }
    }
}

impl std::error::Error for CliError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunArguments {
    pub scenario_path: std::path::PathBuf,
    pub output_path: std::path::PathBuf,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Scenario {
    pub schema_version: String,
    pub scenario_id: String,
    pub purpose: Purpose,
    pub assumptions: Vec<Assumption>,
    #[serde(default)]
    pub seed: Option<u32>,
    pub payload: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Purpose {
    pub category: PurposeCategory,
    pub description: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PurposeCategory {
    WaterResilience,
    EnergyResilience,
    EcologicalRestoration,
    MobilityPlanning,
    InfrastructureMaintenance,
    PublicServiceCapacity,
    ContinuityPlanning,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Assumption {
    pub name: String,
    pub basis: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ResultEnvelope {
    pub scenario_id: String,
    pub purpose: Purpose,
    pub assumptions: Vec<Assumption>,
    pub validation_status: ValidationStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub continuity: Option<ContinuitySummary>,
    pub metrics: ResultMetrics,
    pub reproducibility: ReproducibilityDigest,
    pub result: AdvisoryResult,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ValidationStatus {
    Valid,
    ReviewRequired,
    Rejected,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContinuitySummary {
    pub overall_status: ContinuityStatus,
    pub explanation: String,
    pub capability_results: Vec<CapabilityResult>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ContinuityStatus {
    Met,
    ConditionallyMet,
    Unmet,
    InsufficientEvidence,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CapabilityResult {
    pub kind: String,
    pub status: ContinuityStatus,
    pub availability_ratio: f64,
    pub verification_ratio: f64,
    pub unmet_seconds: f64,
    pub longest_gap_seconds: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ResultMetrics {
    pub knowledge_factor: f64,
    pub eco_impact_value: f64,
    pub harm_risk: f64,
    pub accessibility_impact: f64,
    pub rights_alignment: f64,
    pub social_acceptance_factor: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReproducibilityDigest {
    pub digest: String,
    pub crate_version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub random_seed: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AdvisoryResult {
    pub payload_summary: PayloadSummary,
    pub explanation: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PayloadSummary {
    pub top_level_fields: Vec<String>,
    pub numeric_field_count: usize,
    pub text_field_count: usize,
    pub boolean_field_count: usize,
    pub nested_object_count: usize,
    pub array_count: usize,
}

pub fn parse_run_arguments(arguments: &[String]) -> Result<RunArguments, CliError> {
    if arguments.first().map(String::as_str) != Some("run") {
        return Err(CliError::InvalidCommand(
            "expected the 'run' command".to_owned(),
        ));
    }

    let mut scenario_path = None;
    let mut output_path = None;
    let mut index = 1;

    while index < arguments.len() {
        match arguments[index].as_str() {
            "--scenario" => {
                let value = arguments.get(index + 1).ok_or_else(|| {
                    CliError::InvalidArgument(
                        "missing value after '--scenario'".to_owned(),
                    )
                })?;

                scenario_path = Some(std::path::PathBuf::from(value));
                index += 2;
            }
            "--output" => {
                let value = arguments.get(index + 1).ok_or_else(|| {
                    CliError::InvalidArgument(
                        "missing value after '--output'".to_owned(),
                    )
                })?;

                output_path = Some(std::path::PathBuf::from(value));
                index += 2;
            }
            argument => {
                return Err(CliError::InvalidArgument(format!(
                    "unsupported argument '{argument}'"
                )));
            }
        }
    }

    let scenario_path = scenario_path.ok_or_else(|| {
        CliError::InvalidArgument("the '--scenario' argument is required".to_owned())
    })?;

    let output_path = output_path.ok_or_else(|| {
        CliError::InvalidArgument("the '--output' argument is required".to_owned())
    })?;

    Ok(RunArguments {
        scenario_path,
        output_path,
    })
}

pub fn parse_scenario(source: &str) -> Result<Scenario, CliError> {
    let scenario: Scenario =
        serde_json::from_str(source).map_err(|error| CliError::ScenarioSyntax(error.to_string()))?;

    validate_scenario(&scenario)?;

    Ok(scenario)
}

pub fn validate_scenario(scenario: &Scenario) -> Result<(), CliError> {
    let mut errors = Vec::new();

    if scenario.schema_version.trim().is_empty() {
        errors.push("property 'schema_version' must be a non-empty string".to_owned());
    }

    if scenario.schema_version != "1.0" {
        errors.push(format!(
            "property 'schema_version' must equal '1.0', received '{}'",
            scenario.schema_version
        ));
    }

    if !is_valid_identifier(&scenario.scenario_id) {
        errors.push(
            "property 'scenario_id' must begin with an alphanumeric character and contain only letters, numbers, periods, underscores, or hyphens"
                .to_owned(),
        );
    }

    if scenario.purpose.description.trim().is_empty() {
        errors.push(
            "property 'purpose.description' must be a non-empty string".to_owned(),
        );
    }

    if scenario.assumptions.is_empty() {
        errors.push("property 'assumptions' must contain at least one item".to_owned());
    }

    for (index, assumption) in scenario.assumptions.iter().enumerate() {
        if assumption.name.trim().is_empty() {
            errors.push(format!(
                "property 'assumptions[{index}].name' must be a non-empty string"
            ));
        }

        if assumption.basis.trim().is_empty() {
            errors.push(format!(
                "property 'assumptions[{index}].basis' must be a non-empty string"
            ));
        }
    }

    if !scenario.payload.is_object() {
        errors.push("property 'payload' must be a JSON object".to_owned());
    }

    if errors.is_empty() {
        Ok(())
    } else {
        Err(CliError::ScenarioValidation(errors))
    }
}

pub fn build_result_envelope(scenario: Scenario) -> ResultEnvelope {
    let payload_summary = summarize_payload(&scenario.payload);
    let continuity = continuity_from_payload(&scenario.payload);
    let metrics = metrics_from_payload(&scenario.payload);

    let validation_status = match continuity.as_ref().map(|item| item.overall_status) {
        Some(ContinuityStatus::Unmet | ContinuityStatus::InsufficientEvidence) => {
            ValidationStatus::ReviewRequired
        }
        _ => ValidationStatus::Valid,
    };

    let canonical_scenario = canonicalize_scenario(&scenario);
    let digest = reproducibility_digest(&canonical_scenario, CLI_CRATE_VERSION);

    ResultEnvelope {
        scenario_id: scenario.scenario_id,
        purpose: scenario.purpose,
        assumptions: scenario.assumptions,
        validation_status,
        continuity,
        metrics,
        reproducibility: ReproducibilityDigest {
            digest,
            crate_version: CLI_CRATE_VERSION.to_owned(),
            random_seed: scenario.seed,
        },
        result: AdvisoryResult {
            payload_summary,
            explanation: String::from(
                "The local command-line runner validated the scenario structure and produced a deterministic advisory result envelope. Domain calculations are delegated to the linked popmath library as domain modules are enabled.",
            ),
        },
    }
}

pub fn serialize_result_envelope(
    result: &ResultEnvelope,
) -> Result<String, CliError> {
    serde_json::to_string_pretty(result)
        .map_err(|error| CliError::Serialization(error.to_string()))
}

fn is_valid_identifier(value: &str) -> bool {
    let mut characters = value.chars();

    let Some(first) = characters.next() else {
        return false;
    };

    if !first.is_ascii_alphanumeric() {
        return false;
    }

    characters.all(|character| {
        character.is_ascii_alphanumeric()
            || matches!(character, '.' | '_' | '-')
    })
}

fn canonicalize_scenario(scenario: &Scenario) -> String {
    let value = serde_json::to_value(scenario)
        .expect("serializing an already valid scenario must succeed");

    canonical_json(&value)
}

fn canonical_json(value: &Value) -> String {
    match value {
        Value::Null => String::from("null"),
        Value::Bool(boolean) => boolean.to_string(),
        Value::Number(number) => number.to_string(),
        Value::String(text) => serde_json::to_string(text)
            .expect("serializing a JSON string must succeed"),
        Value::Array(values) => {
            let values = values.iter().map(canonical_json).collect::<Vec<_>>();
            format!("[{}]", values.join(","))
        }
        Value::Object(object) => canonical_object(object),
    }
}

fn canonical_object(object: &Map<String, Value>) -> String {
    let sorted = object
        .iter()
        .map(|(key, value)| (key.as_str(), value))
        .collect::<BTreeMap<_, _>>();

    let fields = sorted
        .iter()
        .map(|(key, value)| {
            let encoded_key = serde_json::to_string(key)
                .expect("serializing a JSON object key must succeed");

            format!("{encoded_key}:{}", canonical_json(value))
        })
        .collect::<Vec<_>>();

    format!("{{{}}}", fields.join(","))
}

fn reproducibility_digest(canonical_scenario: &str, crate_version: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(canonical_scenario.as_bytes());
    hasher.update([0]);
    hasher.update(crate_version.as_bytes());

    let digest = hasher.finalize();
    format!("{digest:x}")
}

fn summarize_payload(payload: &Value) -> PayloadSummary {
    let mut counters = PayloadCounters::default();
    count_payload_value(payload, &mut counters);

    let top_level_fields = payload
        .as_object()
        .map(|object| object.keys().cloned().collect::<Vec<_>>())
        .unwrap_or_default();

    PayloadSummary {
        top_level_fields,
        numeric_field_count: counters.numeric_field_count,
        text_field_count: counters.text_field_count,
        boolean_field_count: counters.boolean_field_count,
        nested_object_count: counters.nested_object_count,
        array_count: counters.array_count,
    }
}

#[derive(Debug, Default)]
struct PayloadCounters {
    numeric_field_count: usize,
    text_field_count: usize,
    boolean_field_count: usize,
    nested_object_count: usize,
    array_count: usize,
}

fn count_payload_value(value: &Value, counters: &mut PayloadCounters) {
    match value {
        Value::Null => {}
        Value::Bool(_) => counters.boolean_field_count += 1,
        Value::Number(_) => counters.numeric_field_count += 1,
        Value::String(_) => counters.text_field_count += 1,
        Value::Array(values) => {
            counters.array_count += 1;

            for value in values {
                count_payload_value(value, counters);
            }
        }
        Value::Object(object) => {
            counters.nested_object_count += 1;

            for value in object.values() {
                count_payload_value(value, counters);
            }
        }
    }
}

fn continuity_from_payload(payload: &Value) -> Option<ContinuitySummary> {
    let continuity = payload.get("continuity")?;
    let overall_status = continuity
        .get("overall_status")
        .and_then(Value::as_str)
        .and_then(parse_continuity_status)?;

    let explanation = continuity
        .get("explanation")
        .and_then(Value::as_str)
        .unwrap_or("Continuity status was supplied by the scenario payload.")
        .to_owned();

    let capability_results = continuity
        .get("capability_results")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(parse_capability_result)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    Some(ContinuitySummary {
        overall_status,
        explanation,
        capability_results,
    })
}

fn parse_continuity_status(value: &str) -> Option<ContinuityStatus> {
    match value {
        "Met" => Some(ContinuityStatus::Met),
        "ConditionallyMet" => Some(ContinuityStatus::ConditionallyMet),
        "Unmet" => Some(ContinuityStatus::Unmet),
        "InsufficientEvidence" => Some(ContinuityStatus::InsufficientEvidence),
        _ => None,
    }
}

fn parse_capability_result(value: &Value) -> Option<CapabilityResult> {
    Some(CapabilityResult {
        kind: value.get("kind")?.as_str()?.to_owned(),
        status: parse_continuity_status(value.get("status")?.as_str()?)?,
        availability_ratio: value.get("availability_ratio")?.as_f64()?,
        verification_ratio: value.get("verification_ratio")?.as_f64()?,
        unmet_seconds: value.get("unmet_seconds")?.as_f64()?,
        longest_gap_seconds: value.get("longest_gap_seconds")?.as_f64()?,
    })
}

fn metrics_from_payload(payload: &Value) -> ResultMetrics {
    let metrics = payload.get("metrics");

    ResultMetrics {
        knowledge_factor: bounded_metric(metrics, "knowledge_factor"),
        eco_impact_value: bounded_metric(metrics, "eco_impact_value"),
        harm_risk: bounded_metric(metrics, "harm_risk"),
        accessibility_impact: bounded_metric(metrics, "accessibility_impact"),
        rights_alignment: bounded_metric(metrics, "rights_alignment"),
        social_acceptance_factor: bounded_metric(metrics, "social_acceptance_factor"),
    }
}

fn bounded_metric(metrics: Option<&Value>, key: &str) -> f64 {
    metrics
        .and_then(|value| value.get(key))
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite())
        .map(|value| value.clamp(0.0, 1.0))
        .unwrap_or(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scenario_json() -> &'static str {
        r#"
{
  "schema_version": "1.0",
  "scenario_id": "continuity-corridor-01",
  "purpose": {
    "category": "ContinuityPlanning",
    "description": "Synthetic local continuity scenario."
  },
  "assumptions": [
    {
      "name": "Support duration",
      "basis": "Synthetic deterministic fixture."
    }
  ],
  "seed": 42,
  "payload": {
    "continuity": {
      "overall_status": "Met",
      "explanation": "All requested conditions were met.",
      "capability_results": [
        {
          "kind": "ContinuousPower",
          "status": "Met",
          "availability_ratio": 1.0,
          "verification_ratio": 1.0,
          "unmet_seconds": 0.0,
          "longest_gap_seconds": 0.0
        }
      ]
    },
    "metrics": {
      "knowledge_factor": 0.92,
      "eco_impact_value": 0.81,
      "harm_risk": 0.10,
      "accessibility_impact": 0.95,
      "rights_alignment": 0.97,
      "social_acceptance_factor": 0.88
    }
  }
}
"#
    }

    #[test]
    fn parses_valid_run_arguments() {
        let arguments = vec![
            String::from("run"),
            String::from("--scenario"),
            String::from("scenario.json"),
            String::from("--output"),
            String::from("result.json"),
        ];

        let parsed = parse_run_arguments(&arguments).expect("arguments should parse");

        assert_eq!(parsed.scenario_path, std::path::PathBuf::from("scenario.json"));
        assert_eq!(parsed.output_path, std::path::PathBuf::from("result.json"));
    }

    #[test]
    fn rejects_invalid_scenario_identifier() {
        let invalid = scenario_json().replace(
            "continuity-corridor-01",
            "continuity corridor with spaces",
        );

        let error = parse_scenario(&invalid).expect_err("invalid identifier must fail");

        assert!(error
            .to_string()
            .contains("property 'scenario_id' must begin"));
    }

    #[test]
    fn produces_stable_digest_for_same_scenario() {
        let scenario = parse_scenario(scenario_json()).expect("scenario should parse");

        let first = build_result_envelope(scenario.clone());
        let second = build_result_envelope(scenario);

        assert_eq!(
            first.reproducibility.digest,
            second.reproducibility.digest
        );
    }

    #[test]
    fn continuity_unmet_requires_review() {
        let input = scenario_json().replace(
            "\"overall_status\": \"Met\"",
            "\"overall_status\": \"Unmet\"",
        );

        let scenario = parse_scenario(&input).expect("scenario should parse");
        let result = build_result_envelope(scenario);

        assert_eq!(result.validation_status, ValidationStatus::ReviewRequired);
    }

    #[test]
    fn serializes_result_envelope() {
        let scenario = parse_scenario(scenario_json()).expect("scenario should parse");
        let result = build_result_envelope(scenario);
        let serialized = serialize_result_envelope(&result)
            .expect("result envelope should serialize");

        assert!(serialized.contains("\"scenario_id\": \"continuity-corridor-01\""));
        assert!(serialized.contains("\"digest\""));
    }
}

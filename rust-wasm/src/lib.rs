//! Local-first WebAssembly bindings for Augmented-Hub evaluation.
//!
//! These bindings evaluate caller-supplied NDJSON text inside a browser or
//! other WASM host. They do not:
//!
//! - Open files.
//! - Make network requests.
//! - Send records to a server.
//! - Create or write a database.
//! - Publish results.
//! - Store records in browser storage.
//! - Sign records or manage private keys.
//! - Control permits, utilities, sensors, workloads, equipment, services, or
//!   external systems.
//! - Verify identity, CyberRank, legal authority, eligibility, enforcement,
//!   medical status, private systems, or sensitive ecological locations.
//!
//! A returned `pass` is bounded decision support only. It does not establish
//! permit approval, legal compliance, authority, ecological safety, identity,
//! or authorization for any external action.

#![forbid(unsafe_code)]

use serde::Serialize;
use wasm_bindgen::prelude::*;

use augmented_hub::pipeline::{
    output_ndjson_line, validate_line, NdjsonLine, PipelineRejectedRecord,
    PipelineValidationResult,
};

const MAXIMUM_LINE_BYTES: usize = 1_048_576;
const MAXIMUM_BATCH_RECORDS: usize = 10_000;
const MAXIMUM_BATCH_BYTES: usize = 8 * 1_024 * 1_024;

/// Evaluates one NDJSON record locally.
///
/// The input must contain exactly one non-empty JSON line. The function
/// returns one deterministic JSON result string. Invalid, oversized, empty,
/// or multi-line input returns a privacy-preserving rejection record.
///
/// No input is retained after the function returns.
#[wasm_bindgen]
pub fn evaluate_ndjson_line(input: &str) -> String {
    if input.len() > MAXIMUM_LINE_BYTES {
        return rejection_line(
            1,
            "wasm.input_line_too_large",
            "The input line exceeds the local browser evaluation limit.",
        );
    }

    let trimmed = input.trim();

    if trimmed.is_empty() {
        return rejection_line(
            1,
            "wasm.input_empty",
            "The input does not contain an NDJSON record.",
        );
    }

    if trimmed.contains('\n') || trimmed.contains('\r') {
        return rejection_line(
            1,
            "wasm.input_multiple_lines",
            "Single-record evaluation accepts exactly one non-empty NDJSON line.",
        );
    }

    serialize_result(validate_line(&NdjsonLine {
        line_number: 1,
        text: trimmed.to_string(),
    }))
}

/// Evaluates a bounded NDJSON batch locally.
///
/// Each non-empty input line produces exactly one output JSON line. Empty
/// lines are skipped. The function performs no persistence and makes no
/// network request. A batch larger than configured safety limits produces one
/// rejection line instead of partially evaluating an unbounded input.
#[wasm_bindgen]
pub fn evaluate_batch(input: &str) -> String {
    if input.len() > MAXIMUM_BATCH_BYTES {
        return rejection_line(
            0,
            "wasm.input_batch_too_large",
            "The input batch exceeds the local browser evaluation limit.",
        );
    }

    let non_empty_line_count = input
        .lines()
        .filter(|line| !line.trim().is_empty())
        .count();

    if non_empty_line_count > MAXIMUM_BATCH_RECORDS {
        return rejection_line(
            0,
            "wasm.input_batch_record_limit_exceeded",
            "The input batch exceeds the local browser record-count limit.",
        );
    }

    let mut output_lines = Vec::with_capacity(non_empty_line_count);

    for (zero_based_line_number, line) in input.lines().enumerate() {
        let line_number = (zero_based_line_number as u64).saturating_add(1);
        let trimmed = line.trim();

        if trimmed.is_empty() {
            continue;
        }

        if trimmed.len() > MAXIMUM_LINE_BYTES {
            output_lines.push(rejection_line(
                line_number,
                "wasm.input_line_too_large",
                "The input line exceeds the local browser evaluation limit.",
            ));
            continue;
        }

        output_lines.push(serialize_result(validate_line(&NdjsonLine {
            line_number,
            text: trimmed.to_string(),
        })));
    }

    if output_lines.is_empty() {
        return rejection_line(
            0,
            "wasm.input_empty",
            "The input batch does not contain an NDJSON record.",
        );
    }

    output_lines.join("\n")
}

fn serialize_result(result: PipelineValidationResult) -> String {
    output_ndjson_line(&result).unwrap_or_else(|_| {
        rejection_line(
            source_line_number(&result),
            "wasm.output_serialization_failed",
            "The local evaluation result could not be serialized.",
        )
    })
}

fn source_line_number(result: &PipelineValidationResult) -> u64 {
    match result {
        PipelineValidationResult::Accepted(accepted) => accepted.line_number,
        PipelineValidationResult::Rejected(rejected) => rejected.line_number,
    }
}

fn rejection_line(line_number: u64, reason_code: &str, message: &str) -> String {
    let result = PipelineValidationResult::Rejected(PipelineRejectedRecord {
        line_number,
        reason_code: reason_code.to_string(),
        message: message.to_string(),
    });

    output_ndjson_line(&result).unwrap_or_else(|_| {
        serde_json::to_string(&WasmFallbackRejection {
            output_kind: "rejection",
            source_line_number: line_number,
            overall_status: "insufficient_evidence",
            active_reason_code: "wasm.output_fallback_failed",
            eligible_for_human_review: false,
            eligible_for_public_benefit_claim: false,
            non_actuating: "required",
            public_summary: "The local evaluation output could not be produced.",
        })
        .unwrap_or_else(|_| {
            "{\"output_kind\":\"rejection\",\"source_line_number\":0,\
             \"overall_status\":\"insufficient_evidence\",\
             \"active_reason_code\":\"wasm.output_fallback_failed\",\
             \"eligible_for_human_review\":false,\
             \"eligible_for_public_benefit_claim\":false,\
             \"non_actuating\":\"required\",\
             \"public_summary\":\"The local evaluation output could not be produced.\"}"
                .to_string()
        })
    })
}

#[derive(Serialize)]
struct WasmFallbackRejection<'a> {
    output_kind: &'a str,
    source_line_number: u64,
    overall_status: &'a str,
    active_reason_code: &'a str,
    eligible_for_human_review: bool,
    eligible_for_public_benefit_claim: bool,
    non_actuating: &'a str,
    public_summary: &'a str,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_single_input_fails_closed() {
        let output = evaluate_ndjson_line("   ");

        assert!(output.contains("\"output_kind\":\"rejection\""));
        assert!(output.contains("\"active_reason_code\":\"wasm.input_empty\""));
        assert!(output.contains("\"non_actuating\":\"required\""));
    }

    #[test]
    fn single_evaluator_rejects_multiple_lines() {
        let output = evaluate_ndjson_line("{\"kind\":\"unknown\"}\n{\"kind\":\"unknown\"}");

        assert!(output.contains("\"active_reason_code\":\"wasm.input_multiple_lines\""));
    }

    #[test]
    fn batch_evaluator_preserves_one_output_per_non_empty_line() {
        let output = evaluate_batch("{\"kind\":\"unknown\"}\n\n{\"kind\":\"unknown\"}\n");

        assert_eq!(output.lines().count(), 2);
        assert!(
            output
                .lines()
                .all(|line| line.contains("\"output_kind\":\"rejection\""))
        );
    }
}

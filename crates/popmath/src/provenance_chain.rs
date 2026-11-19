use alloc::string::String;
use alloc::vec::Vec;

use crate::continuity::EvidenceStatus;
use crate::error::PopmathError;
use crate::provenance::{
    AggregationStatus, DataQuality, ProvenanceRecord, SourceKind,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CalibrationStatus {
    Calibrated,
    CalibrationPending,
    CalibrationExpired,
    CalibrationFailed,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SensorReadingCommitment {
    pub sensor_alias: String,
    pub sequence_number: u64,
    pub measurement_window_start_seconds: i64,
    pub measurement_window_end_seconds: i64,
    pub calibration_status: CalibrationStatus,
    pub aggregation_status: AggregationStatus,
    pub evidence_status: EvidenceStatus,
    pub reading_commitment: String,
    pub previous_chain_hash: String,
    pub chain_hash: String,
    pub provenance: ProvenanceRecord,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProvenanceChainSummary {
    pub record_count: u64,
    pub terminal_chain_hash: String,
    pub required_evidence: EvidenceStatus,
    pub all_inputs_meet_required_evidence: bool,
    pub all_inputs_calibrated: bool,
    pub verified_input_count: u64,
    pub assumed_input_count: u64,
    pub unknown_input_count: u64,
    pub calibrated_input_count: u64,
}

pub fn build_sensor_provenance_chain(
    records: &[(String, ProvenanceRecord, CalibrationStatus, EvidenceStatus)],
) -> Result<Vec<SensorReadingCommitment>, PopmathError> {
    let mut previous_hash = String::from("popmath-provenance-chain-v1");
    let mut chain = Vec::with_capacity(records.len());

    for (index, (canonical_reading, provenance, calibration, evidence)) in
        records.iter().enumerate()
    {
        let reading_commitment = deterministic_hash(canonical_reading);
        let metadata = canonical_metadata(
            index as u64,
            provenance,
            *calibration,
            *evidence,
            &reading_commitment,
        );

        let chain_hash = deterministic_hash(&alloc::format!(
            "{}|{}",
            previous_hash,
            metadata
        ));

        chain.push(SensorReadingCommitment {
            sensor_alias: provenance.source_name.clone(),
            sequence_number: index as u64,
            measurement_window_start_seconds: provenance
                .time_window
                .start()
                .seconds_since_epoch(),
            measurement_window_end_seconds: provenance
                .time_window
                .end()
                .seconds_since_epoch(),
            calibration_status: *calibration,
            aggregation_status: provenance.aggregation_status,
            evidence_status: *evidence,
            reading_commitment,
            previous_chain_hash: previous_hash.clone(),
            chain_hash: chain_hash.clone(),
            provenance: provenance.clone(),
        });

        previous_hash = chain_hash;
    }

    Ok(chain)
}

pub fn summarize_provenance_chain(
    chain: &[SensorReadingCommitment],
    required_evidence: EvidenceStatus,
) -> ProvenanceChainSummary {
    let mut verified_input_count = 0_u64;
    let mut assumed_input_count = 0_u64;
    let mut unknown_input_count = 0_u64;
    let mut calibrated_input_count = 0_u64;
    let mut all_inputs_calibrated = true;
    let mut all_inputs_meet_required_evidence = true;

    for record in chain {
        match record.evidence_status {
            EvidenceStatus::Verified => verified_input_count += 1,
            EvidenceStatus::Assumed => assumed_input_count += 1,
            EvidenceStatus::Unknown => unknown_input_count += 1,
        }

        if record.calibration_status == CalibrationStatus::Calibrated {
            calibrated_input_count += 1;
        } else {
            all_inputs_calibrated = false;
        }

        if record.evidence_status < required_evidence {
            all_inputs_meet_required_evidence = false;
        }
    }

    ProvenanceChainSummary {
        record_count: chain.len() as u64,
        terminal_chain_hash: chain
            .last()
            .map(|record| record.chain_hash.clone())
            .unwrap_or_else(|| String::from("popmath-provenance-chain-v1")),
        required_evidence,
        all_inputs_meet_required_evidence,
        all_inputs_calibrated,
        verified_input_count,
        assumed_input_count,
        unknown_input_count,
        calibrated_input_count,
    }
}

pub fn verify_provenance_chain(
    chain: &[SensorReadingCommitment],
) -> Result<bool, PopmathError> {
    let mut expected_previous_hash = String::from("popmath-provenance-chain-v1");

    for record in chain {
        if record.previous_chain_hash != expected_previous_hash {
            return Ok(false);
        }

        let metadata = canonical_metadata(
            record.sequence_number,
            &record.provenance,
            record.calibration_status,
            record.evidence_status,
            &record.reading_commitment,
        );

        let expected_chain_hash = deterministic_hash(&alloc::format!(
            "{}|{}",
            expected_previous_hash,
            metadata
        ));

        if record.chain_hash != expected_chain_hash {
            return Ok(false);
        }

        expected_previous_hash = record.chain_hash.clone();
    }

    Ok(true)
}

fn canonical_metadata(
    sequence_number: u64,
    provenance: &ProvenanceRecord,
    calibration_status: CalibrationStatus,
    evidence_status: EvidenceStatus,
    reading_commitment: &str,
) -> String {
    alloc::format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}",
        sequence_number,
        provenance.source_name,
        provenance.time_window.start().seconds_since_epoch(),
        provenance.time_window.end().seconds_since_epoch(),
        source_kind_name(provenance.source_kind),
        aggregation_status_name(provenance.aggregation_status),
        data_quality_name(provenance.data_quality),
        calibration_status_name(calibration_status),
        alloc::format!(
            "{}|{}",
            evidence_status_name(evidence_status),
            reading_commitment
        )
    )
}

fn deterministic_hash(input: &str) -> String {
    let mut state = 0xcbf29ce484222325_u64;

    for byte in input.as_bytes() {
        state ^= u64::from(*byte);
        state = state.wrapping_mul(0x100000001b3);
    }

    alloc::format!("{state:016x}")
}

fn source_kind_name(value: SourceKind) -> &'static str {
    match value {
        SourceKind::PublicRecord => "public_record",
        SourceKind::SensorMeasurement => "sensor_measurement",
        SourceKind::SyntheticModel => "synthetic_model",
        SourceKind::CommunityAggregate => "community_aggregate",
        SourceKind::DerivedCalculation => "derived_calculation",
    }
}

fn aggregation_status_name(value: AggregationStatus) -> &'static str {
    match value {
        AggregationStatus::Unknown => "unknown",
        AggregationStatus::VerifiedAggregate => "verified_aggregate",
        AggregationStatus::Synthetic => "synthetic",
        AggregationStatus::Quarantined => "quarantined",
    }
}

fn data_quality_name(value: DataQuality) -> &'static str {
    match value {
        DataQuality::High => "high",
        DataQuality::Medium => "medium",
        DataQuality::Low => "low",
        DataQuality::Unknown => "unknown",
    }
}

fn calibration_status_name(value: CalibrationStatus) -> &'static str {
    match value {
        CalibrationStatus::Calibrated => "calibrated",
        CalibrationStatus::CalibrationPending => "calibration_pending",
        CalibrationStatus::CalibrationExpired => "calibration_expired",
        CalibrationStatus::CalibrationFailed => "calibration_failed",
    }
}

fn evidence_status_name(value: EvidenceStatus) -> &'static str {
    match value {
        EvidenceStatus::Verified => "verified",
        EvidenceStatus::Assumed => "assumed",
        EvidenceStatus::Unknown => "unknown",
    }
}

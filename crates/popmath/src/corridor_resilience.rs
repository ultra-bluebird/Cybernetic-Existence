use std::collections::BTreeMap;
use std::fmt;

const MILLIS_PER_SECOND: u64 = 1_000;
const SHA256_HEX_LENGTH: usize = 64;
const MAX_QUARANTINE_INCONSISTENCY_NUMERATOR: u64 = 10;
const QUARANTINE_THRESHOLD_DENOMINATOR: u64 = 100;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct UnitInterval(u16);

impl UnitInterval {
    pub const ZERO: Self = Self(0);
    pub const ONE: Self = Self(10_000);

    pub fn from_ratio(numerator: u64, denominator: u64) -> Result<Self, CorridorError> {
        if denominator == 0 {
            return Err(CorridorError::ZeroDenominator);
        }

        if numerator > denominator {
            return Err(CorridorError::InvalidRatio {
                numerator,
                denominator,
            });
        }

        let scaled = numerator
            .checked_mul(Self::ONE.0 as u64)
            .ok_or(CorridorError::ArithmeticOverflow)?
            / denominator;

        Ok(Self(scaled as u16))
    }

    pub fn from_basis_points(basis_points: u16) -> Result<Self, CorridorError> {
        if basis_points > Self::ONE.0 {
            return Err(CorridorError::InvalidUnitInterval { basis_points });
        }

        Ok(Self(basis_points))
    }

    pub fn basis_points(self) -> u16 {
        self.0
    }

    pub fn as_f64(self) -> f64 {
        self.0 as f64 / Self::ONE.0 as f64
    }

    pub fn minimum(self, other: Self) -> Self {
        Self(self.0.min(other.0))
    }

    pub fn multiply(self, other: Self) -> Self {
        let product = self.0 as u32 * other.0 as u32;
        Self((product / Self::ONE.0 as u32) as u16)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EvidenceStatus {
    Verified,
    PendingReview,
    Rejected,
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CapabilityRequirement {
    pub capability: String,
    pub minimum_score: UnitInterval,
    pub measured_score: UnitInterval,
    pub evidence_status: EvidenceStatus,
    pub satisfied: bool,
    pub explanation: String,
}

impl CapabilityRequirement {
    pub fn verified(
        capability: impl Into<String>,
        minimum_score: UnitInterval,
        measured_score: UnitInterval,
        explanation: impl Into<String>,
    ) -> Self {
        Self {
            capability: capability.into(),
            minimum_score,
            measured_score,
            evidence_status: EvidenceStatus::Verified,
            satisfied: measured_score >= minimum_score,
            explanation: explanation.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProvenanceRecord {
    pub sensor_pseudonymous_id: String,
    pub corridor_id: String,
    pub observation_sequence: u64,
    pub observed_at_unix_seconds: u64,
    pub payload_sha256_hex: String,
    pub last_calibration_certificate_sha256_hex: String,
    pub device_public_key_fingerprint_sha256_hex: String,
    pub signature_algorithm: String,
    pub signature_base64url: String,
    pub evidence_status: EvidenceStatus,
}

impl ProvenanceRecord {
    pub fn validate(&self) -> Result<(), CorridorError> {
        if self.sensor_pseudonymous_id.trim().is_empty() {
            return Err(CorridorError::MissingField {
                field: "sensor_pseudonymous_id",
            });
        }

        if self.corridor_id.trim().is_empty() {
            return Err(CorridorError::MissingField {
                field: "corridor_id",
            });
        }

        if self.observation_sequence == 0 {
            return Err(CorridorError::InvalidObservationSequence);
        }

        validate_sha256_hex(
            "payload_sha256_hex",
            &self.payload_sha256_hex,
        )?;

        validate_sha256_hex(
            "last_calibration_certificate_sha256_hex",
            &self.last_calibration_certificate_sha256_hex,
        )?;

        validate_sha256_hex(
            "device_public_key_fingerprint_sha256_hex",
            &self.device_public_key_fingerprint_sha256_hex,
        )?;

        if self.signature_algorithm != "Ed25519" {
            return Err(CorridorError::UnsupportedSignatureAlgorithm {
                algorithm: self.signature_algorithm.clone(),
            });
        }

        if self.signature_base64url.trim().is_empty() {
            return Err(CorridorError::MissingField {
                field: "signature_base64url",
            });
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CorridorQuarantineAssessment {
    pub corridor_id: String,
    pub eligible_sensor_count: u64,
    pub canonical_calibration_certificate_sha256_hex: Option<String>,
    pub inconsistent_sensor_ids: Vec<String>,
    pub invalid_record_sensor_ids: Vec<String>,
    pub inconsistency_ratio: UnitInterval,
    pub quarantine_required: bool,
    pub reason: String,
}

impl CorridorQuarantineAssessment {
    pub fn trusted_for_continuity_assessment(&self) -> bool {
        !self.quarantine_required
            && self.invalid_record_sensor_ids.is_empty()
            && self.eligible_sensor_count > 0
    }
}

pub fn assess_corridor_calibration_consistency(
    corridor_id: &str,
    records: &[ProvenanceRecord],
) -> Result<CorridorQuarantineAssessment, CorridorError> {
    if corridor_id.trim().is_empty() {
        return Err(CorridorError::MissingField {
            field: "corridor_id",
        });
    }

    let mut certificate_counts = BTreeMap::<String, u64>::new();
    let mut invalid_record_sensor_ids = Vec::new();
    let mut eligible_records = Vec::new();

    for record in records {
        if record.corridor_id != corridor_id {
            return Err(CorridorError::CrossCorridorRecord {
                expected_corridor_id: corridor_id.to_owned(),
                actual_corridor_id: record.corridor_id.clone(),
            });
        }

        match record.validate() {
            Ok(()) => {
                let normalized_hash =
                    record.last_calibration_certificate_sha256_hex.to_ascii_lowercase();

                *certificate_counts.entry(normalized_hash).or_insert(0) += 1;
                eligible_records.push(record);
            }
            Err(_) => invalid_record_sensor_ids.push(record.sensor_pseudonymous_id.clone()),
        }
    }

    if eligible_records.is_empty() {
        return Ok(CorridorQuarantineAssessment {
            corridor_id: corridor_id.to_owned(),
            eligible_sensor_count: 0,
            canonical_calibration_certificate_sha256_hex: None,
            inconsistent_sensor_ids: Vec::new(),
            invalid_record_sensor_ids,
            inconsistency_ratio: UnitInterval::ONE,
            quarantine_required: true,
            reason: "No valid signed provenance records are available for this corridor."
                .to_owned(),
        });
    }

    let canonical_hash = certificate_counts
        .iter()
        .max_by(|(left_hash, left_count), (right_hash, right_count)| {
            left_count
                .cmp(right_count)
                .then_with(|| right_hash.cmp(left_hash))
        })
        .map(|(hash, _)| hash.clone())
        .ok_or(CorridorError::MissingCanonicalHash)?;

    let mut inconsistent_sensor_ids = eligible_records
        .iter()
        .filter(|record| {
            !record
                .last_calibration_certificate_sha256_hex
                .eq_ignore_ascii_case(&canonical_hash)
        })
        .map(|record| record.sensor_pseudonymous_id.clone())
        .collect::<Vec<_>>();

    inconsistent_sensor_ids.sort();
    invalid_record_sensor_ids.sort();

    let inconsistency_count =
        inconsistent_sensor_ids.len() as u64 + invalid_record_sensor_ids.len() as u64;

    let total_record_count = records.len() as u64;
    let inconsistency_ratio = UnitInterval::from_ratio(inconsistency_count, total_record_count)?;

    let quarantine_required = inconsistency_count
        .checked_mul(QUARANTINE_THRESHOLD_DENOMINATOR)
        .ok_or(CorridorError::ArithmeticOverflow)?
        > total_record_count
            .checked_mul(MAX_QUARANTINE_INCONSISTENCY_NUMERATOR)
            .ok_or(CorridorError::ArithmeticOverflow)?;

    let reason = if quarantine_required {
        format!(
            "Corridor data is quarantined because {}/{} sensor records are inconsistent or invalid, exceeding the strict 10% threshold.",
            inconsistency_count, total_record_count
        )
    } else {
        format!(
            "Corridor data remains eligible because {}/{} sensor records are inconsistent or invalid, which does not exceed the strict 10% threshold.",
            inconsistency_count, total_record_count
        )
    };

    Ok(CorridorQuarantineAssessment {
        corridor_id: corridor_id.to_owned(),
        eligible_sensor_count: eligible_records.len() as u64,
        canonical_calibration_certificate_sha256_hex: Some(canonical_hash),
        inconsistent_sensor_ids,
        invalid_record_sensor_ids,
        inconsistency_ratio,
        quarantine_required,
        reason,
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SidewalkAccessibilityMeasurements {
    pub available_turning_radius_millimeters: u32,
    pub required_turning_radius_millimeters: u32,
    pub available_charging_clearance_millimeters: u32,
    pub required_charging_clearance_millimeters: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JointAccessibilityAssessment {
    pub wheelchair_turning_score: UnitInterval,
    pub exoskeleton_charging_clearance_score: UnitInterval,
    pub combined_index: UnitInterval,
    pub capability_requirement: CapabilityRequirement,
}

pub fn assess_joint_accessibility(
    measurements: SidewalkAccessibilityMeasurements,
    required_combined_index: UnitInterval,
) -> Result<JointAccessibilityAssessment, CorridorError> {
    validate_positive_measurement(
        "required_turning_radius_millimeters",
        measurements.required_turning_radius_millimeters,
    )?;

    validate_positive_measurement(
        "required_charging_clearance_millimeters",
        measurements.required_charging_clearance_millimeters,
    )?;

    let wheelchair_turning_score = capped_adequacy_score(
        measurements.available_turning_radius_millimeters,
        measurements.required_turning_radius_millimeters,
    )?;

    let exoskeleton_charging_clearance_score = capped_adequacy_score(
        measurements.available_charging_clearance_millimeters,
        measurements.required_charging_clearance_millimeters,
    )?;

    let combined_index = wheelchair_turning_score.minimum(exoskeleton_charging_clearance_score);

    let explanation = format!(
        "The joint accessibility index uses the minimum operator: wheelchair turning adequacy is {:.4}, exoskeleton charging-clearance adequacy is {:.4}, and the segment score is {:.4}. This prevents a strong result in one access mode from masking an unmet requirement in the other.",
        wheelchair_turning_score.as_f64(),
        exoskeleton_charging_clearance_score.as_f64(),
        combined_index.as_f64(),
    );

    let capability_requirement = CapabilityRequirement::verified(
        "joint_wheelchair_turning_and_exoskeleton_charging_clearance",
        required_combined_index,
        combined_index,
        explanation,
    );

    Ok(JointAccessibilityAssessment {
        wheelchair_turning_score,
        exoskeleton_charging_clearance_score,
        combined_index,
        capability_requirement,
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CapabilityWindow {
    pub route_start_millimeters: u64,
    pub route_end_millimeters: u64,
    pub latency_milliseconds: u16,
}

impl CapabilityWindow {
    pub fn validate(&self) -> Result<(), CorridorError> {
        if self.route_end_millimeters <= self.route_start_millimeters {
            return Err(CorridorError::InvalidCapabilityWindow {
                start_millimeters: self.route_start_millimeters,
                end_millimeters: self.route_end_millimeters,
            });
        }

        Ok(())
    }

    pub fn covers(&self, route_position_millimeters: u64) -> bool {
        self.route_start_millimeters <= route_position_millimeters
            && route_position_millimeters < self.route_end_millimeters
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BaseStationCoverage {
    pub base_station_pseudonymous_id: String,
    pub low_latency_window: CapabilityWindow,
    pub evidence_status: EvidenceStatus,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RouteSegment {
    pub route_start_millimeters: u64,
    pub route_end_millimeters: u64,
    pub selected_base_station_pseudonymous_id: Option<String>,
    pub best_available_latency_milliseconds: Option<u16>,
    pub continuity_met: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RouteContinuityAssessment {
    pub route_start_millimeters: u64,
    pub route_end_millimeters: u64,
    pub latency_limit_milliseconds: u16,
    pub covered_distance_millimeters: u64,
    pub total_distance_millimeters: u64,
    pub continuity_ratio: UnitInterval,
    pub uninterrupted: bool,
    pub route_segments: Vec<RouteSegment>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MobilityRouteAssessment {
    pub route_segments: Vec<RouteSegment>,
    pub continuity_assessment: RouteContinuityAssessment,
}

pub fn assess_route_low_latency_continuity(
    route_start_millimeters: u64,
    route_end_millimeters: u64,
    latency_limit_milliseconds: u16,
    coverages: &[BaseStationCoverage],
) -> Result<MobilityRouteAssessment, CorridorError> {
    if route_end_millimeters <= route_start_millimeters {
        return Err(CorridorError::InvalidRouteBounds {
            start_millimeters: route_start_millimeters,
            end_millimeters: route_end_millimeters,
        });
    }

    if latency_limit_milliseconds == 0 {
        return Err(CorridorError::ZeroLatencyLimit);
    }

    let mut boundaries = vec![route_start_millimeters, route_end_millimeters];

    for coverage in coverages {
        coverage.low_latency_window.validate()?;

        if coverage.evidence_status != EvidenceStatus::Verified {
            continue;
        }

        if coverage.low_latency_window.latency_milliseconds > latency_limit_milliseconds {
            continue;
        }

        boundaries.push(
            coverage
                .low_latency_window
                .route_start_millimeters
                .max(route_start_millimeters)
                .min(route_end_millimeters),
        );

        boundaries.push(
            coverage
                .low_latency_window
                .route_end_millimeters
                .max(route_start_millimeters)
                .min(route_end_millimeters),
        );
    }

    boundaries.sort_unstable();
    boundaries.dedup();

    let mut route_segments = Vec::new();
    let mut covered_distance_millimeters = 0_u64;

    for boundary_pair in boundaries.windows(2) {
        let segment_start = boundary_pair[0];
        let segment_end = boundary_pair[1];

        if segment_end <= segment_start {
            continue;
        }

        let midpoint = segment_start + (segment_end - segment_start) / 2;

        let selected_coverage = coverages
            .iter()
            .filter(|coverage| coverage.evidence_status == EvidenceStatus::Verified)
            .filter(|coverage| coverage.low_latency_window.covers(midpoint))
            .filter(|coverage| {
                coverage.low_latency_window.latency_milliseconds <= latency_limit_milliseconds
            })
            .min_by(|left, right| {
                left.low_latency_window
                    .latency_milliseconds
                    .cmp(&right.low_latency_window.latency_milliseconds)
                    .then_with(|| {
                        left.base_station_pseudonymous_id
                            .cmp(&right.base_station_pseudonymous_id)
                    })
            });

        let continuity_met = selected_coverage.is_some();

        if continuity_met {
            covered_distance_millimeters = covered_distance_millimeters
                .checked_add(segment_end - segment_start)
                .ok_or(CorridorError::ArithmeticOverflow)?;
        }

        route_segments.push(RouteSegment {
            route_start_millimeters: segment_start,
            route_end_millimeters: segment_end,
            selected_base_station_pseudonymous_id: selected_coverage
                .map(|coverage| coverage.base_station_pseudonymous_id.clone()),
            best_available_latency_milliseconds: selected_coverage
                .map(|coverage| coverage.low_latency_window.latency_milliseconds),
            continuity_met,
        });
    }

    let total_distance_millimeters = route_end_millimeters - route_start_millimeters;
    let continuity_ratio =
        UnitInterval::from_ratio(covered_distance_millimeters, total_distance_millimeters)?;

    let uninterrupted = covered_distance_millimeters == total_distance_millimeters;

    let continuity_assessment = RouteContinuityAssessment {
        route_start_millimeters,
        route_end_millimeters,
        latency_limit_milliseconds,
        covered_distance_millimeters,
        total_distance_millimeters,
        continuity_ratio,
        uninterrupted,
        route_segments: route_segments.clone(),
    };

    Ok(MobilityRouteAssessment {
        route_segments,
        continuity_assessment,
    })
}

fn capped_adequacy_score(available: u32, required: u32) -> Result<UnitInterval, CorridorError> {
    validate_positive_measurement("required_measurement", required)?;

    let capped_available = available.min(required);
    UnitInterval::from_ratio(capped_available as u64, required as u64)
}

fn validate_positive_measurement(
    field: &'static str,
    value: u32,
) -> Result<(), CorridorError> {
    if value == 0 {
        return Err(CorridorError::InvalidMeasurement {
            field,
            value,
        });
    }

    Ok(())
}

fn validate_sha256_hex(field: &'static str, value: &str) -> Result<(), CorridorError> {
    if value.len() != SHA256_HEX_LENGTH || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(CorridorError::InvalidSha256Hex {
            field,
            value: value.to_owned(),
        });
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CorridorError {
    ArithmeticOverflow,
    CrossCorridorRecord {
        expected_corridor_id: String,
        actual_corridor_id: String,
    },
    InvalidCapabilityWindow {
        start_millimeters: u64,
        end_millimeters: u64,
    },
    InvalidMeasurement {
        field: &'static str,
        value: u32,
    },
    InvalidObservationSequence,
    InvalidRatio {
        numerator: u64,
        denominator: u64,
    },
    InvalidRouteBounds {
        start_millimeters: u64,
        end_millimeters: u64,
    },
    InvalidSha256Hex {
        field: &'static str,
        value: String,
    },
    InvalidUnitInterval {
        basis_points: u16,
    },
    MissingCanonicalHash,
    MissingField {
        field: &'static str,
    },
    UnsupportedSignatureAlgorithm {
        algorithm: String,
    },
    ZeroDenominator,
    ZeroLatencyLimit,
}

impl fmt::Display for CorridorError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ArithmeticOverflow => write!(formatter, "an arithmetic operation overflowed"),
            Self::CrossCorridorRecord {
                expected_corridor_id,
                actual_corridor_id,
            } => write!(
                formatter,
                "record corridor '{}' does not match expected corridor '{}'",
                actual_corridor_id, expected_corridor_id
            ),
            Self::InvalidCapabilityWindow {
                start_millimeters,
                end_millimeters,
            } => write!(
                formatter,
                "capability window end {} must be greater than start {}",
                end_millimeters, start_millimeters
            ),
            Self::InvalidMeasurement { field, value } => {
                write!(formatter, "measurement '{}' must be positive, found {}", field, value)
            }
            Self::InvalidObservationSequence => {
                write!(formatter, "observation sequence must be greater than zero")
            }
            Self::InvalidRatio {
                numerator,
                denominator,
            } => write!(
                formatter,
                "ratio numerator {} exceeds denominator {}",
                numerator, denominator
            ),
            Self::InvalidRouteBounds {
                start_millimeters,
                end_millimeters,
            } => write!(
                formatter,
                "route end {} must be greater than route start {}",
                end_millimeters, start_millimeters
            ),
            Self::InvalidSha256Hex { field, value } => write!(
                formatter,
                "field '{}' is not a 64-character hexadecimal SHA-256 digest: '{}'",
                field, value
            ),
            Self::InvalidUnitInterval { basis_points } => write!(
                formatter,
                "basis points {} exceed the UnitInterval maximum of 10000",
                basis_points
            ),
            Self::MissingCanonicalHash => write!(formatter, "no canonical calibration hash exists"),
            Self::MissingField { field } => write!(formatter, "field '{}' is required", field),
            Self::UnsupportedSignatureAlgorithm { algorithm } => write!(
                formatter,
                "signature algorithm '{}' is not supported; Ed25519 is required",
                algorithm
            ),
            Self::ZeroDenominator => write!(formatter, "ratio denominator must not be zero"),
            Self::ZeroLatencyLimit => write!(formatter, "latency limit must be greater than zero"),
        }
    }
}

impl std::error::Error for CorridorError {}

#[cfg(test)]
mod tests {
    use super::*;

    const CALIBRATION_HASH_A: &str =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const CALIBRATION_HASH_B: &str =
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const PAYLOAD_HASH: &str =
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
    const KEY_FINGERPRINT: &str =
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";

    fn signed_record(
        sensor_pseudonymous_id: &str,
        corridor_id: &str,
        calibration_hash: &str,
    ) -> ProvenanceRecord {
        ProvenanceRecord {
            sensor_pseudonymous_id: sensor_pseudonymous_id.to_owned(),
            corridor_id: corridor_id.to_owned(),
            observation_sequence: 1,
            observed_at_unix_seconds: 1_700_000_000,
            payload_sha256_hex: PAYLOAD_HASH.to_owned(),
            last_calibration_certificate_sha256_hex: calibration_hash.to_owned(),
            device_public_key_fingerprint_sha256_hex: KEY_FINGERPRINT.to_owned(),
            signature_algorithm: "Ed25519".to_owned(),
            signature_base64url: "signed-evidence-placeholder-for-verified-ingestion".to_owned(),
            evidence_status: EvidenceStatus::Verified,
        }
    }

    #[test]
    fn quarantines_when_inconsistent_hashes_exceed_ten_percent() {
        let records = vec![
            signed_record("sensor-a", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-b", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-c", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-d", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-e", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-f", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-g", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-h", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-i", "green-corridor", CALIBRATION_HASH_B),
            signed_record("sensor-j", "green-corridor", CALIBRATION_HASH_B),
        ];

        let assessment =
            assess_corridor_calibration_consistency("green-corridor", &records).unwrap();

        assert!(assessment.quarantine_required);
        assert_eq!(assessment.inconsistency_ratio.basis_points(), 2_000);
        assert_eq!(
            assessment.inconsistent_sensor_ids,
            vec!["sensor-i".to_owned(), "sensor-j".to_owned()]
        );
    }

    #[test]
    fn exactly_ten_percent_inconsistency_does_not_trigger_quarantine() {
        let records = vec![
            signed_record("sensor-a", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-b", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-c", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-d", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-e", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-f", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-g", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-h", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-i", "green-corridor", CALIBRATION_HASH_A),
            signed_record("sensor-j", "green-corridor", CALIBRATION_HASH_B),
        ];

        let assessment =
            assess_corridor_calibration_consistency("green-corridor", &records).unwrap();

        assert!(!assessment.quarantine_required);
        assert_eq!(assessment.inconsistency_ratio.basis_points(), 1_000);
    }

    #[test]
    fn joint_accessibility_fails_when_charging_clearance_is_insufficient() {
        let assessment = assess_joint_accessibility(
            SidewalkAccessibilityMeasurements {
                available_turning_radius_millimeters: 1_800,
                required_turning_radius_millimeters: 1_500,
                available_charging_clearance_millimeters: 600,
                required_charging_clearance_millimeters: 1_000,
            },
            UnitInterval::from_basis_points(10_000).unwrap(),
        )
        .unwrap();

        assert_eq!(assessment.wheelchair_turning_score, UnitInterval::ONE);
        assert_eq!(
            assessment.exoskeleton_charging_clearance_score,
            UnitInterval::from_basis_points(6_000).unwrap()
        );
        assert_eq!(
            assessment.combined_index,
            UnitInterval::from_basis_points(6_000).unwrap()
        );
        assert_eq!(
            assessment.capability_requirement.evidence_status,
            EvidenceStatus::Verified
        );
        assert!(!assessment.capability_requirement.satisfied);
    }

    #[test]
    fn seamless_overlap_preserves_route_continuity_below_twenty_milliseconds() {
        let coverages = vec![
            BaseStationCoverage {
                base_station_pseudonymous_id: "tower-west".to_owned(),
                low_latency_window: CapabilityWindow {
                    route_start_millimeters: 0,
                    route_end_millimeters: 6_000_000,
                    latency_milliseconds: 18,
                },
                evidence_status: EvidenceStatus::Verified,
            },
            BaseStationCoverage {
                base_station_pseudonymous_id: "tower-east".to_owned(),
                low_latency_window: CapabilityWindow {
                    route_start_millimeters: 5_500_000,
                    route_end_millimeters: 10_000_000,
                    latency_milliseconds: 16,
                },
                evidence_status: EvidenceStatus::Verified,
            },
        ];

        let result =
            assess_route_low_latency_continuity(0, 10_000_000, 20, &coverages).unwrap();

        assert!(result.continuity_assessment.uninterrupted);
        assert_eq!(
            result.continuity_assessment.continuity_ratio,
            UnitInterval::ONE
        );
        assert_eq!(result.route_segments.len(), 3);
        assert_eq!(
            result.route_segments[1]
                .selected_base_station_pseudonymous_id
                .as_deref(),
            Some("tower-east")
        );
    }

    #[test]
    fn coverage_gap_reduces_route_continuity_ratio() {
        let coverages = vec![
            BaseStationCoverage {
                base_station_pseudonymous_id: "tower-west".to_owned(),
                low_latency_window: CapabilityWindow {
                    route_start_millimeters: 0,
                    route_end_millimeters: 4_000_000,
                    latency_milliseconds: 12,
                },
                evidence_status: EvidenceStatus::Verified,
            },
            BaseStationCoverage {
                base_station_pseudonymous_id: "tower-east".to_owned(),
                low_latency_window: CapabilityWindow {
                    route_start_millimeters: 5_000_000,
                    route_end_millimeters: 10_000_000,
                    latency_milliseconds: 19,
                },
                evidence_status: EvidenceStatus::Verified,
            },
        ];

        let result =
            assess_route_low_latency_continuity(0, 10_000_000, 20, &coverages).unwrap();

        assert!(!result.continuity_assessment.uninterrupted);
        assert_eq!(
            result.continuity_assessment.continuity_ratio,
            UnitInterval::from_basis_points(9_000).unwrap()
        );
        assert!(!result.route_segments[1].continuity_met);
    }

    #[test]
    fn latency_above_limit_does_not_count_as_continuous_coverage() {
        let coverages = vec![BaseStationCoverage {
            base_station_pseudonymous_id: "tower-high-latency".to_owned(),
            low_latency_window: CapabilityWindow {
                route_start_millimeters: 0,
                route_end_millimeters: 1_000_000,
                latency_milliseconds: 21,
            },
            evidence_status: EvidenceStatus::Verified,
        }];

        let result =
            assess_route_low_latency_continuity(0, 1_000_000, 20, &coverages).unwrap();

        assert!(!result.continuity_assessment.uninterrupted);
        assert_eq!(
            result.continuity_assessment.continuity_ratio,
            UnitInterval::ZERO
        );
    }

    #[test]
    fn constant_is_expressed_in_milliseconds_for_explicit_unit_safety() {
        assert_eq!(MILLIS_PER_SECOND, 1_000);
    }
}

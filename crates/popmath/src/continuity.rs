use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};
use crate::time::{TimeWindow, UtcTimestamp};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum CapabilityKind {
    AccessiblePath,
    ContinuousPower,
    LocalBackupPower,
    NetworkConnectivity,
    LowLatencyConnectivity,
    ChargingAvailability,
    ElectromagneticInterferenceLow,
    LowNoiseEnvironment,
    EnvironmentalCompatibility,
    HumanSupportAvailability,
    OfflineServiceAvailability,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum EvidenceStatus {
    Unknown,
    Assumed,
    Verified,
}

impl EvidenceStatus {
    #[must_use]
    pub const fn satisfies(self, required: Self) -> bool {
        self >= required
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CapabilityRequirement {
    pub kind: CapabilityKind,
    pub minimum_availability: UnitInterval,
    pub maximum_gap_seconds: NonNegativeF64,
    pub required_evidence: EvidenceStatus,
}

impl CapabilityRequirement {
    pub fn new(
        kind: CapabilityKind,
        minimum_availability: UnitInterval,
        maximum_gap_seconds: NonNegativeF64,
        required_evidence: EvidenceStatus,
    ) -> Self {
        Self {
            kind,
            minimum_availability,
            maximum_gap_seconds,
            required_evidence,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum CapabilityExpression {
    Requirement(CapabilityRequirement),
    All(Vec<CapabilityExpression>),
    Any(Vec<CapabilityExpression>),
}

impl CapabilityExpression {
    #[must_use]
    pub const fn requirement(requirement: CapabilityRequirement) -> Self {
        Self::Requirement(requirement)
    }

    pub fn all(expressions: Vec<CapabilityExpression>) -> PopmathResult<Self> {
        if expressions.is_empty() {
            return Err(PopmathError::InvalidScenario {
                reason: "an all expression requires at least one capability expression",
            });
        }

        Ok(Self::All(expressions))
    }

    pub fn any(expressions: Vec<CapabilityExpression>) -> PopmathResult<Self> {
        if expressions.is_empty() {
            return Err(PopmathError::InvalidScenario {
                reason: "an any expression requires at least one capability expression",
            });
        }

        Ok(Self::Any(expressions))
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CapabilityWindow {
    pub kind: CapabilityKind,
    pub window: TimeWindow,
    pub evidence: EvidenceStatus,
    pub available: bool,
}

impl CapabilityWindow {
    #[must_use]
    pub const fn new(
        kind: CapabilityKind,
        window: TimeWindow,
        evidence: EvidenceStatus,
        available: bool,
    ) -> Self {
        Self {
            kind,
            window,
            evidence,
            available,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContinuityStatus {
    Met,
    ConditionallyMet,
    Unmet,
    InsufficientEvidence,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CapabilityContinuityResult {
    pub kind: CapabilityKind,
    pub availability_ratio: UnitInterval,
    pub verification_ratio: UnitInterval,
    pub unmet_seconds: NonNegativeF64,
    pub longest_gap_seconds: NonNegativeF64,
    pub status: ContinuityStatus,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ContinuityAssessment {
    pub window: TimeWindow,
    pub availability_ratio: UnitInterval,
    pub verification_ratio: UnitInterval,
    pub unmet_seconds: NonNegativeF64,
    pub longest_gap_seconds: NonNegativeF64,
    pub capability_results: Vec<CapabilityContinuityResult>,
    pub overall_status: ContinuityStatus,
    pub explanation: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct EvaluatedInterval {
    window: TimeWindow,
    available: bool,
    evidence: EvidenceStatus,
}

pub fn assess_continuity(
    requested_window: TimeWindow,
    requirements: &[CapabilityRequirement],
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<ContinuityAssessment> {
    if requirements.is_empty() {
        return Err(PopmathError::InvalidScenario {
            reason: "at least one capability requirement is required",
        });
    }

    let mut results = Vec::with_capacity(requirements.len());

    for requirement in requirements {
        results.push(evaluate_flat_requirement(
            requested_window,
            *requirement,
            capability_windows,
        )?);
    }

    let overall_status = derive_overall_status(&results);
    let availability_ratio = minimum_availability(&results)?;
    let verification_ratio = minimum_verification(&results)?;
    let unmet_seconds = maximum_unmet_seconds(&results)?;
    let longest_gap_seconds = maximum_gap_seconds(&results)?;
    let explanation = build_flat_explanation(overall_status, &results);

    Ok(ContinuityAssessment {
        window: requested_window,
        availability_ratio,
        verification_ratio,
        unmet_seconds,
        longest_gap_seconds,
        capability_results: results,
        overall_status,
        explanation,
    })
}

pub fn assess_continuity_expression(
    requested_window: TimeWindow,
    expression: &CapabilityExpression,
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<ContinuityAssessment> {
    let evaluated = evaluate_expression(requested_window, expression, capability_windows)?;
    let aggregate = calculate_interval_metrics(requested_window, &evaluated)?;
    let capability_results =
        collect_requirement_results(requested_window, expression, capability_windows)?;
    let explanation = build_expression_explanation(aggregate.status);

    Ok(ContinuityAssessment {
        window: requested_window,
        availability_ratio: aggregate.availability_ratio,
        verification_ratio: aggregate.verification_ratio,
        unmet_seconds: aggregate.unmet_seconds,
        longest_gap_seconds: aggregate.longest_gap_seconds,
        capability_results,
        overall_status: aggregate.status,
        explanation,
    })
}

fn evaluate_flat_requirement(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<CapabilityContinuityResult> {
    let intervals = evaluate_requirement(requested_window, requirement, capability_windows)?;
    let metrics = calculate_interval_metrics(requested_window, &intervals)?;
    let status = classify_requirement_status(metrics, requirement);

    Ok(CapabilityContinuityResult {
        kind: requirement.kind,
        availability_ratio: metrics.availability_ratio,
        verification_ratio: metrics.verification_ratio,
        unmet_seconds: metrics.unmet_seconds,
        longest_gap_seconds: metrics.longest_gap_seconds,
        status,
    })
}

fn evaluate_expression(
    requested_window: TimeWindow,
    expression: &CapabilityExpression,
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<Vec<EvaluatedInterval>> {
    match expression {
        CapabilityExpression::Requirement(requirement) => {
            evaluate_requirement(requested_window, *requirement, capability_windows)
        }
        CapabilityExpression::All(children) => {
            evaluate_children(requested_window, children, capability_windows, true)
        }
        CapabilityExpression::Any(children) => {
            evaluate_children(requested_window, children, capability_windows, false)
        }
    }
}

fn evaluate_children(
    requested_window: TimeWindow,
    children: &[CapabilityExpression],
    capability_windows: &[CapabilityWindow],
    require_all: bool,
) -> PopmathResult<Vec<EvaluatedInterval>> {
    if children.is_empty() {
        return Err(PopmathError::InvalidScenario {
            reason: "capability expression requires at least one child",
        });
    }

    let mut child_sets = Vec::with_capacity(children.len());

    for child in children {
        child_sets.push(evaluate_expression(
            requested_window,
            child,
            capability_windows,
        )?);
    }

    compose_intervals(requested_window, &child_sets, require_all)
}

fn evaluate_requirement(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<Vec<EvaluatedInterval>> {
    let mut candidates = Vec::new();

    for candidate in capability_windows {
        if candidate.kind != requirement.kind {
            continue;
        }

        if !candidate.evidence.satisfies(requirement.required_evidence) {
            continue;
        }

        if let Some(window) = intersect_windows(requested_window, candidate.window) {
            candidates.push(EvaluatedInterval {
                window,
                available: candidate.available,
                evidence: candidate.evidence,
            });
        }
    }

    normalize_intervals(requested_window, &candidates)
}

fn normalize_intervals(
    requested_window: TimeWindow,
    intervals: &[EvaluatedInterval],
) -> PopmathResult<Vec<EvaluatedInterval>> {
    let boundaries = collect_boundaries(requested_window, intervals)?;
    let mut normalized = Vec::new();

    for pair in boundaries.windows(2) {
        let segment = TimeWindow::new(pair[0], pair[1])?;
        let mut available = false;
        let mut evidence = EvidenceStatus::Unknown;

        for interval in intervals {
            if contains_window(interval.window, segment) && interval.available {
                available = true;
                evidence = evidence.max(interval.evidence);
            }
        }

        push_or_merge(
            &mut normalized,
            EvaluatedInterval {
                window: segment,
                available,
                evidence,
            },
        )?;
    }

    Ok(normalized)
}

fn compose_intervals(
    requested_window: TimeWindow,
    child_sets: &[Vec<EvaluatedInterval>],
    require_all: bool,
) -> PopmathResult<Vec<EvaluatedInterval>> {
    if child_sets.is_empty() {
        return Err(PopmathError::InvalidScenario {
            reason: "capability composition requires at least one child interval set",
        });
    }

    let mut all_intervals = Vec::new();

    for child_set in child_sets {
        all_intervals.extend_from_slice(child_set);
    }

    let boundaries = collect_boundaries(requested_window, &all_intervals)?;
    let mut composed = Vec::new();

    for pair in boundaries.windows(2) {
        let segment = TimeWindow::new(pair[0], pair[1])?;
        let mut child_states = Vec::with_capacity(child_sets.len());

        for child_set in child_sets {
            child_states.push(state_for_segment(child_set, segment));
        }

        let available = if require_all {
            child_states.iter().all(|state| state.available)
        } else {
            child_states.iter().any(|state| state.available)
        };

        let evidence = combined_evidence(&child_states, available, require_all);

        push_or_merge(
            &mut composed,
            EvaluatedInterval {
                window: segment,
                available,
                evidence,
            },
        )?;
    }

    Ok(composed)
}

fn combined_evidence(
    child_states: &[EvaluatedInterval],
    available: bool,
    require_all: bool,
) -> EvidenceStatus {
    if !available {
        return EvidenceStatus::Unknown;
    }

    if require_all {
        child_states
            .iter()
            .filter(|state| state.available)
            .map(|state| state.evidence)
            .min()
            .unwrap_or(EvidenceStatus::Unknown)
    } else {
        child_states
            .iter()
            .filter(|state| state.available)
            .map(|state| state.evidence)
            .max()
            .unwrap_or(EvidenceStatus::Unknown)
    }
}

fn state_for_segment(
    intervals: &[EvaluatedInterval],
    segment: TimeWindow,
) -> EvaluatedInterval {
    intervals
        .iter()
        .copied()
        .find(|interval| contains_window(interval.window, segment))
        .unwrap_or(EvaluatedInterval {
            window: segment,
            available: false,
            evidence: EvidenceStatus::Unknown,
        })
}

fn calculate_interval_metrics(
    requested_window: TimeWindow,
    intervals: &[EvaluatedInterval],
) -> PopmathResult<IntervalMetrics> {
    let total_seconds = window_seconds(requested_window)?;

    if total_seconds <= 0.0 {
        return Err(PopmathError::InvalidScenario {
            reason: "continuity assessment requires a non-empty time window",
        });
    }

    let mut available_seconds = 0.0_f64;
    let mut verified_seconds = 0.0_f64;
    let mut current_gap_seconds = 0.0_f64;
    let mut longest_gap_seconds = 0.0_f64;

    for interval in intervals {
        let seconds = window_seconds(interval.window)?;

        if interval.available {
            available_seconds += seconds;

            if interval.evidence == EvidenceStatus::Verified {
                verified_seconds += seconds;
            }

            current_gap_seconds = 0.0;
        } else {
            current_gap_seconds += seconds;
            longest_gap_seconds = longest_gap_seconds.max(current_gap_seconds);
        }
    }

    let available_seconds = available_seconds.min(total_seconds);
    let verified_seconds = verified_seconds.min(total_seconds);
    let unmet_seconds = (total_seconds - available_seconds).max(0.0);

    let availability_ratio = UnitInterval::new(
        available_seconds / total_seconds,
        "continuity availability ratio",
    )?;
    let verification_ratio = UnitInterval::new(
        verified_seconds / total_seconds,
        "continuity verification ratio",
    )?;

    Ok(IntervalMetrics {
        availability_ratio,
        verification_ratio,
        unmet_seconds: NonNegativeF64::new(unmet_seconds, "continuity unmet seconds")?,
        longest_gap_seconds: NonNegativeF64::new(
            longest_gap_seconds,
            "continuity longest gap seconds",
        )?,
        status: classify_expression_status(
            availability_ratio,
            verification_ratio,
            NonNegativeF64::new(longest_gap_seconds, "continuity longest gap seconds")?,
        ),
    })
}

fn classify_requirement_status(
    metrics: IntervalMetrics,
    requirement: CapabilityRequirement,
) -> ContinuityStatus {
    if metrics.verification_ratio.get() < requirement.minimum_availability.get() {
        return ContinuityStatus::InsufficientEvidence;
    }

    if metrics.availability_ratio.get() < requirement.minimum_availability.get()
        || metrics.longest_gap_seconds.get() > requirement.maximum_gap_seconds.get()
    {
        return ContinuityStatus::Unmet;
    }

    if metrics.verification_ratio.get() < 1.0 {
        return ContinuityStatus::ConditionallyMet;
    }

    ContinuityStatus::Met
}

fn classify_expression_status(
    availability_ratio: UnitInterval,
    verification_ratio: UnitInterval,
    longest_gap_seconds: NonNegativeF64,
) -> ContinuityStatus {
    if availability_ratio.get() < 1.0 || longest_gap_seconds.get() > 0.0 {
        return ContinuityStatus::Unmet;
    }

    if verification_ratio.get() < 1.0 {
        return ContinuityStatus::ConditionallyMet;
    }

    ContinuityStatus::Met
}

fn collect_requirement_results(
    requested_window: TimeWindow,
    expression: &CapabilityExpression,
    capability_windows: &[CapabilityWindow],
) -> PopmathResult<Vec<CapabilityContinuityResult>> {
    let mut requirements = Vec::new();
    collect_requirements(expression, &mut requirements);

    let mut results = Vec::with_capacity(requirements.len());

    for requirement in requirements {
        results.push(evaluate_flat_requirement(
            requested_window,
            requirement,
            capability_windows,
        )?);
    }

    Ok(results)
}

fn collect_requirements(
    expression: &CapabilityExpression,
    requirements: &mut Vec<CapabilityRequirement>,
) {
    match expression {
        CapabilityExpression::Requirement(requirement) => requirements.push(*requirement),
        CapabilityExpression::All(children) | CapabilityExpression::Any(children) => {
            for child in children {
                collect_requirements(child, requirements);
            }
        }
    }
}

fn minimum_availability(results: &[CapabilityContinuityResult]) -> PopmathResult<UnitInterval> {
    let value = results
        .iter()
        .map(|result| result.availability_ratio.get())
        .fold(1.0_f64, f64::min);

    UnitInterval::new(value, "overall continuity availability ratio")
}

fn minimum_verification(results: &[CapabilityContinuityResult]) -> PopmathResult<UnitInterval> {
    let value = results
        .iter()
        .map(|result| result.verification_ratio.get())
        .fold(1.0_f64, f64::min);

    UnitInterval::new(value, "overall continuity verification ratio")
}

fn maximum_unmet_seconds(
    results: &[CapabilityContinuityResult],
) -> PopmathResult<NonNegativeF64> {
    let value = results
        .iter()
        .map(|result| result.unmet_seconds.get())
        .fold(0.0_f64, f64::max);

    NonNegativeF64::new(value, "overall continuity unmet seconds")
}

fn maximum_gap_seconds(
    results: &[CapabilityContinuityResult],
) -> PopmathResult<NonNegativeF64> {
    let value = results
        .iter()
        .map(|result| result.longest_gap_seconds.get())
        .fold(0.0_f64, f64::max);

    NonNegativeF64::new(value, "overall continuity longest gap seconds")
}

fn derive_overall_status(results: &[CapabilityContinuityResult]) -> ContinuityStatus {
    if results
        .iter()
        .any(|result| result.status == ContinuityStatus::InsufficientEvidence)
    {
        return ContinuityStatus::InsufficientEvidence;
    }

    if results
        .iter()
        .any(|result| result.status == ContinuityStatus::Unmet)
    {
        return ContinuityStatus::Unmet;
    }

    if results
        .iter()
        .any(|result| result.status == ContinuityStatus::ConditionallyMet)
    {
        return ContinuityStatus::ConditionallyMet;
    }

    ContinuityStatus::Met
}

fn build_flat_explanation(
    status: ContinuityStatus,
    results: &[CapabilityContinuityResult],
) -> String {
    match status {
        ContinuityStatus::Met => String::from(
            "All declared capability requirements were satisfied across the full time window with verified evidence.",
        ),
        ContinuityStatus::ConditionallyMet => String::from(
            "All declared capability requirements were satisfied, with one or more intervals supported by assumed evidence.",
        ),
        ContinuityStatus::Unmet => {
            let name = results
                .iter()
                .find(|result| result.status == ContinuityStatus::Unmet)
                .map(|result| capability_name(result.kind))
                .unwrap_or("a required capability");

            alloc::format!(
                "The scenario did not meet the declared continuity threshold for {}.",
                name
            )
        }
        ContinuityStatus::InsufficientEvidence => {
            let name = results
                .iter()
                .find(|result| result.status == ContinuityStatus::InsufficientEvidence)
                .map(|result| capability_name(result.kind))
                .unwrap_or("a required capability");

            alloc::format!(
                "The scenario does not have enough verified coverage to determine continuity for {}.",
                name
            )
        }
    }
}

fn build_expression_explanation(status: ContinuityStatus) -> String {
    match status {
        ContinuityStatus::Met => String::from(
            "The declared capability expression was continuously satisfied with verified evidence.",
        ),
        ContinuityStatus::ConditionallyMet => String::from(
            "The declared capability expression was continuously satisfied, with one or more intervals supported by assumed evidence.",
        ),
        ContinuityStatus::Unmet => String::from(
            "The declared capability expression was not continuously satisfied across the requested time window.",
        ),
        ContinuityStatus::InsufficientEvidence => String::from(
            "The declared capability expression does not have enough verified coverage for a decision-ready continuity determination.",
        ),
    }
}

fn capability_name(kind: CapabilityKind) -> &'static str {
    match kind {
        CapabilityKind::AccessiblePath => "accessible-path availability",
        CapabilityKind::ContinuousPower => "continuous power",
        CapabilityKind::LocalBackupPower => "local backup power",
        CapabilityKind::NetworkConnectivity => "network connectivity",
        CapabilityKind::LowLatencyConnectivity => "low-latency connectivity",
        CapabilityKind::ChargingAvailability => "charging availability",
        CapabilityKind::ElectromagneticInterferenceLow => "low electromagnetic interference",
        CapabilityKind::EnvironmentalCompatibility => "environmental compatibility",
        CapabilityKind::HumanSupportAvailability => "human support availability",
        CapabilityKind::OfflineServiceAvailability => "offline-service availability",
    }
}

fn collect_boundaries(
    requested_window: TimeWindow,
    intervals: &[EvaluatedInterval],
) -> PopmathResult<Vec<UtcTimestamp>> {
    let mut boundaries = Vec::with_capacity(intervals.len().saturating_mul(2).saturating_add(2));
    boundaries.push(requested_window.start());
    boundaries.push(requested_window.end());

    for interval in intervals {
        if let Some(intersection) = intersect_windows(requested_window, interval.window) {
            boundaries.push(intersection.start());
            boundaries.push(intersection.end());
        }
    }

    boundaries.sort_unstable();
    boundaries.dedup();

    if boundaries.len() < 2 {
        return Err(PopmathError::InvalidScenario {
            reason: "continuity assessment requires at least two unique time boundaries",
        });
    }

    Ok(boundaries)
}

fn push_or_merge(
    intervals: &mut Vec<EvaluatedInterval>,
    next: EvaluatedInterval,
) -> PopmathResult<()> {
    if let Some(last) = intervals.last_mut() {
        if last.available == next.available
            && last.evidence == next.evidence
            && last.window.end() == next.window.start()
        {
            last.window = TimeWindow::new(last.window.start(), next.window.end())?;
            return Ok(());
        }
    }

    intervals.push(next);
    Ok(())
}

fn intersect_windows(left: TimeWindow, right: TimeWindow) -> Option<TimeWindow> {
    let start = left.start().max(right.start());
    let end = left.end().min(right.end());

    if start >= end {
        return None;
    }

    TimeWindow::new(start, end).ok()
}

fn contains_window(container: TimeWindow, candidate: TimeWindow) -> bool {
    container.start() <= candidate.start() && candidate.end() <= container.end()
}

fn window_seconds(window: TimeWindow) -> PopmathResult<f64> {
    let seconds = window
        .end()
        .seconds_since_epoch()
        .checked_sub(window.start().seconds_since_epoch())
        .ok_or(PopmathError::InvalidScenario {
            reason: "time window end precedes time window start",
        })?;

    NonNegativeF64::new(seconds as f64, "time window duration seconds").map(|value| value.get())
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct IntervalMetrics {
    availability_ratio: UnitInterval,
    verification_ratio: UnitInterval,
    unmet_seconds: NonNegativeF64,
    longest_gap_seconds: NonNegativeF64,
    status: ContinuityStatus,
}

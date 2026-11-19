from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log10
from typing import Iterable, Sequence


LN_10 = 2.302585092994046
SECONDS_PER_HOUR = 3_600.0


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within the closed interval [0, 1].")


@dataclass(frozen=True)
class HexEdgeFlux:
    """
    Species-specific directional establishment flux across one shared hex edge.

    Flux may be estimated from marked movement, seed dispersal, occupancy
    transitions, genetic connectivity, or a validated mechanistic model.
    Units must be identical in both directions, for example:
      established propagules per metre-edge per day, or
      successful movement events per metre-edge per season.
    """

    hexagon_a: str
    hexagon_b: str
    flux_a_to_b: float
    flux_b_to_a: float
    reference_flux_max: float
    target_species_median_mobility_m: float
    inter_patch_gap_m: float
    reproductive_cycle_days: float

    def __post_init__(self) -> None:
        for name, value in (
            ("flux_a_to_b", self.flux_a_to_b),
            ("flux_b_to_a", self.flux_b_to_a),
            ("reference_flux_max", self.reference_flux_max),
            ("target_species_median_mobility_m", self.target_species_median_mobility_m),
            ("inter_patch_gap_m", self.inter_patch_gap_m),
            ("reproductive_cycle_days", self.reproductive_cycle_days),
        ):
            _nonnegative(name, value)

        _positive("reference_flux_max", self.reference_flux_max)
        _positive("target_species_median_mobility_m", self.target_species_median_mobility_m)
        _positive("reproductive_cycle_days", self.reproductive_cycle_days)


@dataclass(frozen=True)
class CorridorContinuityResult:
    relative_edge_flux_discontinuity: float
    mobility_ratio: float
    required_continuity_threshold: float
    edge_is_continuous: bool
    rationale: str


def species_calibrated_continuity_threshold(
    target_species_median_mobility_m: float,
    inter_patch_gap_m: float,
    base_threshold: float = 0.15,
    minimum_threshold: float = 0.05,
    maximum_threshold: float = 0.30,
) -> float:
    """
    Derive a conservative directional-flux imbalance tolerance.

      mobility_ratio = mobility / gap

      epsilon_species =
        clamp(base_threshold * min(1, mobility_ratio),
              minimum_threshold,
              maximum_threshold)

    Interpretation:
      - Low-mobility species crossing large gaps require near-symmetric,
        strongly continuous exchange, so epsilon contracts toward 0.05.
      - Species whose median mobility comfortably exceeds the gap can tolerate
        more directional asymmetry, up to the declared maximum.

    This is a planning threshold, not a universal ecological constant. It must
    be calibrated to empirical movement, demographic persistence, and habitat
    quality for the selected focal species or guild.
    """
    _positive("target_species_median_mobility_m", target_species_median_mobility_m)
    _positive("inter_patch_gap_m", inter_patch_gap_m)
    _unit_interval("base_threshold", base_threshold)
    _unit_interval("minimum_threshold", minimum_threshold)
    _unit_interval("maximum_threshold", maximum_threshold)
    if minimum_threshold > maximum_threshold:
        raise ValueError("minimum_threshold must not exceed maximum_threshold.")

    mobility_ratio = target_species_median_mobility_m / inter_patch_gap_m
    raw_threshold = base_threshold * min(1.0, mobility_ratio)
    return max(minimum_threshold, min(maximum_threshold, raw_threshold))


def assess_hex_edge_continuity(edge: HexEdgeFlux) -> CorridorContinuityResult:
    """
    Apply the object condition:

      |J_veg(i->j) - J_veg(j->i)| / J_max < epsilon_continuity

    J_max is a species-, season-, and edge-class-specific high-functioning
    reference flux. The denominator is therefore not silently derived from the
    observed edge being assessed.
    """
    discontinuity = abs(edge.flux_a_to_b - edge.flux_b_to_a) / edge.reference_flux_max
    mobility_ratio = edge.target_species_median_mobility_m / max(
        edge.inter_patch_gap_m, 1e-12
    )
    threshold = species_calibrated_continuity_threshold(
        target_species_median_mobility_m=edge.target_species_median_mobility_m,
        inter_patch_gap_m=edge.inter_patch_gap_m,
    )
    continuous = discontinuity < threshold

    if mobility_ratio < 1.0:
        rationale = (
            "The focal species' median movement scale is smaller than the "
            "inter-patch gap, so continuity requires a low directional flux "
            "imbalance and complementary stepping-stone habitat."
        )
    else:
        rationale = (
            "The focal species' median movement scale reaches or exceeds the "
            "inter-patch gap, allowing modest directional asymmetry while "
            "still requiring measured cross-edge establishment."
        )

    return CorridorContinuityResult(
        relative_edge_flux_discontinuity=discontinuity,
        mobility_ratio=mobility_ratio,
        required_continuity_threshold=threshold,
        edge_is_continuous=continuous,
        rationale=rationale,
    )


@dataclass(frozen=True)
class MonsoonCoolingInputs:
    """
    One decision interval, typically five to fifteen minutes.

    relative_humidity_percent:
        Ambient, pre-operation RH from an upwind/reference sensor.

    near_node_relative_humidity_percent:
        RH at an accessible downwind receptor point, used only as an aggregate
        environmental condition. It is not a proxy for any person's exposure.

    predicted_wbgt_reduction_c:
        Counterfactual predicted benefit for this interval, from a calibrated
        thermal model or site measurement.

    added_relative_humidity_percent:
        Expected RH increase from operation at the receptor point.
    """

    relative_humidity_percent: float
    near_node_relative_humidity_percent: float
    predicted_wbgt_reduction_c: float
    added_relative_humidity_percent: float
    interval_minutes: float

    def __post_init__(self) -> None:
        for name, value in (
            ("relative_humidity_percent", self.relative_humidity_percent),
            (
                "near_node_relative_humidity_percent",
                self.near_node_relative_humidity_percent,
            ),
            ("predicted_wbgt_reduction_c", self.predicted_wbgt_reduction_c),
            ("added_relative_humidity_percent", self.added_relative_humidity_percent),
            ("interval_minutes", self.interval_minutes),
        ):
            _nonnegative(name, value)

        if self.relative_humidity_percent > 100.0:
            raise ValueError("relative_humidity_percent must not exceed 100.")
        if self.near_node_relative_humidity_percent > 100.0:
            raise ValueError("near_node_relative_humidity_percent must not exceed 100.")
        if self.added_relative_humidity_percent > 100.0:
            raise ValueError("added_relative_humidity_percent must not exceed 100.")
        _positive("interval_minutes", self.interval_minutes)


@dataclass(frozen=True)
class CoolingSwitchPolicy:
    """
    Humidity-hysteresis and seasonal elevated-humidity budget.

    Disabling threshold:
      RH >= rh_critical_percent

    Re-enable threshold:
      RH <= rh_critical_percent - hysteresis_percent

    The 70% threshold is a public-health/comfort guardrail for near-node
    humidity accumulation, not a claim that 70% RH is intrinsically safe or
    unsafe in every thermal and microbial context.
    """

    rh_critical_percent: float
    hysteresis_percent: float
    elevated_rh_limit_percent: float = 70.0
    elevated_rh_budget_hours: float = 30.0
    minimum_predicted_wbgt_reduction_c: float = 0.10

    def __post_init__(self) -> None:
        for name, value in (
            ("rh_critical_percent", self.rh_critical_percent),
            ("hysteresis_percent", self.hysteresis_percent),
            ("elevated_rh_limit_percent", self.elevated_rh_limit_percent),
            ("elevated_rh_budget_hours", self.elevated_rh_budget_hours),
            (
                "minimum_predicted_wbgt_reduction_c",
                self.minimum_predicted_wbgt_reduction_c,
            ),
        ):
            _nonnegative(name, value)

        if self.rh_critical_percent > 100.0:
            raise ValueError("rh_critical_percent must not exceed 100.")
        if self.elevated_rh_limit_percent > 100.0:
            raise ValueError("elevated_rh_limit_percent must not exceed 100.")
        if self.hysteresis_percent >= self.rh_critical_percent:
            raise ValueError(
                "hysteresis_percent must be less than rh_critical_percent."
            )


@dataclass(frozen=True)
class CoolingSwitchDecision:
    enabled: bool
    reason: str
    accumulated_elevated_rh_hours: float


def decide_cooling_switch(
    prior_enabled: bool,
    policy: CoolingSwitchPolicy,
    inputs: MonsoonCoolingInputs,
    accumulated_elevated_rh_hours: float,
) -> CoolingSwitchDecision:
    """
    Deterministic hysteresis controller with a non-bypassable seasonal budget.

    This function intentionally prioritizes the humidity budget and predicted
    benefit floor over the prior switch state. It does not automatically
    activate hardware; it produces a reviewable eligibility decision.
    """
    _nonnegative(
        "accumulated_elevated_rh_hours",
        accumulated_elevated_rh_hours,
    )

    reenable_threshold = policy.rh_critical_percent - policy.hysteresis_percent
    projected_receptor_rh = min(
        100.0,
        inputs.near_node_relative_humidity_percent
        + inputs.added_relative_humidity_percent,
    )
    projected_elevated_hours = accumulated_elevated_rh_hours
    if projected_receptor_rh > policy.elevated_rh_limit_percent:
        projected_elevated_hours += inputs.interval_minutes / 60.0

    if projected_elevated_hours > policy.elevated_rh_budget_hours:
        return CoolingSwitchDecision(
            enabled=False,
            reason="seasonal_near_node_elevated_humidity_budget_exhausted",
            accumulated_elevated_rh_hours=projected_elevated_hours,
        )

    if inputs.predicted_wbgt_reduction_c < policy.minimum_predicted_wbgt_reduction_c:
        return CoolingSwitchDecision(
            enabled=False,
            reason="predicted_cooling_benefit_below_operational_floor",
            accumulated_elevated_rh_hours=projected_elevated_hours,
        )

    if prior_enabled and inputs.relative_humidity_percent >= policy.rh_critical_percent:
        return CoolingSwitchDecision(
            enabled=False,
            reason="ambient_humidity_reached_disable_threshold",
            accumulated_elevated_rh_hours=projected_elevated_hours,
        )

    if not prior_enabled and inputs.relative_humidity_percent > reenable_threshold:
        return CoolingSwitchDecision(
            enabled=False,
            reason="ambient_humidity_above_hysteretic_reenable_threshold",
            accumulated_elevated_rh_hours=projected_elevated_hours,
        )

    return CoolingSwitchDecision(
        enabled=True,
        reason="within_humidity_and_cooling_benefit_corridors",
        accumulated_elevated_rh_hours=projected_elevated_hours,
    )


@dataclass(frozen=True)
class SeasonalCoolingSummary:
    rh_critical_percent: float
    seasonal_wbgt_benefit_c_minutes: float
    elevated_rh_hours: float
    enabled_minutes: float
    meets_elevated_rh_budget: bool


def evaluate_monsoon_policy(
    policy: CoolingSwitchPolicy,
    intervals: Sequence[MonsoonCoolingInputs],
    initially_enabled: bool = False,
) -> SeasonalCoolingSummary:
    """
    Evaluate a policy over a historical or synthetic monsoon interval series.

    The policy maximizing WBGT-benefit minutes among policies satisfying the
    under-30-hour constraint is selected externally by optimize_monsoon_policy.
    """
    enabled = initially_enabled
    elevated_hours = 0.0
    benefit_c_minutes = 0.0
    enabled_minutes = 0.0

    for interval in intervals:
        decision = decide_cooling_switch(
            prior_enabled=enabled,
            policy=policy,
            inputs=interval,
            accumulated_elevated_rh_hours=elevated_hours,
        )
        enabled = decision.enabled
        elevated_hours = decision.accumulated_elevated_rh_hours

        if enabled:
            enabled_minutes += interval.interval_minutes
            benefit_c_minutes += (
                interval.predicted_wbgt_reduction_c * interval.interval_minutes
            )

    return SeasonalCoolingSummary(
        rh_critical_percent=policy.rh_critical_percent,
        seasonal_wbgt_benefit_c_minutes=benefit_c_minutes,
        elevated_rh_hours=elevated_hours,
        enabled_minutes=enabled_minutes,
        meets_elevated_rh_budget=(
            elevated_hours <= policy.elevated_rh_budget_hours
        ),
    )


def optimize_monsoon_policy(
    candidate_policies: Sequence[CoolingSwitchPolicy],
    intervals: Sequence[MonsoonCoolingInputs],
) -> SeasonalCoolingSummary:
    """
    Choose the policy with maximum seasonal modeled cooling benefit subject to
    its declared near-node elevated-humidity-hour budget.
    """
    if not candidate_policies:
        raise ValueError("At least one cooling-switch policy is required.")
    if not intervals:
        raise ValueError("At least one monsoon measurement interval is required.")

    summaries = [
        evaluate_monsoon_policy(policy, intervals)
        for policy in candidate_policies
    ]
    eligible = [summary for summary in summaries if summary.meets_elevated_rh_budget]

    if not eligible:
        raise ValueError(
            "No candidate policy satisfies the elevated-humidity-hour budget."
        )
    return max(eligible, key=lambda summary: summary.seasonal_wbgt_benefit_c_minutes)


@dataclass(frozen=True)
class AerosolSensorObservation:
    """
    A time-bucketed, privacy-preserving environmental observation.

    opc_ratio:
        Ratio of current relevant aerodynamic-size-bin concentration to a
        diurnally matched baseline. For a 2-log event, a sustained ratio near
        100 is expected, subject to sensitivity and particle composition.

    atp_ratio:
        ATP signal relative to a site-specific diurnally matched baseline.

    impinger_viable_log10_ratio:
        Log10 viable-count increase, available after the delayed incubation or
        analysis process. Use None until the sample result arrives.

    qpcr_legionella_log10_ratio:
        Log10 target-specific DNA increase, available after qPCR completion.
        qPCR is target-specific but detects nucleic acid and does not on its
        own establish viability.

    meteorology is represented by the diurnal baseline construction upstream;
    raw time of day and meteorological covariates need not be retained in the
    fusion object after residualization.
    """

    opc_ratio: float
    atp_ratio: float
    impinger_viable_log10_ratio: float | None
    qpcr_legionella_log10_ratio: float | None
    interval_minutes: float

    def __post_init__(self) -> None:
        _nonnegative("opc_ratio", self.opc_ratio)
        _nonnegative("atp_ratio", self.atp_ratio)
        _positive("interval_minutes", self.interval_minutes)
        if self.impinger_viable_log10_ratio is not None:
            _nonnegative(
                "impinger_viable_log10_ratio",
                self.impinger_viable_log10_ratio,
            )
        if self.qpcr_legionella_log10_ratio is not None:
            _nonnegative(
                "qpcr_legionella_log10_ratio",
                self.qpcr_legionella_log10_ratio,
            )


@dataclass(frozen=True)
class AerosolFusionPolicy:
    """
    Prior and likelihood-ratio parameters must be estimated from blinded,
    labeled environmental calibration data.

    Real-time OPC and ATP signals provide early evidence. Impinger viable
    counts and qPCR provide delayed confirmatory evidence. The architecture
    explicitly avoids treating either non-specific proxy as pathogen proof.
    """

    prior_pathogenic_event_probability: float
    opc_likelihood_ratio_at_2log: float
    atp_likelihood_ratio_at_2log: float
    impinger_likelihood_ratio_at_2log: float
    qpcr_likelihood_ratio_at_2log: float
    screening_probability_threshold: float = 0.80
    confirmed_probability_threshold: float = 0.95
    viable_log10_confirmation_threshold: float = 2.0
    qpcr_log10_confirmation_threshold: float = 2.0

    def __post_init__(self) -> None:
        _unit_interval(
            "prior_pathogenic_event_probability",
            self.prior_pathogenic_event_probability,
        )
        if self.prior_pathogenic_event_probability in (0.0, 1.0):
            raise ValueError(
                "prior_pathogenic_event_probability must be strictly within (0, 1)."
            )
        for name, value in (
            ("opc_likelihood_ratio_at_2log", self.opc_likelihood_ratio_at_2log),
            ("atp_likelihood_ratio_at_2log", self.atp_likelihood_ratio_at_2log),
            (
                "impinger_likelihood_ratio_at_2log",
                self.impinger_likelihood_ratio_at_2log,
            ),
            ("qpcr_likelihood_ratio_at_2log", self.qpcr_likelihood_ratio_at_2log),
        ):
            _positive(name, value)
        _unit_interval("screening_probability_threshold", self.screening_probability_threshold)
        _unit_interval("confirmed_probability_threshold", self.confirmed_probability_threshold)
        _nonnegative(
            "viable_log10_confirmation_threshold",
            self.viable_log10_confirmation_threshold,
        )
        _nonnegative(
            "qpcr_log10_confirmation_threshold",
            self.qpcr_log10_confirmation_threshold,
        )


@dataclass(frozen=True)
class AerosolFusionResult:
    posterior_pathogenic_event_probability: float
    alert_level: str
    real_time_screening_triggered: bool
    viable_confirmation_available: bool
    target_specific_confirmation_available: bool
    estimated_detection_delay_minutes: float
    explanation: str


def _posterior_from_likelihood_ratio(
    prior_probability: float,
    total_likelihood_ratio: float,
) -> float:
    prior_odds = prior_probability / (1.0 - prior_probability)
    posterior_odds = prior_odds * total_likelihood_ratio
    return posterior_odds / (1.0 + posterior_odds)


def fuse_aerosol_observation(
    observation: AerosolSensorObservation,
    policy: AerosolFusionPolicy,
    impinger_delay_hours: float = 24.0,
    qpcr_delay_hours: float = 6.0,
) -> AerosolFusionResult:
    """
    Hierarchical Bayesian evidence fusion with delayed observation channels.

    Architecture:
      latent state: viable pathogenic aerosol concentration relative to a
                    diurnally conditioned baseline;
      fast observations: OPC and ATP;
      delayed observations: impinger viable count and Legionella qPCR;
      decision layer: screening, confirmation, and human-reviewed response.

    A Kalman filter is suitable only after log-transformed continuous signals
    can be approximated as Gaussian and linear. Aerosol concentrations,
    threshold events, delayed assays, and irregular sampling are better
    represented by a state-space particle filter whose observation model is
    Bayesian and assay-specific. This function is the per-time-step posterior
    update used by that architecture.
    """
    _nonnegative("impinger_delay_hours", impinger_delay_hours)
    _nonnegative("qpcr_delay_hours", qpcr_delay_hours)

    likelihood_ratio = 1.0
    real_time_evidence = 1.0
    if observation.opc_ratio >= 100.0:
        likelihood_ratio *= policy.opc_likelihood_ratio_at_2log
        real_time_evidence *= policy.opc_likelihood_ratio_at_2log
    if observation.atp_ratio >= 100.0:
        likelihood_ratio *= policy.atp_likelihood_ratio_at_2log
        real_time_evidence *= policy.atp_likelihood_ratio_at_2log

    viable_confirmed = (
        observation.impinger_viable_log10_ratio is not None
        and observation.impinger_viable_log10_ratio
        >= policy.viable_log10_confirmation_threshold
    )
    if viable_confirmed:
        likelihood_ratio *= policy.impinger_likelihood_ratio_at_2log

    target_confirmed = (
        observation.qpcr_legionella_log10_ratio is not None
        and observation.qpcr_legionella_log10_ratio
        >= policy.qpcr_log10_confirmation_threshold
    )
    if target_confirmed:
        likelihood_ratio *= policy.qpcr_likelihood_ratio_at_2log

    posterior = _posterior_from_likelihood_ratio(
        policy.prior_pathogenic_event_probability,
        likelihood_ratio,
    )
    real_time_posterior = _posterior_from_likelihood_ratio(
        policy.prior_pathogenic_event_probability,
        real_time_evidence,
    )

    screening_triggered = real_time_posterior >= policy.screening_probability_threshold
    confirmation = viable_confirmed and target_confirmed
    confirmed = (
        confirmation
        and posterior >= policy.confirmed_probability_threshold
    )

    if confirmed:
        alert_level = "confirmed_pathogenic_aerosol_event_requires_human_review"
        delay_minutes = max(impinger_delay_hours, qpcr_delay_hours) * 60.0
        explanation = (
            "The posterior exceeds the confirmation threshold and both viable "
            "impinger evidence and target-specific qPCR evidence meet their "
            "predeclared 2-log confirmation thresholds."
        )
    elif screening_triggered:
        alert_level = "rapid_screening_signal_requires_precautionary_review"
        delay_minutes = observation.interval_minutes
        explanation = (
            "Real-time OPC and/or ATP evidence crossed the screening threshold. "
            "This is an early environmental signal, not proof of viable "
            "pathogenic aerosol; delayed viability and target-specific assays "
            "remain required."
        )
    else:
        alert_level = "no_threshold_crossing_in_current_interval"
        delay_minutes = observation.interval_minutes
        explanation = (
            "Current fused evidence is below the rapid screening threshold "
            "after comparison with a diurnally matched baseline."
        )

    return AerosolFusionResult(
        posterior_pathogenic_event_probability=posterior,
        alert_level=alert_level,
        real_time_screening_triggered=screening_triggered,
        viable_confirmation_available=viable_confirmed,
        target_specific_confirmation_available=target_confirmed,
        estimated_detection_delay_minutes=delay_minutes,
        explanation=explanation,
    )

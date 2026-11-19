from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class WaterSecurityInputs:
    ph: float
    turbidity_ntu: float
    microbial_risk: float
    contaminant_risk_ratio: float
    supply_reliability: float
    accessibility: float
    self_governance_capacity: float
    data_quality_confidence: float


@dataclass(frozen=True)
class WaterSecurityResult:
    score: float
    quality_score: float
    service_score: float
    governance_score: float
    safety_cap: float
    interpretation: str
    explanations: tuple[str, ...]


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    if not isfinite(value):
        raise ValueError("all inputs must be finite")
    return max(lower, min(upper, value))


def left_shoulder(value: float, full_until: float, zero_from: float) -> float:
    if zero_from <= full_until:
        raise ValueError("zero_from must be greater than full_until")
    if value <= full_until:
        return 1.0
    if value >= zero_from:
        return 0.0
    return (zero_from - value) / (zero_from - full_until)


def right_shoulder(value: float, zero_until: float, full_from: float) -> float:
    if full_from <= zero_until:
        raise ValueError("full_from must be greater than zero_until")
    if value <= zero_until:
        return 0.0
    if value >= full_from:
        return 1.0
    return (value - zero_until) / (full_from - zero_until)


def trapezoid(value: float, a: float, b: float, c: float, d: float) -> float:
    if not a <= b <= c <= d or a == d:
        raise ValueError("membership breakpoints must satisfy a <= b <= c <= d")
    if value <= a or value >= d:
        return 0.0
    if b <= value <= c:
        return 1.0
    if value < b:
        return (value - a) / (b - a)
    return (d - value) / (d - c)


def classify(score: float) -> str:
    if score <= 20.0:
        return "Critical"
    if score <= 40.0:
        return "Fragile"
    if score <= 60.0:
        return "Stressed"
    if score <= 80.0:
        return "Secure"
    return "Resilient"


def calculate_water_security_index(inputs: WaterSecurityInputs) -> WaterSecurityResult:
    microbial_risk = clamp(inputs.microbial_risk)
    contaminant_ratio = max(0.0, inputs.contaminant_risk_ratio)
    reliability = clamp(inputs.supply_reliability)
    accessibility = clamp(inputs.accessibility)
    governance = clamp(inputs.self_governance_capacity)
    confidence = clamp(inputs.data_quality_confidence)

    ph_adequate = trapezoid(inputs.ph, 6.8, 7.1, 8.4, 8.7)
    turbidity_low = left_shoulder(inputs.turbidity_ntu, 0.3, 1.0)
    turbidity_high = right_shoulder(inputs.turbidity_ntu, 1.0, 5.0)
    microbial_safe = left_shoulder(microbial_risk, 0.05, 0.20)
    microbial_unsafe = right_shoulder(microbial_risk, 0.20, 0.60)
    chemical_safe = left_shoulder(contaminant_ratio, 0.50, 0.80)
    chemical_unsafe = right_shoulder(contaminant_ratio, 0.80, 1.00)
    reliable = right_shoulder(reliability, 0.80, 0.97)
    accessible = right_shoulder(accessibility, 0.65, 0.85)
    strong_governance = right_shoulder(governance, 0.60, 0.82)

    quality_score = min(ph_adequate, turbidity_low, microbial_safe, chemical_safe)
    service_score = min(reliable, accessible)
    governance_score = strong_governance

    base_score = 100.0 * (
        0.50 * quality_score
        + 0.30 * service_score
        + 0.20 * governance_score
    )

    safety_cap = 100.0
    explanations: list[str] = []

    if microbial_unsafe >= 0.50:
        safety_cap = 20.0
        explanations.append("Microbial-risk safety gate is active.")
    if chemical_unsafe >= 0.50:
        safety_cap = min(safety_cap, 20.0)
        explanations.append("Chemical-contaminant safety gate is active.")
    if turbidity_high >= 0.75 and microbial_safe < 0.50:
        safety_cap = min(safety_cap, 40.0)
        explanations.append("Turbidity and microbial uncertainty safety gate is active.")
    if confidence < 0.60:
        explanations.append("Data confidence is low; prioritize monitoring and community review.")
    if reliability < 0.80:
        explanations.append("Supply reliability requires resilience and repair planning.")
    if accessibility < 0.65:
        explanations.append("Water access requires affordability, accessibility, or distribution improvements.")
    if governance < 0.60:
        explanations.append("Community self-governance capacity requires support and accessible participation pathways.")

    score = confidence * min(base_score, safety_cap)
    return WaterSecurityResult(
        score=round(max(0.0, min(100.0, score)), 2),
        quality_score=round(quality_score, 4),
        service_score=round(service_score, 4),
        governance_score=round(governance_score, 4),
        safety_cap=safety_cap,
        interpretation=classify(score),
        explanations=tuple(explanations),
    )

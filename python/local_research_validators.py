"""Local, in-memory validation of supplied project records; Python 3.10+.

No filesystem, network, subprocess, device, or repository writes are performed.
Input labels such as term_id are private correlation keys, never credentials.
"""
from __future__ import annotations
from dataclasses import dataclass
from collections.abc import Mapping, Sequence
from decimal import Decimal, InvalidOperation
import hashlib
import re
from typing import Any

RISK_CLASSES = (
    "key_ordering_rule", "ascii_structural_key_profile", "nfc_handling",
    "surrogate_handling", "control_character_policy", "maximum_depth",
    "integer_range", "fixed_point_decimal_representation", "float_rejection_rule",
    "exclusion_path_semantics", "nested_commitment_behavior", "utf8_encoding_behavior",
    "sha256_input_construction",
)
# The supplied list contains thirteen named classes, not fourteen. The caller
# must declare an additional reviewed class rather than silently inventing one.
FORBIDDEN = frozenset({
    "coverage_percentage", "pass_rate", "confidence_score", "quality_score",
    "priority", "ranking", "rank", "score", "drift_count", "priority_rank",
    "urgency", "queue_position", "completion_percent",
})
TRIGGER_FORBIDDEN = FORBIDDEN | frozenset({
    "review_artifact", "review_artifact_instance", "assigned_reviewer", "owner",
    "assignee", "due_date", "review_deadline", "review_required_by",
    "notification_target", "automatic_task", "automatic_notification", "automatic_workflow",
})
AUTH = ("external_action_authorized", "automatic_retrieval_authorized", "automatic_review_authorized")
DIGEST = re.compile(r"sha256:[0-9a-f]{64}\Z")
NUMBER = re.compile(r"-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\Z")
PROJECTIONS = ("mapping", "policy", "documentation", "locale", "constraints", "vector")

@dataclass(frozen=True)
class DriftFinding:
    drift_class: str
    code: str
    term_id: str
    artifact_path: str | None
    selector: str | None
    status: str
    plain_language_summary: str

@dataclass(frozen=True)
class TermParityResult:
    term_id: str
    status: str
    findings: tuple[DriftFinding, ...]
    plain_language_summary: str
    external_action_authorized: bool = False
    universal_claimed: bool = False

@dataclass(frozen=True)
class ValidationResult:
    status: str
    findings: tuple[str, ...]
    plain_language_summary: str
    external_action_authorized: bool = False
    automatic_retrieval_authorized: bool = False
    automatic_review_authorized: bool = False
    universal_claimed: bool = False

@dataclass(frozen=True)
class CanonicalizationCorpusResult:
    status: str
    profile_id: str
    profile_version: str
    covered_risk_classes: tuple[str, ...]
    missing_risk_classes: tuple[str, ...]
    runtime_disagreement_vector_ids: tuple[str, ...]
    findings: tuple[str, ...]
    plain_language_summary: str
    external_action_authorized: bool = False
    universal_claimed: bool = False


def _strings(value: Any) -> bool:
    return isinstance(value, (list, tuple)) and all(isinstance(x, str) and x for x in value)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _forbidden(value: Any, keys=FORBIDDEN) -> bool:
    if isinstance(value, Mapping):
        return any(k in keys or _forbidden(v, keys) for k, v in value.items())
    if isinstance(value, (list, tuple)):
        return any(_forbidden(v, keys) for v in value)
    return False


def _result(errors: list[str], unavailable: list[str] | None = None,
            review: list[str] | None = None) -> ValidationResult:
    missing = unavailable or []
    pending = review or []
    status = "fail" if errors else "not_established" if missing else "needs_local_review" if pending else "pass"
    return ValidationResult(status, tuple(errors + missing + pending),
        {"pass": "Declared local checks passed; no external action is authorized.",
         "fail": "One or more supplied records violate the declared local contract.",
         "not_established": "Required local evidence or contract information is unavailable.",
         "needs_local_review": "Declared local checks require review; no action is authorized."}[status])


def sha256_bytes(data: bytes) -> str:
    if not isinstance(data, bytes):
        raise TypeError("Only explicitly supplied bytes may be committed.")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def validate_manifest(record: Mapping[str, Any], supplied_bytes: bytes | None = None) -> ValidationResult:
    errors: list[str] = []
    missing: list[str] = []
    if _forbidden(record): errors.append("prohibited_scoring_field")
    state = record.get("local_availability_state")
    if state == "available_locally":
        if not DIGEST.fullmatch(str(record.get("sha256", ""))): errors.append("invalid_or_missing_sha256")
        size = record.get("byte_size")
        if type(size) is not int or size < 0: errors.append("invalid_or_missing_byte_size")
        if not _text(record.get("local_path_reference")): errors.append("missing_local_path_reference")
        if supplied_bytes is None: missing.append("local_bytes_not_supplied_for_verification")
        elif not isinstance(supplied_bytes, bytes): errors.append("invalid_supplied_bytes")
        else:
            if record.get("sha256") != sha256_bytes(supplied_bytes): errors.append("byte_commitment_mismatch")
            if size != len(supplied_bytes): errors.append("byte_size_mismatch")
    elif state == "not_available_locally":
        if supplied_bytes is not None: errors.append("availability_bytes_contradiction")
        if not _text(record.get("source_reference")): errors.append("missing_source_reference")
        if record.get("source_reference_state") not in {
            "declared_external_reference_not_fetched", "source_not_established"
        }: errors.append("invalid_source_reference_state")
        if "sha256" in record or "byte_size" in record:
            errors.append("remote_digest_or_size_requires_separate_reference_contract")
        missing.append("source_bytes_not_established_locally")
    else: errors.append("invalid_local_availability_state")
    return _result(errors, missing)


def validate_vector_corpus(profile: Mapping[str, Any], vectors: Sequence[Mapping[str, Any]],
                           runtime_results: Sequence[Mapping[str, Any]]) -> CanonicalizationCorpusResult:
    errors: list[str] = []
    missing: list[str] = []
    disagreements: set[str] = set()
    covered: list[str] = []
    if _forbidden((profile, vectors, runtime_results)): errors.append("prohibited_scoring_field")
    pid, version = profile.get("profile_id"), profile.get("profile_version")
    if not _text(pid) or not _text(version): errors.append("profile_binding_missing")
    mandatory = profile.get("mandatory_risk_classes")
    if not _strings(mandatory) or len(set(mandatory)) != len(mandatory):
        errors.append("invalid_mandatory_risk_classes"); mandatory = []
    if len(mandatory) != 14 or not set(RISK_CLASSES).issubset(mandatory):
        missing.append("fourteen_class_contract_not_established")
    required = profile.get("required_vector_ids")
    if not _strings(required) or not required or len(set(required)) != len(required):
        errors.append("invalid_required_vector_ids"); required = []
    outcomes = profile.get("required_outcomes_by_risk_class", {})
    if not isinstance(outcomes, Mapping): errors.append("invalid_outcome_contract"); outcomes = {}
    table: dict[str, Mapping[str, Any]] = {}
    for vector in vectors:
        vid = vector.get("vector_id")
        if not _text(vid): errors.append("vector_binding_missing"); continue
        if vid in table: errors.append("duplicate_vector_id"); continue
        table[vid] = vector
        if vector.get("profile_id") != pid or vector.get("profile_version") != version:
            errors.append("vector_profile_binding_mismatch")
        if not _strings(vector.get("risk_classes")) or not set(vector["risk_classes"]).issubset(mandatory):
            errors.append("invalid_vector_risk_classes")
        if vector.get("expected_outcome") not in {"pass", "reject"}: errors.append("invalid_vector_outcome")
    records: dict[tuple[str, str], Mapping[str, Any]] = {}
    for record in runtime_results:
        vid, runtime = record.get("vector_id"), record.get("runtime")
        if not _text(vid) or runtime not in {"Python", "PowerShell"}:
            errors.append("invalid_runtime_binding"); continue
        key = (vid, runtime)
        if key in records: errors.append("duplicate_runtime_record"); continue
        records[key] = record
        if vid not in table: errors.append("unknown_runtime_vector")
        if record.get("profile_id") != pid or record.get("profile_version") != version:
            errors.append("runtime_profile_binding_mismatch")
        if not _text(record.get("runtime_version")): errors.append("runtime_version_missing")
        outcome = record.get("outcome")
        if outcome not in {"pass", "reject"}: errors.append("invalid_runtime_outcome")
        if outcome == "pass" and not DIGEST.fullmatch(str(record.get("output_sha256", ""))):
            errors.append("passing_output_commitment_missing")
        if outcome == "reject" and not _text(record.get("rejection_code")):
            errors.append("rejection_code_missing")
    established: set[str] = set()
    for vid in required:
        if vid not in table: missing.append("required_vector_missing:" + vid); continue
        a, b = records.get((vid, "Python")), records.get((vid, "PowerShell"))
        if a is None or b is None: missing.append("runtime_record_missing:" + vid); continue
        signature = lambda x: (x.get("outcome"), x.get("output_sha256") if x.get("outcome") == "pass" else x.get("rejection_code"))
        if signature(a) != signature(b): disagreements.add(vid); continue
        if a.get("outcome") != table[vid].get("expected_outcome"):
            errors.append("configured_outcome_mismatch:" + vid); continue
        established.add(vid)
    absent: list[str] = []
    for risk in mandatory:
        wanted = outcomes.get(risk)
        if not _strings(wanted) or not wanted or not set(wanted).issubset({"pass", "reject"}):
            missing.append("risk_outcome_contract_missing:" + risk); absent.append(risk); continue
        observed = {table[v]["expected_outcome"] for v in established
                    if risk in table[v].get("risk_classes", [])}
        if set(wanted).issubset(observed): covered.append(risk)
        else: absent.append(risk)
    if absent: missing.append("mandatory_outcome_coverage_not_established")
    status = "fail" if errors else "needs_local_review" if disagreements else "not_established" if missing else "pass"
    summaries = {
        "pass": "The declared local canonicalization profile was tested against the required representative vector classes in this versioned corpus. Python and PowerShell produced the configured matching or rejecting outcomes for those vectors. This result is limited to the declared profile, runtimes, and vector corpus. It does not claim corpus completeness, RFC 8785 conformance, IEEE 754 conformance, Unicode conformance certification, or cross-runtime parity beyond the declared vectors.",
        "not_established": "The declared local canonicalization corpus is incomplete because mandatory profile coverage or required runtime evidence has not been established. This does not imply that the implementation is incorrect.",
        "needs_local_review": "The declared local canonicalization corpus needs local review because Python and PowerShell produced different results for required vectors. No commitment profile change, repository modification, external notification, or external action is authorized.",
        "fail": "Supplied corpus records violate the declared local contract; no implementation certification or external action is authorized.",
    }
    return CanonicalizationCorpusResult(status, pid if isinstance(pid,str) else "", version if isinstance(version,str) else "",
        tuple(covered), tuple(absent), tuple(sorted(disagreements)), tuple(errors + missing), summaries[status])


def _finding(term: str, group: str, code: str, status="fail") -> DriftFinding:
    return DriftFinding(group, code, term, None, None, status, code.replace("_", " "))


def validate_term_mapping(term: Mapping[str, Any], mapping: Mapping[str, Any]) -> tuple[DriftFinding, ...]:
    tid = term.get("term_id", "")
    return () if mapping.get("term_id") == tid and mapping.get("canonical_term") == term.get("canonical_term") else (
        _finding(tid, "mapping", "term_mapping_mismatch"),)


def validate_locale_lifecycle(term: Mapping[str, Any], locale: Mapping[str, Any]) -> tuple[DriftFinding, ...]:
    tid = term.get("term_id", "")
    findings = []
    keys = locale.get("resolvable_keys", [])
    if not _strings(keys): findings.append(_finding(tid,"locale","invalid_locale_keys"))
    if not _text(term.get("locale_key")) or term.get("locale_key") not in keys:
        findings.append(_finding(tid,"locale","term_locale_key_missing"))
    if term.get("lifecycle") == "deprecated" and term.get("replacement_term_id"):
        key = locale.get("replacement_locale_key")
        if locale.get("replacement_term_id") != term["replacement_term_id"] or not _text(key) or key not in keys:
            findings.append(_finding(tid,"locale","replacement_locale_key_missing"))
    return tuple(findings)


def validate_documentation_constraint_parity(term: Mapping[str, Any], document: Mapping[str, Any]) -> tuple[DriftFinding, ...]:
    tid = term.get("term_id", "")
    findings = []
    front = document.get("frontmatter", {})
    if not isinstance(front, Mapping): return (_finding(tid,"documentation","invalid_frontmatter"),)
    if front.get("term_id") != tid: findings.append(_finding(tid,"documentation","documentation_identity_mismatch"))
    headings = document.get("headings", [])
    required = term.get("required_headings", [])
    if not _strings(headings) or not _strings(required) or not set(required).issubset(headings):
        findings.append(_finding(tid,"documentation","required_heading_missing"))
    for field in ("constraints", "non_claims"):
        expected, actual = term.get(field), front.get(field)
        if not _strings(expected) or not _strings(actual) or len(set(expected)) != len(expected) or len(set(actual)) != len(actual) or set(expected) != set(actual):
            findings.append(_finding(tid,"documentation",field + "_frontmatter_mismatch"))
    bullets = document.get("non_claims_bullets")
    if not _strings(bullets) or len(set(bullets)) != len(bullets) or not _strings(front.get("non_claims")) or set(bullets) != set(front["non_claims"]):
        findings.append(_finding(tid,"documentation","non_claims_body_mismatch"))
    return tuple(findings)


def validate_fragment_reference(reference: Mapping[str, Any], fragments: Mapping[str, Any]) -> ValidationResult:
    key = reference.get("fragment_reference")
    if not _text(key): return _result(["fragment_reference_missing"])
    if key not in fragments: return _result([], ["fragment_not_available_locally"])
    return validate_manifest(reference, fragments[key])


def validate_term_drift(term: Mapping[str, Any], projections: Mapping[str, Any]) -> TermParityResult:
    tid = term.get("term_id", "")
    findings: list[DriftFinding] = []
    if not _text(tid) or not _text(term.get("canonical_term")) or term.get("lifecycle") not in {"active", "deprecated"}:
        findings.append(_finding(tid,"registry","invalid_term_contract"))
    if _forbidden((term, projections)): findings.append(_finding(tid,"contract","prohibited_scoring_field"))
    for name in PROJECTIONS:
        if name == "vector" and not term.get("required_vector_names"): continue
        if name not in projections or projections[name] is None:
            findings.append(_finding(tid,name,"required_projection_not_available","not_established"))
        elif not isinstance(projections[name], Mapping):
            findings.append(_finding(tid,name,"invalid_projection"))
    available = lambda name: isinstance(projections.get(name), Mapping)
    if available("mapping"): findings.extend(validate_term_mapping(term, projections["mapping"]))
    if available("locale"): findings.extend(validate_locale_lifecycle(term, projections["locale"]))
    if available("documentation"): findings.extend(validate_documentation_constraint_parity(term, projections["documentation"]))
    if available("policy"):
        if tid not in projections["policy"].get("term_ids", []): findings.append(_finding(tid,"policy","policy_projection_missing_term"))
    if available("constraints"):
        values = projections["constraints"].get("constraints")
        if not _strings(values) or not _strings(term.get("constraints")) or set(values) != set(term["constraints"]):
            findings.append(_finding(tid,"constraints","structured_constraints_mismatch"))
    required = term.get("required_vector_names", [])
    if not _strings(required): findings.append(_finding(tid,"vector","invalid_required_vector_contract"))
    elif required and available("vector"):
        names = projections["vector"].get("vector_names", [])
        if not _strings(names) or not set(required).issubset(names): findings.append(_finding(tid,"vector","required_vector_missing"))
    trigger = term.get("material_change_trigger", False)
    if type(trigger) is not bool: findings.append(_finding(tid,"change","invalid_trigger_state"))
    elif trigger: findings.append(_finding(tid,"change","material_change_review_pending","needs_local_review"))
    states = {x.status for x in findings}
    status = "fail" if "fail" in states else "not_established" if "not_established" in states else "needs_local_review" if states else "pass"
    return TermParityResult(tid, status, tuple(findings), "Local term parity: " + status + "; no external action is authorized.")


def validate_trigger_reference(trigger: Mapping[str, Any], envelope_bytes: bytes | None = None) -> ValidationResult:
    errors: list[str] = []
    missing: list[str] = []
    allowed = {"review_artifact_type_ref_commitment_sha256", "review_artifact_instance_binding_state", "change_context_envelope_ref", *AUTH}
    if set(trigger) - allowed or _forbidden(trigger, TRIGGER_FORBIDDEN): errors.append("prohibited_trigger_field")
    if any(trigger.get(k) is not False for k in AUTH): errors.append("authorization_must_be_explicit_false")
    if not DIGEST.fullmatch(str(trigger.get("review_artifact_type_ref_commitment_sha256", ""))): errors.append("invalid_type_reference_commitment")
    if trigger.get("review_artifact_instance_binding_state") != "not_yet_bound": errors.append("invalid_instance_binding_state")
    envelope = trigger.get("change_context_envelope_ref")
    if envelope is not None:
        if not isinstance(envelope, Mapping): errors.append("invalid_envelope_reference")
        else:
            if set(envelope) != {"envelope_id", "envelope_commitment_sha256", "reference_state"}: errors.append("invalid_envelope_fields")
            if not _text(envelope.get("envelope_id")) or envelope.get("reference_state") != "envelope_reference_recorded": errors.append("invalid_envelope_binding")
            digest = envelope.get("envelope_commitment_sha256")
            if not DIGEST.fullmatch(str(digest)): errors.append("invalid_envelope_commitment")
            if envelope_bytes is None: missing.append("envelope_reference_not_established")
            elif not isinstance(envelope_bytes, bytes) or sha256_bytes(envelope_bytes) != digest: errors.append("envelope_commitment_mismatch")
    elif envelope_bytes is not None: errors.append("bytes_without_envelope_reference")
    return _result(errors, missing)


def validate_envelope_successor(prior: Mapping[str, Any], successor: Mapping[str, Any],
                                prior_bytes: bytes, successor_bytes: bytes) -> ValidationResult:
    errors: list[str] = []
    states = {"active_local_correlation_context", "deprecated_local_correlation_context", "quarantined_not_authoritative"}
    for record, data in ((prior, prior_bytes), (successor, successor_bytes)):
        if not _text(record.get("envelope_id")) or record.get("lifecycle") not in states: errors.append("invalid_envelope_metadata")
        if record.get("sha256") != sha256_bytes(data): errors.append("envelope_bytes_mismatch")
    if prior_bytes != successor_bytes and prior.get("envelope_id") == successor.get("envelope_id"):
        errors.append("changed_bytes_require_new_envelope")
    # Metadata is supplied as a separate lifecycle observation, not rewritten bytes.
    transitions = {"active_local_correlation_context": states,
                   "deprecated_local_correlation_context": {"deprecated_local_correlation_context", "quarantined_not_authoritative"},
                   "quarantined_not_authoritative": {"quarantined_not_authoritative"}}
    if prior.get("envelope_id") == successor.get("envelope_id") and successor.get("lifecycle") not in transitions.get(prior.get("lifecycle"), set()):
        errors.append("invalid_append_only_lifecycle_transition")
    return _result(errors)


def validate_metric_value(family: Mapping[str, Any], metric: Mapping[str, Any],
                          value: Mapping[str, Any]) -> ValidationResult:
    errors: list[str] = []
    dimension, unit = family.get("dimension"), metric.get("canonical_storage_unit_id")
    units = family.get("permitted_units")
    if not _text(dimension) or not _text(unit) or not isinstance(units, Mapping) or not units:
        return _result(["invalid_metric_family_contract"])
    if any(d != dimension for d in units.values()) or unit not in units: errors.append("unit_dimension_mismatch")
    if metric.get("dimension") != dimension: errors.append("metric_dimension_mismatch")
    if value.get("canonical_storage_unit_id") != unit: errors.append("noncanonical_value_unit")
    numeric = value.get("canonical_numeric_value")
    if not isinstance(numeric, str) or not NUMBER.fullmatch(numeric): errors.append("invalid_canonical_numeric_string")
    else:
        try:
            if not Decimal(numeric).is_finite(): errors.append("nonfinite_numeric_value")
        except InvalidOperation: errors.append("invalid_numeric_value")
    if any(k in value for k in ("localized_numeric_value", "conversion_authorized")): errors.append("storage_conversion_boundary_violation")
    return _result(errors)


def validate_counterfactual(record: Mapping[str, Any]) -> ValidationResult:
    errors: list[str] = []
    for key in ("baseline_reference", "altered_condition_category", "altered_condition_dimension",
                "bounded_comparison_boundary", "assumption_evidence_state"):
        if not _text(record.get(key)): errors.append("missing_" + key)
    if not _strings(record.get("affected_variable_references")) or not record.get("affected_variable_references"):
        errors.append("affected_variable_references_missing")
    required = {"fact_status": "assumption_not_fact", "causal_validity_state": "not_established",
                "selection_prohibited": True, "external_action_authorized": False}
    for key, expected in required.items():
        actual = record.get(key)
        if actual != expected or type(actual) is not type(expected): errors.append("invalid_" + key)
    if _forbidden(record): errors.append("prohibited_scoring_field")
    return _result(errors)

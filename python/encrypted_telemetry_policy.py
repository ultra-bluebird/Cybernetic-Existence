from __future__ import annotations

from dataclasses import dataclass
from enum import Enum

class Operation(str, Enum):
    COUNT = "count"
    SUM = "sum"
    MEAN = "mean"
    HISTOGRAM = "histogram"
    LINEAR_SCORE = "linear_score"
    THRESHOLD = "threshold"
    FEATURE_EXTRACTION = "feature_extraction"
    NONLINEAR_INFERENCE = "nonlinear_inference"
    INDIVIDUAL_DECISION = "individual_decision"

class Method(str, Enum):
    DO_NOT_COLLECT = "do_not_collect"
    LOCAL_ONLY = "local_only"
    ADDITIVE_PHE = "additive_phe"
    FHE_REVIEW_REQUIRED = "fhe_review_required"
    PROHIBITED = "prohibited"

@dataclass(frozen=True)
class TelemetryRequest:
    necessary_for_documented_purpose: bool
    explicit_revocable_consent: bool
    minimized_schema: bool
    retention_days: int
    requested_operation: Operation
    minimum_group_size: int
    raw_data_export_requested: bool
    individual_decision_requested: bool

def choose_method(request: TelemetryRequest) -> Method:
    collection_allowed = (
        request.necessary_for_documented_purpose
        and request.explicit_revocable_consent
        and request.minimized_schema
        and 1 <= request.retention_days <= 365
    )

    if not collection_allowed:
        return Method.DO_NOT_COLLECT

    if request.individual_decision_requested:
        return Method.PROHIBITED

    if request.raw_data_export_requested:
        return Method.PROHIBITED

    if request.requested_operation in {
        Operation.COUNT,
        Operation.SUM,
        Operation.MEAN,
        Operation.HISTOGRAM,
    }:
        if request.minimum_group_size < 10:
            return Method.LOCAL_ONLY
        return Method.ADDITIVE_PHE

    if request.requested_operation == Operation.LINEAR_SCORE:
        if request.minimum_group_size < 10:
            return Method.LOCAL_ONLY
        return Method.ADDITIVE_PHE

    if request.requested_operation in {
        Operation.THRESHOLD,
        Operation.NONLINEAR_INFERENCE,
    }:
        return Method.FHE_REVIEW_REQUIRED

    if request.requested_operation == Operation.FEATURE_EXTRACTION:
        return Method.LOCAL_ONLY

    return Method.PROHIBITED

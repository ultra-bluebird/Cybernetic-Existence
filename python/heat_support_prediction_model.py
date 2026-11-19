from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Final

import numpy as np
import pandas as pd
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    roc_auc_score,
)
from sklearn.model_selection import TimeSeriesSplit
from xgboost import XGBClassifier


class HeatModelStatus(str, Enum):
    HEAT_SUPPORT_MONITORING = "HEAT_SUPPORT_MONITORING"
    HEAT_SUPPORT_REVIEW_REQUIRED = "HEAT_SUPPORT_REVIEW_REQUIRED"
    HEAT_SUPPORT_ESCALATION_REVIEW_REQUIRED = "HEAT_SUPPORT_ESCALATION_REVIEW_REQUIRED"
    INSUFFICIENT_PUBLIC_HEALTH_CONTEXT = "INSUFFICIENT_PUBLIC_HEALTH_CONTEXT"
    MODEL_CALIBRATION_REVIEW_REQUIRED = "MODEL_CALIBRATION_REVIEW_REQUIRED"


FEATURE_COLUMNS: Final[tuple[str, ...]] = (
    "maximum_air_temperature_c",
    "minimum_air_temperature_c",
    "maximum_heat_index_c",
    "land_surface_temperature_c",
    "relative_humidity_fraction",
    "normalized_uv_index",
    "normalized_air_quality_context",
    "tree_canopy_fraction",
    "impervious_surface_fraction",
    "cooling_access_fraction",
    "forecast_freshness_fraction",
    "seasonal_context_fraction",
)

REQUIRED_COLUMNS: Final[set[str]] = {
    "planning_area_id",
    "observed_at_utc",
    "heat_support_escalation_label",
    "minimum_group_size_passed",
    "provenance_available",
    "privacy_review_passed",
    "uncertainty_flag",
    *FEATURE_COLUMNS,
}


@dataclass(frozen=True)
class HeatModelConfig:
    minimum_training_rows: int
    maximum_allowed_brier_score: float
    minimum_required_auroc: float
    minimum_required_average_precision: float
    escalation_probability_threshold: float
    advisory_only: bool = True
    human_review_required: bool = True
    fairness_review_required: bool = True


@dataclass(frozen=True)
class HeatModelEvaluation:
    status: HeatModelStatus
    auroc: float | None
    average_precision: float | None
    brier_score: float | None
    explanation: str


@dataclass(frozen=True)
class HeatSupportPrediction:
    planning_area_id: str
    observed_at_utc: str
    probability: float | None
    status: HeatModelStatus
    explanation: str


class HeatSupportModel:
    def __init__(self, config: HeatModelConfig) -> None:
        self.config = config
        self._model: CalibratedClassifierCV | None = None

    @staticmethod
    def validate_frame(frame: pd.DataFrame) -> None:
        missing = REQUIRED_COLUMNS - set(frame.columns)
        if missing:
            raise ValueError(f"Missing required columns: {sorted(missing)}")

        if frame.empty:
            raise ValueError("Training data must not be empty.")

        timestamps = pd.to_datetime(frame["observed_at_utc"], utc=True, errors="coerce")
        if timestamps.isna().any():
            raise ValueError("observed_at_utc must contain valid UTC timestamps.")

        for column in FEATURE_COLUMNS:
            if frame[column].isna().any():
                raise ValueError(f"{column} contains missing values.")
            if ((frame[column] < 0.0) | (frame[column] > 1.0)).any():
                raise ValueError(
                    f"{column} must be normalized to the closed interval [0, 1]."
                )

        labels = frame["heat_support_escalation_label"]
        if not labels.isin([0, 1]).all():
            raise ValueError("heat_support_escalation_label must contain only 0 or 1.")

    def fit(self, frame: pd.DataFrame) -> HeatModelEvaluation:
        self.validate_frame(frame)

        if not self.config.advisory_only or not self.config.human_review_required:
            return HeatModelEvaluation(
                status=HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "The model must remain advisory-only and subject to human review."
                ),
            )

        if not self.config.fairness_review_required:
            return HeatModelEvaluation(
                status=HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "A documented fairness and non-discrimination review is required "
                    "before model training or release."
                ),
            )

        if len(frame) < self.config.minimum_training_rows:
            return HeatModelEvaluation(
                status=HeatModelStatus.INSUFFICIENT_PUBLIC_HEALTH_CONTEXT,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "The aggregate training dataset is below the reviewed minimum size."
                ),
            )

        if not frame["minimum_group_size_passed"].all():
            return HeatModelEvaluation(
                status=HeatModelStatus.INSUFFICIENT_PUBLIC_HEALTH_CONTEXT,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "At least one aggregate record does not meet the minimum group-size rule."
                ),
            )

        if not frame["provenance_available"].all() or not frame["privacy_review_passed"].all():
            return HeatModelEvaluation(
                status=HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "Every training row requires provenance and privacy-review confirmation."
                ),
            )

        if frame["uncertainty_flag"].any():
            return HeatModelEvaluation(
                status=HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "At least one training row is marked uncertain. Review the data "
                    "before training rather than silently treating uncertainty as certainty."
                ),
            )

        ordered = frame.sort_values("observed_at_utc").reset_index(drop=True)
        features = ordered.loc[:, FEATURE_COLUMNS]
        labels = ordered["heat_support_escalation_label"]

        if labels.nunique() < 2:
            return HeatModelEvaluation(
                status=HeatModelStatus.INSUFFICIENT_PUBLIC_HEALTH_CONTEXT,
                auroc=None,
                average_precision=None,
                brier_score=None,
                explanation=(
                    "At least two target classes are required for supervised classification."
                ),
            )

        splits = TimeSeriesSplit(n_splits=3)
        train_index, test_index = list(splits.split(features))[-1]

        x_train = features.iloc[train_index]
        y_train = labels.iloc[train_index]
        x_test = features.iloc[test_index]
        y_test = labels.iloc[test_index]

        base = XGBClassifier(
            objective="binary:logistic",
            eval_metric="logloss",
            max_depth=4,
            learning_rate=0.05,
            n_estimators=250,
            subsample=0.85,
            colsample_bytree=0.85,
            reg_lambda=1.0,
            random_state=20260907,
            n_jobs=1,
        )

        calibrated = CalibratedClassifierCV(
            estimator=base,
            method="isotonic",
            cv=3,
        )
        calibrated.fit(x_train, y_train)

        probabilities = calibrated.predict_proba(x_test)[:, 1]
        auroc = float(roc_auc_score(y_test, probabilities))
        average_precision = float(average_precision_score(y_test, probabilities))
        brier = float(brier_score_loss(y_test, probabilities))

        self._model = calibrated

        acceptable = (
            auroc >= self.config.minimum_required_auroc
            and average_precision >= self.config.minimum_required_average_precision
            and brier <= self.config.maximum_allowed_brier_score
        )

        return HeatModelEvaluation(
            status=(
                HeatModelStatus.HEAT_SUPPORT_MONITORING
                if acceptable
                else HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED
            ),
            auroc=auroc,
            average_precision=average_precision,
            brier_score=brier,
            explanation=(
                "The model evaluates aggregate area-time heat-support conditions only. "
                "It does not predict individual health, eligibility, behavior, or need."
                if acceptable
                else
                "Performance or calibration thresholds were not met. Human review is required."
            ),
        )

    def predict(self, frame: pd.DataFrame) -> tuple[HeatSupportPrediction, ...]:
        if self._model is None:
            raise RuntimeError("fit must complete before prediction.")

        self.validate_frame(frame)

        predictions: list[HeatSupportPrediction] = []

        for row in frame.itertuples(index=False):
            if (
                not row.minimum_group_size_passed
                or not row.provenance_available
                or not row.privacy_review_passed
                or row.uncertainty_flag
            ):
                predictions.append(
                    HeatSupportPrediction(
                        planning_area_id=row.planning_area_id,
                        observed_at_utc=str(row.observed_at_utc),
                        probability=None,
                        status=HeatModelStatus.MODEL_CALIBRATION_REVIEW_REQUIRED,
                        explanation=(
                            "Required privacy, provenance, group-size, or uncertainty "
                            "conditions are not met."
                        ),
                    )
                )
                continue

            feature_row = pd.DataFrame(
                [[getattr(row, column) for column in FEATURE_COLUMNS]],
                columns=FEATURE_COLUMNS,
            )
            probability = float(self._model.predict_proba(feature_row)[0, 1])

            status = (
                HeatModelStatus.HEAT_SUPPORT_ESCALATION_REVIEW_REQUIRED
                if probability >= self.config.escalation_probability_threshold
                else HeatModelStatus.HEAT_SUPPORT_REVIEW_REQUIRED
            )

            predictions.append(
                HeatSupportPrediction(
                    planning_area_id=row.planning_area_id,
                    observed_at_utc=str(row.observed_at_utc),
                    probability=probability,
                    status=status,
                    explanation=(
                        "This is an aggregate planning signal for heat-support review. "
                        "It must not be used to identify, profile, deny, rank, or "
                        "make decisions about individual people."
                    ),
                )
            )

        return tuple(predictions)

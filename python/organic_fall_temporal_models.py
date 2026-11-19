"""Organic-fall temporal inference kernels.

License: MIT OR Apache-2.0
Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Requires NumPy and SciPy.
No network access, file creation, hardware control, or field calibration.
Lag penalties assume ordered, equally spaced lag bins.
"""

from dataclasses import dataclass
import math
import unittest

import numpy as np
from scipy.optimize import minimize
from scipy.stats import gamma as gamma_distribution


def vector(values, name):
    result = np.asarray(values, dtype=float)
    if result.ndim != 1 or not np.all(np.isfinite(result)):
        raise ValueError(f"{name} must be a finite one-dimensional array")
    return result


def positive(value, name):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise ValueError(f"{name} must be finite and positive")
    return result


def fit_lag_amplitudes(design, counts, background, penalty):
    """Fit mu = background + design @ theta, theta >= 0.

    design must already include the forward observation response.
    Returns a regularized point estimate, not a posterior.
    Background must yield positive means at the supplied starting point.
    """
    H = np.asarray(design, dtype=float)
    y = vector(counts, "counts")
    o = vector(background, "background")
    penalty = float(penalty)

    if H.ndim != 2 or H.shape[0] == 0 or H.shape[1] == 0:
        raise ValueError("design must be a nonempty two-dimensional array")
    if not np.all(np.isfinite(H)) or np.any(H < 0):
        raise ValueError("design must be finite and nonnegative")
    if H.shape[0] != len(y) or len(o) != len(y):
        raise ValueError("design, counts, and background dimensions differ")
    if np.any(y < 0) or np.any(y != np.floor(y)):
        raise ValueError("counts must be nonnegative integers")
    if np.any(o < 0):
        raise ValueError("background must be nonnegative")
    if not math.isfinite(penalty) or penalty < 0:
        raise ValueError("penalty must be finite and nonnegative")
    if np.any((H.sum(axis=1) == 0) & (o == 0)):
        raise ValueError("each observation needs a positive modeled mean")
    if np.any(H.sum(axis=0) == 0):
        raise ValueError("an entirely unobserved lag bin cannot be estimated")

    n_bins = H.shape[1]
    D = np.diff(np.eye(n_bins), n=2, axis=0)
    scale = max(float(y.sum()), 1.0) / max(float(H.sum()), 1e-12)
    start = np.full(n_bins, scale)

    def objective(theta):
        mu = o + H @ theta
        if np.any(mu <= 0):
            return math.inf
        roughness = D @ theta
        return (
            float(np.sum(mu - y * np.log(mu)))
            + 0.5 * penalty * float(roughness @ roughness)
        )

    def gradient(theta):
        mu = o + H @ theta
        if np.any(mu <= 0):
            return np.full(n_bins, np.nan)
        return H.T @ (1.0 - y / mu) + penalty * (D.T @ (D @ theta))

    result = minimize(
        objective,
        start,
        jac=gradient,
        method="L-BFGS-B",
        bounds=[(0.0, None)] * n_bins,
    )
    if not result.success or not np.all(np.isfinite(result.x)):
        raise RuntimeError(f"lag optimization failed: {result.message}")

    theta = result.x
    total = float(theta.sum())
    singular_values = np.linalg.svd(H, compute_uv=False)

    return {
        "amplitudes": theta,
        "total_amplitude": total,
        "lag_bin_probabilities": theta / total if total > 0 else None,
        "expected_counts": o + H @ theta,
        "design_rank": int(np.linalg.matrix_rank(H)),
        "number_of_lag_bins": n_bins,
        "singular_values": singular_values,
        "penalty": penalty,
        "objective": float(result.fun),
    }


def background_posterior(counts, effective_exposures,
                         prior_shape, prior_rate, credibility=0.95):
    """Gamma-Poisson update; exposures are known effective area-years.

    Rate density is per area-year. This does not automatically return
    a patch-level occupancy hazard.
    """
    y = vector(counts, "counts")
    exposure = vector(effective_exposures, "effective_exposures")
    if len(y) == 0 or len(y) != len(exposure):
        raise ValueError("nonempty counts and exposures must have equal lengths")
    if np.any(y < 0) or np.any(y != np.floor(y)):
        raise ValueError("counts must be nonnegative integers")
    if np.any(exposure < 0):
        raise ValueError("exposures cannot be negative")
    if np.any((exposure == 0) & (y > 0)):
        raise ValueError("positive counts cannot have zero effective exposure")

    a0 = positive(prior_shape, "prior_shape")
    b0 = positive(prior_rate, "prior_rate")
    credibility = float(credibility)
    if not math.isfinite(credibility) or not 0 < credibility < 1:
        raise ValueError("credibility must lie strictly between zero and one")

    shape = a0 + float(y.sum())
    rate = b0 + float(exposure.sum())
    tail = (1.0 - credibility) / 2.0
    interval = gamma_distribution.ppf(
        [tail, 1.0 - tail],
        a=shape,
        scale=1.0 / rate,
    )
    return {
        "shape": shape,
        "rate": rate,
        "mean_rate_density": shape / rate,
        "credible_interval": tuple(float(x) for x in interval),
        "credibility": credibility,
        "effective_exposure_total": float(exposure.sum()),
    }


@dataclass(frozen=True)
class LifetimeRecord:
    """All times are years since a defined stage onset.

    kind: 'exact', 'right', or 'interval'.
    exact: lower is the event time; upper must be None.
    right: lower is censoring time; upper must be None.
    interval: end lies in (lower, upper].
    entry: known delayed-entry age, conditional on remaining active.
    """
    kind: str
    lower: float
    upper: float | None = None
    entry: float = 0.0


def weibull_record_loglik(record, shape, scale):
    """Exact/right/interval-censored likelihood with known delayed entry."""
    k = positive(shape, "shape")
    lam = positive(scale, "scale")
    lower = float(record.lower)
    entry = float(record.entry)
    if not math.isfinite(lower) or not math.isfinite(entry):
        raise ValueError("record times must be finite")
    if lower < 0 or entry < 0:
        raise ValueError("record times cannot be negative")

    def cumulative_hazard(t):
        if t == 0:
            return 0.0
        return math.exp(k * (math.log(t) - math.log(lam)))

    h_entry = cumulative_hazard(entry)

    if record.kind == "exact":
        if record.upper is not None or lower <= entry:
            raise ValueError("exact event must occur strictly after entry")
        h = cumulative_hazard(lower)
        log_density = (
            math.log(k) - math.log(lam)
            + (k - 1.0) * (math.log(lower) - math.log(lam))
            - h
        )
        return log_density + h_entry

    if record.kind == "right":
        if record.upper is not None or lower < entry:
            raise ValueError("right censoring must occur at or after entry")
        return -cumulative_hazard(lower) + h_entry

    if record.kind == "interval":
        if record.upper is None:
            raise ValueError("interval censoring requires an upper bound")
        upper = float(record.upper)
        left = max(lower, entry)
        if not math.isfinite(upper) or upper <= left:
            raise ValueError("interval must contain possible events after entry")
        h_left = cumulative_hazard(left)
        h_right = cumulative_hazard(upper)
        delta = h_right - h_left
        if delta <= 0:
            raise ArithmeticError("interval probability is numerically unresolved")
        return -h_left + math.log(-math.expm1(-delta)) + h_entry

    raise ValueError("unknown censoring kind")


def weibull_aft_loglik(beta, log_shape, design, records):
    """Total lifetime log likelihood, with scale_i = exp(X_i @ beta).

    design should include an intercept column if an intercept is wanted.
    Covariates and onset/entry times must already be prepared and reviewed.
    """
    X = np.asarray(design, dtype=float)
    b = vector(beta, "beta")
    records = tuple(records)
    if X.ndim != 2 or X.shape != (len(records), len(b)):
        raise ValueError("design dimensions do not match records and coefficients")
    if len(records) == 0 or not np.all(np.isfinite(X)):
        raise ValueError("design must be nonempty and finite")
    log_shape = float(log_shape)
    if not math.isfinite(log_shape):
        raise ValueError("log_shape must be finite")

    k = math.exp(log_shape)
    log_scales = X @ b
    if not np.all(np.isfinite(log_scales)):
        raise ValueError("nonfinite scale predictor")
    return math.fsum(
        weibull_record_loglik(record, k, math.exp(float(eta)))
        for record, eta in zip(records, log_scales)
    )


class TemporalModelTests(unittest.TestCase):
    """Synthetic fixtures only; not environmental observations."""

    def test_background_update(self):
        result = background_posterior([2, 0], [1.0, 3.0], 1.0, 2.0)
        self.assertEqual(result["shape"], 3.0)
        self.assertEqual(result["rate"], 6.0)
        self.assertAlmostEqual(result["mean_rate_density"], 0.5)

    def test_impossible_exposure(self):
        with self.assertRaises(ValueError):
            background_posterior([1], [0], 1, 1)

    def test_exponential_right_censoring(self):
        record = LifetimeRecord("right", lower=3, entry=1)
        self.assertAlmostEqual(weibull_record_loglik(record, 1, 2), -1)

    def test_exponential_interval(self):
        record = LifetimeRecord("interval", lower=1, upper=3)
        expected = math.log(math.exp(-0.5) - math.exp(-1.5))
        self.assertAlmostEqual(weibull_record_loglik(record, 1, 2), expected)

    def test_exact_with_entry(self):
        record = LifetimeRecord("exact", lower=3, entry=1)
        expected = -math.log(2) - 1
        self.assertAlmostEqual(weibull_record_loglik(record, 1, 2), expected)

    def test_aft_total(self):
        rows = [LifetimeRecord("right", 2), LifetimeRecord("right", 4)]
        result = weibull_aft_loglik(
            [math.log(2)], 0, [[1], [1]], rows
        )
        self.assertAlmostEqual(result, -3)

    def test_lag_recovery(self):
        result = fit_lag_amplitudes(
            np.eye(3),
            [2, 4, 6],
            [0.1, 0.1, 0.1],
            penalty=0,
        )
        np.testing.assert_allclose(
            result["expected_counts"], [2, 4, 6], atol=1e-3
        )


if __name__ == "__main__":
    unittest.main()

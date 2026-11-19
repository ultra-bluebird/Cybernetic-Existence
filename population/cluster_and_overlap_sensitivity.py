"""Synthetic clustering sensitivity and aggregate overlap bounds.

Attribution:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit only, not identity verification, consent, or authority.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from itertools import product

import numpy as np
import pandas as pd
from scipy.optimize import Bounds, LinearConstraint, linprog, milp


def integer_vector(values, name):
    raw = np.asarray(values)
    if raw.dtype.kind not in "iu f".replace(" ", ""):
        raise ValueError(f"{name}: numeric integer counts required")
    a = np.asarray(values, dtype=float)
    if (
        a.ndim != 1
        or a.size == 0
        or not np.all(np.isfinite(a))
        or np.any(a < 0)
        or np.any(a > 2**53 - 1)
        or np.any(a != np.floor(a))
    ):
        raise ValueError(f"{name}: finite nonnegative integer vector required")
    return a


def sensitivity(population, sample, outcomes, deff):
    N = integer_vector(population, "population")
    n = integer_vector(sample, "sample")
    x = integer_vector(outcomes, "outcomes")
    if not (N.shape == n.shape == x.shape):
        raise ValueError("Stratum vectors must have matching shapes")
    if np.any(N < 1) or np.any(n < 2) or np.any(n > N) or np.any(x > n):
        raise ValueError("Require N >= n >= 2 and 0 <= x <= n")

    d = np.asarray(deff, dtype=float)
    if d.ndim != 2 or d.shape[1] != N.size:
        raise ValueError("DEFF must have one column per stratum")
    if not np.all(np.isfinite(d)) or np.any(d <= 0):
        raise ValueError("DEFF values must be finite and positive")

    p = x / n
    noncensus = n < N
    if np.any(noncensus & ((x < 5) | (n - x < 5))):
        raise ValueError("Sparse noncensus outcomes need another interval method")

    v = N**2 * (1 - n / N) * p * (1 - p) / (n - 1)
    baseline = v.sum()
    if baseline <= 0:
        raise ValueError("Positive baseline variance required for width ratios")

    variance = d @ v
    z = 1.959963984540054
    return pd.DataFrame({
        "estimated_total": np.repeat(np.sum(N * p), len(d)),
        "standard_error": np.sqrt(variance),
        "full_interval_width": 2 * z * np.sqrt(variance),
        "width_ratio": np.sqrt(variance / baseline),
    })


def simulate_clusters(deffs, repetitions=10000, seed=137):
    if not isinstance(repetitions, int) or repetitions < 2:
        raise ValueError("At least two simulation repetitions required")

    rng = np.random.default_rng(seed)
    N = np.array([6000.0, 4000.0])
    n = np.array([120, 80])
    p = np.array([0.30, 0.50])
    cluster_size = 10
    baseline = np.sum(N**2 * p * (1 - p) / n)
    rows = []

    for d in deffs:
        if not np.isfinite(d) or not 1 <= d < cluster_size:
            raise ValueError("Simulation requires 1 <= DEFF < cluster size")
        rho = (d - 1) / (cluster_size - 1)
        totals = np.zeros(repetitions)

        for Nh, nh, ph in zip(N, n, p):
            if rho == 0:
                successes = rng.binomial(nh, ph, size=repetitions)
            else:
                concentration = 1 / rho - 1
                theta = rng.beta(
                    ph * concentration,
                    (1 - ph) * concentration,
                    size=(repetitions, nh // cluster_size),
                )
                successes = rng.binomial(cluster_size, theta).sum(axis=1)
            totals += Nh * successes / nh

        rows.append({
            "deff": d,
            "icc": rho,
            "simulated_mean": totals.mean(),
            "sd_ratio": totals.std(ddof=1) / np.sqrt(baseline),
            "repetitions": repetitions,
            "seed": seed,
            "model": "superpopulation_beta_binomial_no_fpc",
        })

    return pd.DataFrame(rows)


def union_bounds(cohort, marginals, pairs=(), integer=False):
    total = integer_vector([cohort], "cohort")[0]
    f = integer_vector(marginals, "marginals")
    k = len(f)
    if total < 1 or k > 10 or np.any(f > total):
        raise ValueError("Require positive cohort, at most 10 properties, f <= N")

    patterns = np.array(list(product((0, 1), repeat=k)), dtype=float)
    objective = patterns.any(axis=1).astype(float)
    rows = [np.ones(len(patterns)), *patterns.T]
    rhs = [total, *f]
    seen = set()

    for i, j, count in pairs:
        if (
            not isinstance(i, (int, np.integer))
            or not isinstance(j, (int, np.integer))
            or not 0 <= i < j < k
            or (i, j) in seen
        ):
            raise ValueError("Pairs need unique zero-based indices i < j")
        q = integer_vector([count], "intersection")[0]
        if not max(0, f[i] + f[j] - total) <= q <= min(f[i], f[j]):
            raise ValueError("Intersection violates pairwise feasibility")
        seen.add((i, j))
        rows.append(patterns[:, i] * patterns[:, j])
        rhs.append(q)

    A = np.vstack(rows)
    b = np.asarray(rhs)
    values = []

    for sign in (1, -1):
        if integer:
            fit = milp(
                sign * objective,
                integrality=np.ones(len(patterns)),
                bounds=Bounds(0, total),
                constraints=LinearConstraint(A, b, b),
                options={"time_limit": 30.0, "mip_rel_gap": 0.0},
            )
        else:
            fit = linprog(
                sign * objective,
                A_eq=A,
                b_eq=b,
                bounds=(0, total),
                method="highs",
                options={"time_limit": 30.0},
            )

        if not fit.success:
            raise RuntimeError(
                f"Optimization not established: status={fit.status}; {fit.message}"
            )
        if np.max(np.abs(A @ fit.x - b)) > 1e-6:
            raise RuntimeError("Solver equality residual exceeded tolerance")
        if integer and np.max(np.abs(fit.x - np.rint(fit.x))) > 1e-6:
            raise RuntimeError("Integer solution tolerance exceeded")
        values.append(float(objective @ fit.x))

    return {
        "lower": values[0],
        "upper": values[1],
        "method": "integer_patterns" if integer else "LP_relaxation",
    }


def demo():
    scenarios = [1.0, 1.5, 2.0, 3.0]
    analytic = sensitivity(
        [6000, 4000], [120, 80], [36, 40],
        np.repeat(np.array(scenarios)[:, None], 2, axis=1),
    )
    simulation = simulate_clusters(scenarios)

    pair_sets = [
        (),
        ((0, 1, 12),),
        ((0, 1, 12), (0, 2, 8)),
        ((0, 1, 12), (0, 2, 8), (1, 2, 5)),
    ]
    expected = [(30, 75), (43, 63), (43, 55), (50, 55)]
    overlap = []

    for pairs, target in zip(pair_sets, expected):
        lp = union_bounds(100, [30, 25, 20], pairs)
        exact = union_bounds(100, [30, 25, 20], pairs, integer=True)
        assert np.allclose([lp["lower"], lp["upper"]], target)
        assert np.allclose([exact["lower"], exact["upper"]], target)
        overlap.append({"known_pairs": len(pairs), **exact})

    assert np.allclose(analytic["estimated_total"], 3800)
    assert np.allclose(analytic["width_ratio"], np.sqrt(scenarios))
    return analytic, simulation, pd.DataFrame(overlap)


if __name__ == "__main__":
    analytic, simulation, overlap = demo()
    print(analytic.to_string(index=False))
    print(simulation.to_string(index=False))
    print(overlap.to_string(index=False))

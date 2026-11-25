# SPDX-License-Identifier: MIT OR Apache-2.0
"""Interval-coverage evaluation by condition stratum. Local calculation only."""
from dataclasses import dataclass
import math
import random
import re
import unittest

Z95 = 1.959963984540054
TOKEN = re.compile(r"[A-Za-z0-9][A-Za-z0-9 ._:/-]{0,119}")


def _num(value, name):
    if type(value) not in (int, float):
        raise ValueError(name)
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(name)
    return result


def _token(value):
    return type(value) is str and TOKEN.fullmatch(value) is not None


def wilson(hits, n, z=Z95):
    """Wilson score interval for a binomial proportion (independent trials)."""
    if type(hits) is not int or type(n) is not int or n < 1 or not 0 <= hits <= n:
        raise ValueError("hits")
    p = hits / n
    centre = p + z * z / (2 * n)
    margin = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    den = 1 + z * z / n
    return max(0.0, (centre - margin) / den), min(1.0, (centre + margin) / den)


@dataclass(frozen=True)
class Trial:
    reference: float
    lower: float
    upper: float
    stratum: str
    group: str
    reference_sd: float = 0.0


def _outcomes(t, k):
    lo, hi, ref, sd = t.lower, t.upper, t.reference, t.reference_sd
    strict = lo <= ref <= hi
    certain = lo + k * sd <= ref <= hi - k * sd
    possible = lo - k * sd <= ref <= hi + k * sd
    return strict, certain, possible


def _bootstrap(groups, boot, rnd):
    if boot == 0 or len(groups) < 2:
        return None
    ps = []
    for _ in range(boot):
        hits = count = 0
        for _ in groups:
            g = groups[rnd.randrange(len(groups))]
            hits += g[0]
            count += g[1]
        ps.append(hits / count)
    ps.sort()
    mean = sum(ps) / boot
    var = sum((p - mean) ** 2 for p in ps) / (boot - 1)
    return var, (ps[int(0.025 * boot)], ps[math.ceil(0.975 * boot) - 1])


def evaluate(trials, ref_k=1.96, min_stratum=30, boot=1000, seed=1):
    """Coverage per stratum with reference-uncertainty band and group bootstrap.

    Trials from one group (for example one vehicle run) are treated as
    dependent. Wilson bounds assume independence; design_effect compares the
    group-bootstrap variance with the independent-binomial variance.
    """
    k = _num(ref_k, "ref_k")
    if (k < 0 or type(min_stratum) is not int or min_stratum < 1 or type(seed) is not int
            or type(boot) is not int or not (boot == 0 or 200 <= boot <= 5000)):
        raise ValueError("options")
    if not isinstance(trials, (list, tuple)) or not trials:
        raise ValueError("trials")
    strata = {}
    for t in trials:
        if not isinstance(t, Trial) or not (_token(t.stratum) and _token(t.group)):
            raise ValueError("trial")
        ref, lo, hi, sd = (_num(v, "trial") for v in
                           (t.reference, t.lower, t.upper, t.reference_sd))
        if ref < 0 or sd < 0 or lo > hi:
            raise ValueError("trial")
        s = strata.setdefault(t.stratum, {"n": 0, "strict": 0, "certain": 0,
                                          "possible": 0, "width": 0.0, "groups": {}})
        strict, certain, possible = _outcomes(Trial(ref, lo, hi, t.stratum, t.group, sd), k)
        s["n"] += 1
        s["strict"] += strict
        s["certain"] += certain
        s["possible"] += possible
        s["width"] += hi - lo
        g = s["groups"].setdefault(t.group, [0, 0])
        g[0] += strict
        g[1] += 1
    rnd = random.Random(seed)
    report, insufficient = {}, []
    for name in sorted(strata):
        s = strata[name]
        lower, upper = wilson(s["strict"], s["n"])
        p = s["strict"] / s["n"]
        groups = [tuple(v) for v in s["groups"].values()]
        boot_result = _bootstrap(groups, boot, rnd)
        binom_var = p * (1 - p) / s["n"]
        deff = None
        if boot_result is not None and binom_var > 0:
            deff = boot_result[0] / binom_var
        sufficient = s["n"] >= min_stratum
        if not sufficient:
            insufficient.append(name)
        report[name] = {"n": s["n"], "groups": len(groups), "coverage": p,
                        "wilson_lower": lower, "wilson_upper": upper,
                        "reference_band": (s["certain"] / s["n"], s["possible"] / s["n"]),
                        "mean_width": s["width"] / s["n"], "design_effect": deff,
                        "bootstrap_interval": None if boot_result is None else boot_result[1],
                        "sufficient": sufficient}
    total_n = sum(s["n"] for s in strata.values())
    total_hits = sum(s["strict"] for s in strata.values())
    pooled_lo, pooled_hi = wilson(total_hits, total_n)
    eligible = [(report[n]["wilson_lower"], n) for n in report if report[n]["sufficient"]]
    worst = min(eligible) if eligible else None
    return {"pooled": {"n": total_n, "coverage": total_hits / total_n,
                       "wilson_lower": pooled_lo, "wilson_upper": pooled_hi},
            "strata": report, "worst_stratum": worst[1] if worst else None,
            "worst_lower": worst[0] if worst else None,
            "insufficient": tuple(insufficient), "publication_authorized": False}


class Tests(unittest.TestCase):
    def build(self, stratum, hits, misses, run_size=10, start=0):
        out = []
        for i in range(hits + misses):
            hit = i < hits
            out.append(Trial(5.0, 4.0 if hit else 6.0, 7.0, stratum,
                             "run %d" % (start + i // run_size)))
        return out

    def test_wilson_values(self):
        lo, hi = wilson(98, 100)
        self.assertAlmostEqual(lo, 0.9300, places=3)
        self.assertAlmostEqual(wilson(0, 30)[0], 0.0)
        self.assertEqual(wilson(30, 30)[1], 1.0)
        for args in [(-1, 10), (11, 10), (1, 0), (True, 10), (1.0, 10)]:
            with self.assertRaises(ValueError):
                wilson(*args)

    def test_pooled_average_hides_difficult_condition(self):
        trials = self.build("normal", 570, 0) + self.build("occlusion", 0, 30, start=1000)
        r = evaluate(trials)
        self.assertAlmostEqual(r["pooled"]["coverage"], 0.95)
        self.assertEqual(r["worst_stratum"], "occlusion")
        self.assertLess(r["worst_lower"], 0.01)
        self.assertGreater(r["strata"]["occlusion"]["wilson_upper"], 0.05)
        self.assertFalse(r["publication_authorized"])

    def test_small_stratum_is_flagged_not_used(self):
        trials = self.build("normal", 100, 0) + self.build("rare", 0, 10, start=500)
        r = evaluate(trials, min_stratum=30)
        self.assertEqual(r["insufficient"], ("rare",))
        self.assertEqual(r["worst_stratum"], "normal")
        only_small = evaluate(self.build("rare", 5, 5), min_stratum=30)
        self.assertIsNone(only_small["worst_stratum"])

    def test_reference_uncertainty_band(self):
        trials = [Trial(10.0, 10.2, 12.0, "s", "a", 0.5),
                  Trial(11.0, 10.0, 12.0, "s", "b", 0.5),
                  Trial(11.0, 10.0, 11.4, "s", "c", 0.5)]
        s = evaluate(trials, min_stratum=1)["strata"]["s"]
        certain, possible = s["reference_band"]
        self.assertAlmostEqual(s["coverage"], 2 / 3)
        self.assertAlmostEqual(certain, 1 / 3)
        self.assertAlmostEqual(possible, 1.0)
        self.assertLessEqual(certain, s["coverage"])
        self.assertLessEqual(s["coverage"], possible)

    def test_dependence_inflates_design_effect(self):
        clustered = []
        for g in range(20):
            for _ in range(10):
                clustered.append(Trial(5.0, 4.0 if g < 10 else 6.0, 7.0, "c", "run %d" % g))
        deff = evaluate(clustered, min_stratum=1)["strata"]["c"]["design_effect"]
        self.assertGreater(deff, 5)
        rnd = random.Random(3)
        independent = []
        for g in range(40):
            for _ in range(10):
                independent.append(Trial(5.0, 4.0 if rnd.random() < 0.9 else 6.0, 7.0, "i", "run %d" % g))
        deff = evaluate(independent, min_stratum=1)["strata"]["i"]["design_effect"]
        self.assertTrue(0.5 < deff < 2.0)

    def synthetic(self, sd_true, sd_claimed, n, stratum, seed):
        rnd, half = random.Random(seed), 1.96 * sd_claimed
        out = []
        for i in range(n):
            err = rnd.gauss(0, sd_true)
            out.append(Trial(0.0, err - half, err + half, stratum, "run %d" % (i // 10)))
        return out

    def test_calibrated_and_understated_intervals(self):
        good = evaluate(self.synthetic(1.0, 1.0, 4000, "a", 5))["pooled"]["coverage"]
        bad = evaluate(self.synthetic(1.0, 0.6, 4000, "a", 5))["pooled"]["coverage"]
        self.assertLess(abs(good - 0.95), 0.02)
        self.assertLess(bad, 0.85)

    def test_shift_in_one_stratum(self):
        trials = (self.synthetic(1.0, 1.0, 2000, "normal", 1)
                  + self.synthetic(2.0, 1.0, 2000, "rush", 2))
        r = evaluate(trials)
        self.assertEqual(r["worst_stratum"], "rush")
        self.assertLess(r["strata"]["rush"]["coverage"], 0.75)
        self.assertGreater(r["pooled"]["coverage"], r["strata"]["rush"]["coverage"])

    def test_deterministic_and_validated(self):
        trials = self.build("n", 60, 0)
        self.assertEqual(evaluate(trials, seed=4), evaluate(trials, seed=4))
        bad_inputs = [[], (), "x", [Trial(5, 7, 6, "s", "g")],
                      [Trial(float("nan"), 1, 2, "s", "g")], [Trial(True, 1, 2, "s", "g")],
                      [Trial(-1, 1, 2, "s", "g")], [Trial(5, 4, 6, "s\n", "g")],
                      [Trial(5, 4, 6, "s", "g", -0.1)], [Trial(5, 4, 6, "s", "")]]
        for bad in bad_inputs:
            with self.assertRaises(ValueError):
                evaluate(bad)
        for opts in (dict(boot=10), dict(boot=True), dict(min_stratum=0), dict(ref_k=-1)):
            with self.assertRaises(ValueError):
                evaluate(trials, **opts)


if __name__ == "__main__":
    unittest.main()

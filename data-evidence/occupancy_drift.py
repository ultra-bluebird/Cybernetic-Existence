# SPDX-License-Identifier: MIT OR Apache-2.0
"""Occupancy error accumulation and an append-only correction ledger.

Local calculation only. Diagnostic estimates are never clipped; flags request
human review and carry no blame, enforcement, or boarding consequence.
"""
import hashlib
import json
import math
import random
import re
import unittest

TOKEN = re.compile(r"[A-Za-z0-9][A-Za-z0-9 ._:/-]{0,119}")
CHI2_1DOF_95 = 3.841458820694124


def _num(value, name):
    if type(value) not in (int, float):
        raise ValueError(name)
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(name)
    return result


def accumulated_error(steps, sigma, rho=0.0, bias_per_step=0.0, init_mean=0.0,
                      init_var=0.0, doors=1, door_corr=0.0):
    """Moments of E_T = E_0 + sum of step errors under stated assumptions.

    Each step error is the sum over doors of equicorrelated door errors
    (per-door sd sigma, correlation door_corr). Step errors form a stationary
    AR(1) series with lag-one correlation rho and constant mean bias_per_step.
    """
    s, r = _num(sigma, "sigma"), _num(rho, "rho")
    b, m0, v0 = _num(bias_per_step, "bias"), _num(init_mean, "init_mean"), _num(init_var, "init_var")
    dc = _num(door_corr, "door_corr")
    if type(steps) is not int or not 1 <= steps <= 100000 or type(doors) is not int \
            or not 1 <= doors <= 64:
        raise ValueError("steps or doors")
    if s <= 0 or v0 < 0 or not -1 < r < 1:
        raise ValueError("sigma, init_var, or rho")
    if doors > 1 and not (-1 / (doors - 1) < dc < 1) or doors == 1 and dc != 0:
        raise ValueError("door_corr")
    step_var = s * s * doors * (1 + (doors - 1) * dc)
    total, power = 0.0, 1.0
    for k in range(1, steps):
        power *= r
        total += (steps - k) * power
    variance = v0 + step_var * (steps + 2 * total)
    independent = v0 + steps * step_var
    mean = m0 + b * steps
    return {"mean": mean, "variance": variance, "mse": variance + mean * mean,
            "independent_variance": independent,
            "variance_ratio_true_over_independent": variance / independent}


class OccupancyLedger:
    """Raw trajectory is immutable; corrections are separate hash-chained entries.

    Variance propagation assumes independent step errors. For correlated
    increments the reported variance is understated; see accumulated_error.
    """
    GENESIS = "0" * 64

    def __init__(self, initial, initial_variance, step_variance, capacity=None,
                 max_steps=100000, chi2_limit=CHI2_1DOF_95):
        self._raw = [_num(initial, "initial")]
        self._var = _num(initial_variance, "initial_variance")
        self._step_var = _num(step_variance, "step_variance")
        self._chi2 = _num(chi2_limit, "chi2_limit")
        self._capacity = None if capacity is None else _num(capacity, "capacity")
        if (self._var < 0 or self._step_var < 0 or self._chi2 <= 0
                or (self._capacity is not None and self._capacity <= 0)
                or type(max_steps) is not int or not 1 <= max_steps <= 1000000):
            raise ValueError("ledger options")
        self._max = max_steps
        self._offset = 0.0
        self._entries = []

    def add_increment(self, delta):
        if len(self._raw) > self._max:
            raise ValueError("trajectory limit reached")
        self._raw.append(self._raw[-1] + _num(delta, "delta"))
        self._var += self._step_var

    @property
    def raw(self):
        return self._raw[-1]

    @property
    def adjusted(self):
        return self._raw[-1] + self._offset

    @property
    def variance(self):
        return self._var

    def trajectory(self):
        return tuple(self._raw)

    def flags(self):
        low = self.adjusted < 0
        high = self._capacity is not None and self.adjusted > self._capacity
        return {"below_zero": low, "above_capacity": high,
                "review_requested": low or high}

    @staticmethod
    def _digest(entry):
        body = {k: v for k, v in entry.items() if k != "hash"}
        data = json.dumps(body, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return hashlib.sha256(data).hexdigest()

    def correct(self, reference, reference_variance, procedure, apply_if_inconsistent=False):
        ref, rvar = _num(reference, "reference"), _num(reference_variance, "reference_variance")
        if rvar <= 0 or type(procedure) is not str or TOKEN.fullmatch(procedure) is None:
            raise ValueError("correction")
        before, var_before = self.adjusted, self._var
        innovation = ref - before
        total = var_before + rvar
        statistic = innovation * innovation / total
        applied = statistic <= self._chi2 or bool(apply_if_inconsistent)
        if applied:
            gain = var_before / total
            self._offset += gain * innovation
            self._var = var_before * rvar / total
        entry = {"index": len(self._entries), "step_index": len(self._raw) - 1,
                 "raw": self.raw, "adjusted_before": before,
                 "adjusted_after": self.adjusted, "variance_before": var_before,
                 "variance_after": self._var, "reference": ref,
                 "reference_variance": rvar, "procedure": procedure,
                 "statistic": statistic, "inconsistent": statistic > self._chi2,
                 "applied": applied,
                 "prev": self._entries[-1]["hash"] if self._entries else self.GENESIS}
        entry["hash"] = self._digest(entry)
        self._entries.append(entry)
        return dict(entry)

    def corrections(self):
        return tuple(dict(e) for e in self._entries)

    @classmethod
    def verify(cls, entries):
        prev = cls.GENESIS
        for i, e in enumerate(entries):
            try:
                if e["index"] != i or e["prev"] != prev or e["hash"] != cls._digest(e):
                    return False
            except (KeyError, TypeError):
                return False
            prev = e["hash"]
        return True


class Tests(unittest.TestCase):
    def matrix_variance(self, steps, sigma, rho, init_var=0.0):
        total = 0.0
        for i in range(steps):
            for j in range(steps):
                total += sigma * sigma * rho ** abs(i - j)
        return total + init_var

    def test_closed_form_matches_direct_matrix(self):
        for steps, sigma, rho, v0 in [(1, 1.0, 0.5, 0.0), (6, 0.7, 0.5, 0.3),
                                      (12, 1.3, -0.4, 1.0), (9, 2.0, 0.0, 0.0)]:
            r = accumulated_error(steps, sigma, rho, init_var=v0)
            self.assertAlmostEqual(r["variance"], self.matrix_variance(steps, sigma, rho, v0), places=9)

    def test_independent_case_and_asymptotic_ratio(self):
        r = accumulated_error(50, 0.5, 0.0, init_var=2.0)
        self.assertAlmostEqual(r["variance"], 2.0 + 50 * 0.25)
        self.assertAlmostEqual(r["variance_ratio_true_over_independent"], 1.0)
        long_run = accumulated_error(5000, 1.0, 0.5)
        self.assertAlmostEqual(long_run["variance_ratio_true_over_independent"], 3.0, delta=0.05)
        self.assertLess(accumulated_error(50, 1.0, -0.5)["variance_ratio_true_over_independent"], 1.0)

    def test_bias_has_no_averaging_floor(self):
        r = accumulated_error(100, 1.0, 0.0, bias_per_step=0.05, init_mean=2.0)
        self.assertAlmostEqual(r["mean"], 7.0)
        self.assertAlmostEqual(r["mse"], 100 + 49)

    def test_door_correlation_step_variance(self):
        r = accumulated_error(1, 1.0, 0.0, doors=3, door_corr=0.3)
        self.assertAlmostEqual(r["variance"], 4.8)
        for bad in (dict(doors=3, door_corr=-0.5), dict(doors=3, door_corr=1.0),
                    dict(doors=1, door_corr=0.2)):
            with self.assertRaises(ValueError):
                accumulated_error(5, 1.0, **bad)

    def test_invalid_accumulation_inputs(self):
        for args in [(0, 1.0), (True, 1.0), (5, 0.0), (5, float("nan")), (5, 1.0, 1.0),
                     (5, 1.0, 0.0, 0.0, 0.0, -1.0), (100001, 1.0)]:
            with self.assertRaises(ValueError):
                accumulated_error(*args)

    def test_monte_carlo_matches_closed_form_and_exposes_independence_gap(self):
        rnd, steps, sigma, rho, sims = random.Random(21), 100, 1.0, 0.5, 2000
        root, totals = math.sqrt(1 - rho * rho), []
        for _ in range(sims):
            e = rnd.gauss(0, sigma)
            acc = e
            for _ in range(steps - 1):
                e = rho * e + root * sigma * rnd.gauss(0, 1)
                acc += e
            totals.append(acc)
        empirical = sum(x * x for x in totals) / sims
        exact = accumulated_error(steps, sigma, rho)
        self.assertLess(abs(empirical / exact["variance"] - 1), 0.1)
        self.assertGreater(empirical / exact["independent_variance"], 2.5)

    def test_ledger_preserves_raw_trajectory(self):
        led = OccupancyLedger(0, 1.0, 0.25, capacity=40)
        for d in (3, 2, -1, 4):
            led.add_increment(d)
        before = led.trajectory()
        entry = led.correct(10.0, 1.0, "approved spot count")
        self.assertEqual(led.trajectory(), before)
        self.assertEqual(led.raw, 8)
        self.assertTrue(entry["applied"])
        gain = 2.0 / 3.0
        self.assertAlmostEqual(led.adjusted, 8 + gain * 2.0 - 0.0, places=9)
        self.assertAlmostEqual(led.variance, (1.0 + 4 * 0.25) * 1.0 / (2.0 + 1.0), places=9)
        self.assertLess(led.variance, entry["variance_before"])

    def test_inconsistent_reference_is_recorded_not_silently_applied(self):
        led = OccupancyLedger(0, 1.0, 0.25)
        led.add_increment(5)
        entry = led.correct(30.0, 1.0, "empty vehicle reference")
        self.assertTrue(entry["inconsistent"] and not entry["applied"])
        self.assertEqual(led.adjusted, 5)
        forced = led.correct(30.0, 1.0, "empty vehicle reference", apply_if_inconsistent=True)
        self.assertTrue(forced["applied"])
        self.assertGreater(led.adjusted, 5)

    def test_diagnostics_are_flagged_not_clipped(self):
        led = OccupancyLedger(0, 0.0, 0.0, capacity=10)
        led.add_increment(-2)
        self.assertEqual(led.adjusted, -2)
        self.assertEqual(led.flags(), {"below_zero": True, "above_capacity": False,
                                       "review_requested": True})
        led.add_increment(15)
        self.assertTrue(led.flags()["above_capacity"])
        led.add_increment(-5)
        self.assertFalse(led.flags()["review_requested"])

    def test_chain_detects_tampering_and_deletion(self):
        led = OccupancyLedger(0, 1.0, 0.1)
        for ref in (1.0, 2.0, 3.0):
            led.add_increment(1)
            led.correct(ref, 0.5, "approved spot count")
        entries = led.corrections()
        self.assertTrue(OccupancyLedger.verify(entries))
        changed = [dict(e) for e in entries]
        changed[1]["reference"] = 99.0
        self.assertFalse(OccupancyLedger.verify(changed))
        self.assertFalse(OccupancyLedger.verify(entries[1:]))
        self.assertFalse(OccupancyLedger.verify([entries[0], entries[2]]))
        entries[0]["raw"] = -1.0
        self.assertEqual(led.corrections()[0]["raw"], 1.0)

    def test_ledger_rejects_invalid_input(self):
        for args in [(float("nan"), 1, 1), (0, -1, 1), (0, 1, -1), (0, 1, 1, 0)]:
            with self.assertRaises(ValueError):
                OccupancyLedger(*args)
        led = OccupancyLedger(0, 1.0, 0.1, max_steps=2)
        with self.assertRaises(ValueError):
            led.correct(1.0, 0.0, "approved spot count")
        with self.assertRaises(ValueError):
            led.correct(1.0, 1.0, "bad\nlabel")
        with self.assertRaises(ValueError):
            led.add_increment(True)
        led.add_increment(1)
        led.add_increment(1)
        with self.assertRaises(ValueError):
            led.add_increment(1)

    def test_independent_variance_understates_correlated_increments(self):
        led = OccupancyLedger(0, 0.0, 1.0)
        for _ in range(100):
            led.add_increment(0)
        truth = accumulated_error(100, 1.0, 0.5)["variance"]
        self.assertAlmostEqual(led.variance, 100.0)
        self.assertGreater(truth / led.variance, 2.5)


if __name__ == "__main__":
    unittest.main()

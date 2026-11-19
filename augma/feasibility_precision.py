# SPDX-License-Identifier: MIT OR Apache-2.0
"""Wilson precision planning for one independent feasibility proportion."""

from math import sqrt
from statistics import NormalDist


def worst_case_wilson_half_width(sample_size, confidence=0.95):
    if type(sample_size) is not int or sample_size < 1:
        raise ValueError("positive integer sample size required")
    if type(confidence) is not float or not 0 < confidence < 1:
        raise ValueError("confidence must be a float between zero and one")
    z = NormalDist().inv_cdf((1 + confidence) / 2)
    return z / (2 * sqrt(sample_size + z * z))


def minimum_sample_for_precision(
    target_half_width, confidence=0.95, maximum_sample=10000
):
    if (
        type(target_half_width) is not float
        or not 0 < target_half_width < 0.5
    ):
        raise ValueError("target half-width must be between zero and 0.5")
    if type(maximum_sample) is not int or maximum_sample < 1:
        raise ValueError("positive maximum sample required")

    for sample_size in range(1, maximum_sample + 1):
        if worst_case_wilson_half_width(sample_size, confidence) <= target_half_width:
            return sample_size
    return None

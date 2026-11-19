from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, Sequence


class CanopyMetricsValidationError(ValueError):
    pass


@dataclass(frozen=True)
class CanopySummary:
    valid_pixel_count: int
    tree_pixel_count: int
    canopy_cover_fraction: float
    canopy_cover_percent: float


@dataclass(frozen=True)
class ThermalSummary:
    valid_pixel_count: int
    median_surface_temperature_c: float
    heat_anomaly: float
    hotspot_candidate: bool


def canopy_cover(
    pixel_labels: Iterable[int | None],
    tree_label: int = 1,
) -> CanopySummary:
    labels = list(pixel_labels)
    valid_labels = [label for label in labels if label is not None]

    if not valid_labels:
        raise CanopyMetricsValidationError(
            "At least one valid classified pixel is required."
        )

    if any(not isinstance(label, int) for label in valid_labels):
        raise CanopyMetricsValidationError(
            "Pixel labels must be integers or null for nodata."
        )

    tree_pixels = sum(label == tree_label for label in valid_labels)
    fraction = tree_pixels / len(valid_labels)

    return CanopySummary(
        valid_pixel_count=len(valid_labels),
        tree_pixel_count=tree_pixels,
        canopy_cover_fraction=fraction,
        canopy_cover_percent=fraction * 100.0,
    )


def kelvin_to_celsius(surface_temperature_kelvin: float) -> float:
    if not isfinite(surface_temperature_kelvin) or surface_temperature_kelvin <= 0.0:
        raise CanopyMetricsValidationError(
            "surface_temperature_kelvin must be finite and positive."
        )

    return surface_temperature_kelvin - 273.15


def heat_anomaly(
    local_surface_temperature_c: float,
    reference_median_c: float,
    reference_standard_deviation_c: float,
    stabilization: float = 1e-6,
) -> float:
    values = (
        local_surface_temperature_c,
        reference_median_c,
        reference_standard_deviation_c,
        stabilization,
    )

    if any(not isfinite(value) for value in values):
        raise CanopyMetricsValidationError(
            "Heat-anomaly inputs must be finite."
        )
    if reference_standard_deviation_c < 0.0:
        raise CanopyMetricsValidationError(
            "reference_standard_deviation_c must be non-negative."
        )
    if stabilization <= 0.0:
        raise CanopyMetricsValidationError("stabilization must be positive.")

    return (
        local_surface_temperature_c - reference_median_c
    ) / (reference_standard_deviation_c + stabilization)


def summarize_thermal_area(
    surface_temperatures_kelvin: Sequence[float | None],
    reference_median_c: float,
    reference_standard_deviation_c: float,
    hotspot_threshold: float = 2.0,
) -> ThermalSummary:
    values = [
        kelvin_to_celsius(value)
        for value in surface_temperatures_kelvin
        if value is not None
    ]

    if not values:
        raise CanopyMetricsValidationError(
            "At least one valid surface-temperature pixel is required."
        )
    if not isfinite(hotspot_threshold):
        raise CanopyMetricsValidationError("hotspot_threshold must be finite.")

    values.sort()
    midpoint = len(values) // 2
    if len(values) % 2:
        median = values[midpoint]
    else:
        median = (values[midpoint - 1] + values[midpoint]) / 2.0

    anomaly = heat_anomaly(
        median,
        reference_median_c,
        reference_standard_deviation_c,
    )

    return ThermalSummary(
        valid_pixel_count=len(values),
        median_surface_temperature_c=median,
        heat_anomaly=anomaly,
        hotspot_candidate=anomaly >= hotspot_threshold,
    )


def privacy_safe_remote_sensing_record() -> dict[str, bool]:
    return {
        "public_satellite_or_aerial_imagery_used": True,
        "ground_level_surveillance_used": False,
        "person_tracking_used": False,
        "mobile_device_data_used": False,
        "wifi_or_bluetooth_data_used": False,
        "property_value_data_used": False,
        "identity_data_used": False,
    }

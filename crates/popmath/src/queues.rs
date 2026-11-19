use crate::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};
use crate::units::PopulationWeight;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QueueCapacityInput {
    pub arrival_rate_per_hour: PopulationWeight,
    pub service_rate_per_hour_per_channel: PositiveF64,
    pub channels: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QueueCapacityResult {
    pub utilization: f64,
    pub stable: bool,
    pub minimum_channels_for_stability: u32,
    pub additional_channels_required: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QueueServiceLevelInput {
    pub arrival_rate_per_hour: PopulationWeight,
    pub service_rate_per_hour_per_channel: PositiveF64,
    pub target_utilization: UnitInterval,
    pub current_channels: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QueueServiceLevelResult {
    pub minimum_channels_for_target: u32,
    pub additional_channels_required: u32,
    pub current_utilization: Option<f64>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TwoClassQueueServiceLevelInput {
    pub standard_arrival_rate_per_hour: NonNegativeF64,
    pub extended_arrival_rate_per_hour: NonNegativeF64,
    pub standard_service_rate_per_hour: PositiveF64,
    pub extended_service_rate_per_hour: PositiveF64,
    pub channel_count: u32,
    pub maximum_extended_total_time_hours: NonNegativeF64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TwoClassQueueServiceLevelResult {
    pub standard_offered_load: NonNegativeF64,
    pub extended_offered_load: NonNegativeF64,
    pub total_offered_load: NonNegativeF64,
    pub utilization: NonNegativeF64,
    pub probability_of_wait: UnitInterval,
    pub expected_queue_wait_hours: Option<NonNegativeF64>,
    pub expected_standard_total_time_hours: Option<NonNegativeF64>,
    pub expected_extended_total_time_hours: Option<NonNegativeF64>,
    pub extended_service_continuity: UnitInterval,
    pub stable: bool,
}

pub fn calculate_queue_capacity(
    input: QueueCapacityInput,
) -> PopmathResult<QueueCapacityResult> {
    if input.channels == 0 {
        return Err(PopmathError::ZeroNotAllowed { field: "channels" });
    }

    let arrivals = input.arrival_rate_per_hour.get();
    let service_rate = input.service_rate_per_hour_per_channel.get();
    let capacity = f64::from(input.channels) * service_rate;

    if !arrivals.is_finite() || !service_rate.is_finite() || !capacity.is_finite() {
        return Err(PopmathError::NumericalInstability {
            component: "queue_capacity",
        });
    }

    if capacity <= 0.0 {
        return Err(PopmathError::DivisionByZero {
            field: "service_capacity",
        });
    }

    let utilization = arrivals / capacity;
    let minimum_channels_for_stability = minimum_channels_for_rate(
        arrivals,
        service_rate,
        "minimum_channels_for_stability",
    )?;

    Ok(QueueCapacityResult {
        utilization,
        stable: utilization < 1.0,
        minimum_channels_for_stability,
        additional_channels_required: minimum_channels_for_stability
            .saturating_sub(input.channels),
    })
}

pub fn calculate_queue_service_level(
    input: QueueServiceLevelInput,
) -> PopmathResult<QueueServiceLevelResult> {
    let target_utilization = input.target_utilization.get();

    if target_utilization <= 0.0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "target_utilization",
        });
    }

    let arrivals = input.arrival_rate_per_hour.get();
    let service_rate = input.service_rate_per_hour_per_channel.get();
    let target_capacity_per_channel = service_rate * target_utilization;

    if !arrivals.is_finite()
        || !service_rate.is_finite()
        || !target_capacity_per_channel.is_finite()
    {
        return Err(PopmathError::NumericalInstability {
            component: "queue_service_level",
        });
    }

    if target_capacity_per_channel <= 0.0 {
        return Err(PopmathError::DivisionByZero {
            field: "target_capacity_per_channel",
        });
    }

    let minimum_channels_for_target = minimum_channels_for_rate(
        arrivals,
        target_capacity_per_channel,
        "minimum_channels_for_target",
    )?;

    let current_utilization = if input.current_channels == 0 {
        None
    } else {
        let current_capacity = f64::from(input.current_channels) * service_rate;

        if !current_capacity.is_finite() || current_capacity <= 0.0 {
            return Err(PopmathError::NumericalInstability {
                component: "current_utilization",
            });
        }

        Some(arrivals / current_capacity)
    };

    Ok(QueueServiceLevelResult {
        minimum_channels_for_target,
        additional_channels_required: minimum_channels_for_target
            .saturating_sub(input.current_channels),
        current_utilization,
    })
}

pub fn calculate_two_class_queue_service_level(
    input: TwoClassQueueServiceLevelInput,
) -> PopmathResult<TwoClassQueueServiceLevelResult> {
    if input.channel_count == 0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "channel_count",
        });
    }

    let standard_arrival_rate = input.standard_arrival_rate_per_hour.value();
    let extended_arrival_rate = input.extended_arrival_rate_per_hour.value();
    let standard_service_rate = input.standard_service_rate_per_hour.get();
    let extended_service_rate = input.extended_service_rate_per_hour.get();
    let total_arrival_rate = standard_arrival_rate + extended_arrival_rate;

    if total_arrival_rate <= 0.0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "total_arrival_rate_per_hour",
        });
    }

    let standard_offered_load = standard_arrival_rate / standard_service_rate;
    let extended_offered_load = extended_arrival_rate / extended_service_rate;
    let total_offered_load = standard_offered_load + extended_offered_load;
    let utilization = total_offered_load / f64::from(input.channel_count);

    validate_two_class_intermediates(
        standard_offered_load,
        extended_offered_load,
        total_offered_load,
        utilization,
    )?;

    if utilization >= 1.0 {
        return Ok(TwoClassQueueServiceLevelResult {
            standard_offered_load: NonNegativeF64::new(standard_offered_load)?,
            extended_offered_load: NonNegativeF64::new(extended_offered_load)?,
            total_offered_load: NonNegativeF64::new(total_offered_load)?,
            utilization: NonNegativeF64::new(utilization)?,
            probability_of_wait: UnitInterval::new(1.0, "probability_of_wait")?,
            expected_queue_wait_hours: None,
            expected_standard_total_time_hours: None,
            expected_extended_total_time_hours: None,
            extended_service_continuity: UnitInterval::new(
                0.0,
                "extended_service_continuity",
            )?,
            stable: false,
        });
    }

    let probability_of_wait = erlang_c_probability(
        total_offered_load,
        input.channel_count,
    )?;

    let equivalent_service_rate = total_arrival_rate / total_offered_load;
    let remaining_service_rate =
        f64::from(input.channel_count) * equivalent_service_rate
            - total_arrival_rate;

    if !remaining_service_rate.is_finite() || remaining_service_rate <= 0.0 {
        return Err(PopmathError::NumericalInstability {
            component: "two_class_remaining_service_rate",
        });
    }

    let expected_queue_wait_hours =
        probability_of_wait / remaining_service_rate;

    let expected_standard_total_time_hours =
        expected_queue_wait_hours + (1.0 / standard_service_rate);

    let expected_extended_total_time_hours =
        expected_queue_wait_hours + (1.0 / extended_service_rate);

    if !expected_queue_wait_hours.is_finite()
        || !expected_standard_total_time_hours.is_finite()
        || !expected_extended_total_time_hours.is_finite()
    {
        return Err(PopmathError::NumericalInstability {
            component: "two_class_queue_wait",
        });
    }

    let extended_service_continuity = if expected_extended_total_time_hours
        <= input.maximum_extended_total_time_hours.value()
    {
        1.0
    } else {
        0.0
    };

    Ok(TwoClassQueueServiceLevelResult {
        standard_offered_load: NonNegativeF64::new(standard_offered_load)?,
        extended_offered_load: NonNegativeF64::new(extended_offered_load)?,
        total_offered_load: NonNegativeF64::new(total_offered_load)?,
        utilization: NonNegativeF64::new(utilization)?,
        probability_of_wait: UnitInterval::new(
            probability_of_wait,
            "probability_of_wait",
        )?,
        expected_queue_wait_hours: Some(NonNegativeF64::new(
            expected_queue_wait_hours,
        )?),
        expected_standard_total_time_hours: Some(NonNegativeF64::new(
            expected_standard_total_time_hours,
        )?),
        expected_extended_total_time_hours: Some(NonNegativeF64::new(
            expected_extended_total_time_hours,
        )?),
        extended_service_continuity: UnitInterval::new(
            extended_service_continuity,
            "extended_service_continuity",
        )?,
        stable: true,
    })
}

fn minimum_channels_for_rate(
    arrival_rate: f64,
    capacity_per_channel: f64,
    component: &'static str,
) -> PopmathResult<u32> {
    if !arrival_rate.is_finite() || !capacity_per_channel.is_finite() {
        return Err(PopmathError::NumericalInstability { component });
    }

    if arrival_rate < 0.0 {
        return Err(PopmathError::NegativeValue {
            field: "arrival_rate",
        });
    }

    if capacity_per_channel <= 0.0 {
        return Err(PopmathError::DivisionByZero {
            field: "capacity_per_channel",
        });
    }

    let required = (arrival_rate / capacity_per_channel).ceil();

    if !required.is_finite() || required > f64::from(u32::MAX) {
        return Err(PopmathError::NumericalInstability { component });
    }

    Ok(required as u32)
}

fn validate_two_class_intermediates(
    standard_offered_load: f64,
    extended_offered_load: f64,
    total_offered_load: f64,
    utilization: f64,
) -> PopmathResult<()> {
    for value in [
        standard_offered_load,
        extended_offered_load,
        total_offered_load,
        utilization,
    ] {
        if !value.is_finite() || value < 0.0 {
            return Err(PopmathError::NumericalInstability {
                component: "two_class_queue_inputs",
            });
        }
    }

    Ok(())
}

fn erlang_c_probability(
    offered_load: f64,
    channel_count: u32,
) -> PopmathResult<f64> {
    if !offered_load.is_finite() || offered_load < 0.0 {
        return Err(PopmathError::NumericalInstability {
            component: "erlang_c_offered_load",
        });
    }

    if channel_count == 0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "channel_count",
        });
    }

    let utilization = offered_load / f64::from(channel_count);

    if utilization >= 1.0 {
        return Ok(1.0);
    }

    let channels = usize::try_from(channel_count).map_err(|_| {
        PopmathError::NumericalInstability {
            component: "erlang_c_channel_count",
        }
    })?;

    let mut sum = 1.0;
    let mut term = 1.0;

    for index in 1..channels {
        term *= offered_load / index as f64;
        sum += term;
    }

    term *= offered_load / channels as f64;

    let waiting_term = term / (1.0 - utilization);
    let denominator = sum + waiting_term;

    if !waiting_term.is_finite()
        || !denominator.is_finite()
        || denominator <= 0.0
    {
        return Err(PopmathError::NumericalInstability {
            component: "erlang_c_probability",
        });
    }

    UnitInterval::new(
        waiting_term / denominator,
        "probability_of_wait",
    )
    .map(|value| value.get())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unstable_queue_reports_required_capacity() {
        let result = calculate_queue_capacity(QueueCapacityInput {
            arrival_rate_per_hour: PopulationWeight::new(25.0).expect("valid"),
            service_rate_per_hour_per_channel: PositiveF64::new(
                10.0,
                "service_rate",
            )
            .expect("valid"),
            channels: 2,
        })
        .expect("valid capacity screen");

        assert!(!result.stable);
        assert_eq!(result.minimum_channels_for_stability, 3);
        assert_eq!(result.additional_channels_required, 1);
        assert!((result.utilization - 1.25).abs() < f64::EPSILON);
    }

    #[test]
    fn utilization_target_increases_capacity_requirement() {
        let result = calculate_queue_service_level(QueueServiceLevelInput {
            arrival_rate_per_hour: PopulationWeight::new(25.0).expect("valid"),
            service_rate_per_hour_per_channel: PositiveF64::new(
                10.0,
                "service_rate",
            )
            .expect("valid"),
            target_utilization: UnitInterval::new(
                0.75,
                "target_utilization",
            )
            .expect("valid"),
            current_channels: 3,
        })
        .expect("valid service-level calculation");

        assert_eq!(result.minimum_channels_for_target, 4);
        assert_eq!(result.additional_channels_required, 1);
        assert_eq!(result.current_utilization, Some(25.0 / 30.0));
    }

    #[test]
    fn zero_channel_capacity_screen_returns_structured_error() {
        let error = calculate_queue_capacity(QueueCapacityInput {
            arrival_rate_per_hour: PopulationWeight::new(10.0).expect("valid"),
            service_rate_per_hour_per_channel: PositiveF64::new(
                10.0,
                "service_rate",
            )
            .expect("valid"),
            channels: 0,
        })
        .expect_err("zero channels must fail");

        assert!(matches!(
            error,
            PopmathError::ZeroNotAllowed { field: "channels" }
        ));
    }

    #[test]
    fn unstable_two_class_queue_has_no_finite_wait_time_claim() {
        let result = calculate_two_class_queue_service_level(
            TwoClassQueueServiceLevelInput {
                standard_arrival_rate_per_hour: NonNegativeF64::new(18.0)
                    .expect("valid"),
                extended_arrival_rate_per_hour: NonNegativeF64::new(8.0)
                    .expect("valid"),
                standard_service_rate_per_hour: PositiveF64::new(
                    12.0,
                    "standard_service_rate",
                )
                .expect("valid"),
                extended_service_rate_per_hour: PositiveF64::new(
                    4.0,
                    "extended_service_rate",
                )
                .expect("valid"),
                channel_count: 2,
                maximum_extended_total_time_hours: NonNegativeF64::new(1.0)
                    .expect("valid"),
            },
        )
        .expect("unstable result remains reportable");

        assert!(!result.stable);
        assert_eq!(result.probability_of_wait.get(), 1.0);
        assert_eq!(result.expected_queue_wait_hours, None);
        assert_eq!(result.expected_standard_total_time_hours, None);
        assert_eq!(result.expected_extended_total_time_hours, None);
        assert_eq!(result.extended_service_continuity.get(), 0.0);
    }

    #[test]
    fn stable_two_class_queue_reports_extended_service_continuity() {
        let result = calculate_two_class_queue_service_level(
            TwoClassQueueServiceLevelInput {
                standard_arrival_rate_per_hour: NonNegativeF64::new(8.0)
                    .expect("valid"),
                extended_arrival_rate_per_hour: NonNegativeF64::new(2.0)
                    .expect("valid"),
                standard_service_rate_per_hour: PositiveF64::new(
                    12.0,
                    "standard_service_rate",
                )
                .expect("valid"),
                extended_service_rate_per_hour: PositiveF64::new(
                    4.0,
                    "extended_service_rate",
                )
                .expect("valid"),
                channel_count: 2,
                maximum_extended_total_time_hours: NonNegativeF64::new(0.5)
                    .expect("valid"),
            },
        )
        .expect("stable queue result");

        assert!(result.stable);
        assert!(result.utilization.get() < 1.0);
        assert!(result.expected_queue_wait_hours.is_some());
        assert!(result.expected_standard_total_time_hours.is_some());
        assert!(result.expected_extended_total_time_hours.is_some());
        assert_eq!(result.extended_service_continuity.get(), 1.0);
    }

    #[test]
    fn tighter_extended_service_target_reports_unmet_continuity() {
        let result = calculate_two_class_queue_service_level(
            TwoClassQueueServiceLevelInput {
                standard_arrival_rate_per_hour: NonNegativeF64::new(8.0)
                    .expect("valid"),
                extended_arrival_rate_per_hour: NonNegativeF64::new(2.0)
                    .expect("valid"),
                standard_service_rate_per_hour: PositiveF64::new(
                    12.0,
                    "standard_service_rate",
                )
                .expect("valid"),
                extended_service_rate_per_hour: PositiveF64::new(
                    4.0,
                    "extended_service_rate",
                )
                .expect("valid"),
                channel_count: 2,
                maximum_extended_total_time_hours: NonNegativeF64::new(0.2)
                    .expect("valid"),
            },
        )
        .expect("stable queue result");

        assert!(result.stable);
        assert_eq!(result.extended_service_continuity.get(), 0.0);
    }
}

use crate::bounds::UnitInterval;
use crate::error::PopmathResult;
use crate::units::PopulationWeight;

/// Input for a verified aggregate service-access calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ServiceAccessInput {
    /// Aggregate weight within the declared service scope.
    pub total_weight: PopulationWeight,
    /// Aggregate weight meeting declared full-access conditions.
    pub accessible_within_threshold_weight: PopulationWeight,
}

/// Result of aggregate service-access calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ServiceAccessResult {
    /// Share of the aggregate scope meeting declared access conditions.
    pub access_index: UnitInterval,
    /// Aggregate weight not meeting stated access conditions.
    pub access_gap_weight: PopulationWeight,
}

/// Calculates a bounded aggregate access index.
pub fn calculate_service_access(
    input: ServiceAccessInput,
) -> PopmathResult<ServiceAccessResult> {
    let access_weight = input.accessible_within_threshold_weight.get();
    let total_weight = input.total_weight.get();

    let access_index = if total_weight == 0.0 {
        UnitInterval::new(0.0, "access_index")?
    } else {
        UnitInterval::new(access_weight / total_weight, "access_index")?
    };

    let access_gap_weight = PopulationWeight::new((total_weight - access_weight).max(0.0))?;

    Ok(ServiceAccessResult {
        access_index,
        access_gap_weight,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn partial_access_is_bounded() {
        let result = calculate_service_access(ServiceAccessInput {
            total_weight: PopulationWeight::new(1_000.0).expect("valid"),
            accessible_within_threshold_weight: PopulationWeight::new(750.0)
                .expect("valid"),
        })
        .expect("valid access calculation");

        assert_eq!(result.access_index.get(), 0.75);
        assert_eq!(result.access_gap_weight.get(), 250.0);
    }
}

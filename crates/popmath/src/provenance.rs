use crate::error::{PopmathError, PopmathResult};
use crate::time::TimeWindow;

/// High-level origin classification for an input.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SourceKind {
    /// A public dataset.
    PublicDataset,
    /// A public measurement or environmental observation.
    PublicMeasurement,
    /// An approved aggregate operational source.
    OperationalAggregate,
    /// A scenario generated without claims of observed behavior.
    SyntheticScenario,
    /// A derived calculation result.
    DerivedCalculation,
}

/// Data classification relevant to permitted model use.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DataClassification {
    /// Data that is public and safe to use under its declared terms.
    Public,
    /// Data aggregated for an approved analysis purpose.
    Aggregate,
    /// Data generated as a synthetic scenario.
    Synthetic,
    /// Data that needs external authorization before any use.
    Restricted,
}

/// Aggregation and scope verification state.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AggregationStatus {
    /// Aggregate method and scope are documented.
    VerifiedAggregate,
    /// Data describes infrastructure, facilities, assets, or networks.
    VerifiedInfrastructureScope,
    /// Data is synthetic.
    Synthetic,
    /// A public aggregate has sufficient source documentation.
    PublicAggregate,
    /// Scope is unknown and may only be inspected, not calculated.
    Unknown,
    /// Documentation is known to be insufficient.
    Insufficient,
    /// Data is prohibited from this analysis.
    Prohibited,
}

/// Quality declaration for an input.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DataQuality {
    /// The input has documented validation and limitations.
    Documented,
    /// The input may be used only with a review requirement.
    ReviewRequired,
    /// The input is insufficient for calculation.
    Insufficient,
}

/// Source and scope metadata required for trusted calculation.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProvenanceRecord {
    source_name: String,
    source_kind: SourceKind,
    classification: DataClassification,
    aggregation_status: AggregationStatus,
    quality: DataQuality,
    time_coverage: TimeWindow,
    geographic_scope: String,
    purpose_compatibility: String,
}

impl ProvenanceRecord {
    /// Creates a complete provenance record.
    pub fn new(
        source_name: impl Into<String>,
        source_kind: SourceKind,
        classification: DataClassification,
        aggregation_status: AggregationStatus,
        quality: DataQuality,
        time_coverage: TimeWindow,
        geographic_scope: impl Into<String>,
        purpose_compatibility: impl Into<String>,
    ) -> PopmathResult<Self> {
        let source_name = source_name.into();
        let geographic_scope = geographic_scope.into();
        let purpose_compatibility = purpose_compatibility.into();

        if source_name.trim().is_empty() {
            return Err(PopmathError::MissingProvenance {
                field: "source_name",
            });
        }
        if geographic_scope.trim().is_empty() {
            return Err(PopmathError::MissingProvenance {
                field: "geographic_scope",
            });
        }
        if purpose_compatibility.trim().is_empty() {
            return Err(PopmathError::MissingProvenance {
                field: "purpose_compatibility",
            });
        }

        Ok(Self {
            source_name,
            source_kind,
            classification,
            aggregation_status,
            quality,
            time_coverage,
            geographic_scope,
            purpose_compatibility,
        })
    }

    /// Returns the source name.
    #[must_use]
    pub fn source_name(&self) -> &str {
        &self.source_name
    }

    /// Returns the aggregation state.
    #[must_use]
    pub const fn aggregation_status(&self) -> AggregationStatus {
        self.aggregation_status
    }

    /// Returns the data quality state.
    #[must_use]
    pub const fn quality(&self) -> DataQuality {
        self.quality
    }

    /// Returns whether the source can enter calculation.
    pub fn authorize_calculation(&self) -> PopmathResult<()> {
        match self.aggregation_status {
            AggregationStatus::VerifiedAggregate
            | AggregationStatus::VerifiedInfrastructureScope
            | AggregationStatus::Synthetic
            | AggregationStatus::PublicAggregate => {}
            AggregationStatus::Unknown => return Err(PopmathError::QuarantinedAggregation),
            AggregationStatus::Insufficient => {
                return Err(PopmathError::InsufficientAggregation);
            }
            AggregationStatus::Prohibited => {
                return Err(PopmathError::DataUseNotAuthorizedForDeclaredPurpose);
            }
        }

        if self.quality == DataQuality::Insufficient {
            return Err(PopmathError::InsufficientAggregation);
        }

        Ok(())
    }

    /// Returns the declared time coverage.
    #[must_use]
    pub const fn time_coverage(&self) -> TimeWindow {
        self.time_coverage
    }

    /// Returns the geographic scope.
    #[must_use]
    pub fn geographic_scope(&self) -> &str {
        &self.geographic_scope
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::time::UtcTimestamp;

    fn coverage() -> TimeWindow {
        TimeWindow::new(
            UtcTimestamp::from_unix_seconds(0),
            UtcTimestamp::from_unix_seconds(3_600),
        )
        .expect("valid time window")
    }

    #[test]
    fn unknown_aggregation_is_quarantined() {
        let record = ProvenanceRecord::new(
            "legacy source",
            SourceKind::PublicDataset,
            DataClassification::Restricted,
            AggregationStatus::Unknown,
            DataQuality::ReviewRequired,
            coverage(),
            "service area",
            "research inspection",
        )
        .expect("valid metadata");

        assert_eq!(
            record.authorize_calculation(),
            Err(PopmathError::QuarantinedAggregation)
        );
    }

    #[test]
    fn public_aggregate_is_calculation_ready() {
        let record = ProvenanceRecord::new(
            "municipal aggregate",
            SourceKind::PublicDataset,
            DataClassification::Public,
            AggregationStatus::PublicAggregate,
            DataQuality::Documented,
            coverage(),
            "citywide",
            "water resilience scenario",
        )
        .expect("valid metadata");

        assert_eq!(record.authorize_calculation(), Ok(()));
    }
}

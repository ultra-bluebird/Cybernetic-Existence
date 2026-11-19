use popmath::prelude::*;

fn provenance() -> ProvenanceRecord {
    let window = TimeWindow::new(
        UtcTimestamp::from_unix_seconds(1_700_000_000),
        UtcTimestamp::from_unix_seconds(1_700_003_600),
    )
    .expect("valid time window");

    ProvenanceRecord::new(
        "synthetic municipal planning fixture",
        SourceKind::SyntheticScenario,
        DataClassification::Synthetic,
        AggregationStatus::Synthetic,
        DataQuality::Documented,
        window,
        "citywide service area",
        "deterministic public-interest planning test",
    )
    .expect("valid provenance")
}

fn scenario() -> Scenario {
    let window = TimeWindow::new(
        UtcTimestamp::from_unix_seconds(1_700_000_000),
        UtcTimestamp::from_unix_seconds(1_700_003_600),
    )
    .expect("valid time window");

    let purpose = Purpose::new(
        PurposeCategory::WaterResilience,
        "Evaluate a synthetic aggregate water-storage scenario.",
    )
    .expect("valid purpose");

    let policy = DataUsePolicy::aggregate_public_interest(
        PermittedUse::AggregateScenarioComparison,
        DecisionBoundary::AnalysisOnly,
        ReviewRequirement::Technical,
    );

    Scenario::new(
        "synthetic-water-balance",
        "A reproducible aggregate scenario used for integration testing.",
        purpose,
        window,
        provenance(),
        policy,
        vec![Assumption::new("interval", "one hour").expect("valid assumption")],
        vec![Constraint::new(
            "storage bound",
            ConstraintKind::Hard,
            "Storage remains between zero and physical capacity.",
        )
        .expect("valid constraint")],
    )
    .expect("valid scenario")
}

#[test]
fn foundation_calculation_builds_reviewable_result() {
    let result = calculate_water_balance(WaterBalanceInput {
        starting_storage: VolumeM3::new(100.0).expect("valid"),
        inflow: VolumeM3::new(10.0).expect("valid"),
        demand: VolumeM3::new(90.0).expect("valid"),
        losses: VolumeM3::new(5.0).expect("valid"),
        evaporation: VolumeM3::new(2.0).expect("valid"),
        recovered_supply: VolumeM3::new(0.0).expect("valid"),
        maximum_storage: VolumeM3::new(200.0).expect("valid"),
    })
    .expect("valid water balance");

    let metrics = ResultMetrics::new(
        UnitInterval::new(0.90, "knowledge_factor").expect("valid"),
        UnitInterval::new(0.82, "eco_impact_value").expect("valid"),
        UnitInterval::new(0.08, "harm_risk").expect("valid"),
        UnitInterval::new(0.96, "accessibility_impact").expect("valid"),
        UnitInterval::new(0.97, "rights_alignment").expect("valid"),
    );

    let envelope = build_result_envelope(
        "water.balance",
        &scenario(),
        result,
        ValidationStatus::Validated,
        metrics,
        "The calculation is aggregate and does not require person-level service data.",
        "The result is analysis only and requires technical review before interpretation.",
        "The model accounts for storage, inflow, demand, losses, evaporation, and recovery.",
        Vec::new(),
        vec!["This fixture is synthetic and does not represent an observed municipal system."
            .to_owned()],
        "synthetic fixture v1",
    );

    assert_eq!(envelope.value().ending_storage.get(), 13.0);
    assert_eq!(envelope.validation_status(), ValidationStatus::Validated);
    assert_eq!(envelope.metrics().rights_alignment().get(), 0.97);
    assert!(!envelope.reproducibility_digest().as_str().is_empty());
}

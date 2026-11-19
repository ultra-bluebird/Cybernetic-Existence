use popmath::bounds::UnitInterval;
use popmath::social::{calculate_social_acceptance, SocialAcceptanceInput};

fn ratio(value: f64) -> UnitInterval {
    UnitInterval::new(value).expect("test ratio must be inside the unit interval")
}

fn valid_input() -> SocialAcceptanceInput {
    SocialAcceptanceInput {
        inclusive_policy_coverage: ratio(0.90),
        inclusive_infrastructure_coverage: ratio(0.85),
        voluntary_participation_coverage: ratio(0.80),
        accessible_remedy_coverage: ratio(0.95),
        policy_weight: ratio(0.25),
        infrastructure_weight: ratio(0.35),
        participation_weight: ratio(0.15),
        remedy_weight: ratio(0.25),
        minimum_policy_coverage: ratio(0.80),
        minimum_infrastructure_coverage: ratio(0.80),
        minimum_remedy_coverage: ratio(0.80),
    }
}

#[test]
fn calculates_social_acceptance_when_foundations_are_met() {
    let result = calculate_social_acceptance(valid_input()).expect("valid calculation");

    let expected = 0.90 * 0.25 + 0.85 * 0.35 + 0.80 * 0.15 + 0.95 * 0.25;

    assert!(result.floor_conditions_met);
    assert!((result.social_acceptance_factor.value() - expected).abs() < 1.0e-12);
    assert!((result.components.weighted_score.value() - expected).abs() < 1.0e-12);
}

#[test]
fn reports_weighted_components_for_explanation_interfaces() {
    let result = calculate_social_acceptance(valid_input()).expect("valid calculation");

    assert!((result.components.policy_component.value() - 0.225).abs() < 1.0e-12);
    assert!((result.components.infrastructure_component.value() - 0.2975).abs() < 1.0e-12);
    assert!((result.components.participation_component.value() - 0.12).abs() < 1.0e-12);
    assert!((result.components.remedy_component.value() - 0.2375).abs() < 1.0e-12);
}

#[test]
fn returns_zero_when_policy_floor_is_not_met() {
    let mut input = valid_input();
    input.inclusive_policy_coverage = ratio(0.79);

    let result = calculate_social_acceptance(input).expect("calculation");

    assert!(!result.floor_conditions_met);
    assert_eq!(result.social_acceptance_factor.value(), 0.0);
    assert!(result.components.weighted_score.value() > 0.0);
}

#[test]
fn returns_zero_when_infrastructure_floor_is_not_met() {
    let mut input = valid_input();
    input.inclusive_infrastructure_coverage = ratio(0.79);

    let result = calculate_social_acceptance(input).expect("calculation");

    assert!(!result.floor_conditions_met);
    assert_eq!(result.social_acceptance_factor.value(), 0.0);
}

#[test]
fn returns_zero_when_remedy_floor_is_not_met() {
    let mut input = valid_input();
    input.accessible_remedy_coverage = ratio(0.79);

    let result = calculate_social_acceptance(input).expect("calculation");

    assert!(!result.floor_conditions_met);
    assert_eq!(result.social_acceptance_factor.value(), 0.0);
}

#[test]
fn rejects_weights_that_do_not_sum_to_one() {
    let mut input = valid_input();
    input.remedy_weight = ratio(0.20);

    assert!(calculate_social_acceptance(input).is_err());
}

#[test]
fn accepts_weights_within_declared_numerical_tolerance() {
    let mut input = valid_input();
    input.policy_weight = ratio(0.2500000000001);
    input.remedy_weight = ratio(0.2499999999999);

    let result = calculate_social_acceptance(input);

    assert!(result.is_ok());
}

use msfp_gateway::enclosure::{
    evaluate_enclosure, EnclosureDecision, EnclosureLimits, EnclosureMeasurement,
};

fn limits() -> EnclosureLimits {
    EnclosureLimits {
        max_surface_temperature_c: 55.0,
        max_component_temperature_c: 85.0,
        max_temperature_rise_rate_c_per_s: 2.0,
        max_rail_deviation_v: 0.25,
    }
}

#[test]
fn rail_integrity_failure_removes_external_authority() {
    let decision = evaluate_enclosure(
        EnclosureMeasurement {
            ambient_temperature_c: 25.0,
            surface_temperature_c: 35.0,
            component_temperature_c: 50.0,
            temperature_rise_rate_c_per_s: 0.1,
            rail_deviation_v: 0.30,
            emc_integrity_passed: true,
        },
        limits(),
    );

    assert_eq!(decision, EnclosureDecision::AuthorityOff);
}

#[test]
fn surface_temperature_can_request_safe_derating() {
    let decision = evaluate_enclosure(
        EnclosureMeasurement {
            ambient_temperature_c: 25.0,
            surface_temperature_c: 60.0,
            component_temperature_c: 70.0,
            temperature_rise_rate_c_per_s: 0.5,
            rail_deviation_v: 0.05,
            emc_integrity_passed: true,
        },
        limits(),
    );

    assert_eq!(decision, EnclosureDecision::SafeDegraded);
}

#[test]
fn normal_measurement_continues_session_processing() {
    let decision = evaluate_enclosure(
        EnclosureMeasurement {
            ambient_temperature_c: 25.0,
            surface_temperature_c: 35.0,
            component_temperature_c: 50.0,
            temperature_rise_rate_c_per_s: 0.1,
            rail_deviation_v: 0.05,
            emc_integrity_passed: true,
        },
        limits(),
    );

    assert_eq!(decision, EnclosureDecision::Continue);
}

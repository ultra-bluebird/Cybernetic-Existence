// crates/swarm-intelligence/tests/kani_policy.rs

use swarm_intelligence::state::SwarmContext;
use swarm_intelligence::policy::{AfmGradientPolicy, SwarmPolicy};
use nanoswarm_telemetry::row::TelemetryRow;
use afm_control::hardware::afm::AfmHeightSample;

#[kani::proof]
fn afm_gradient_policy_produces_commands() {
    let host_did = "OrganicCPU".to_string();
    let bostrom_address = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string();

    let mut ctx = SwarmContext::new(host_did, bostrom_address, "swarm-1".to_string());

    let sample = AfmHeightSample {
        x_nm: 1.0,
        y_nm: 2.0,
        z_nm: 3.0,
        timestamp_ns: 123,
    };

    let row = TelemetryRow::new(
        "OrganicCPU".to_string(),
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
        123,
        "robot-1".to_string(),
        7.4,
        37.0,
        1.0,
        "survey".to_string(),
        Some(sample),
        None,
        None,
        None,
    );

    ctx.ingest(vec![row]);

    let mut policy = AfmGradientPolicy::default();
    let commands = policy.compute_commands(&ctx);

    assert!(!commands.is_empty());
    assert_eq!(commands[0].robot_id, "robot-1");
    assert_eq!(commands[0].new_mode, "dock");
    assert!(commands[0].target_position_nm.is_some());
}

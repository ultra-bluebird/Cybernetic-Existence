// crates/nanorobotics-host-loop/src/host_loop.rs

use std::fs::File;
use std::io::Read;

use serde::{Deserialize, Serialize};
use anyhow::{anyhow, Result};

use afm_control::hardware::dummy_impl::{DummyAfm, DummyStage};
use afm_control::hardware::afm::{AfmController, AfmScanParams, AfmMode};
use afm_control::hardware::motion_stage::{AxisConfig, MotionStage, MotionTarget};

use swarm_intelligence::policy::RobotCommand;
use crate::roh::{evaluate_metrics, metrics_ok, HostMetrics};
use crate::governance::{CYBERCORE_AUTHORITY_MIGRATION, default_host_loop_mode, default_host_compliance};

/// Command envelope structure as produced by swarm-intelligence/examples/afm_dna_swarm.rs.
#[derive(Debug, Deserialize)]
struct CommandEnvelope {
    host_did: String,
    bostrom_address: String,
    swarm_governance_mode: String,
    swarm_compliance: String,
    authority: String,
    commands: Vec<RobotCommand>,
}

/// Host-loop report for logging/telemetry, fully serializable and Cybercore-ready.
#[derive(Debug, Serialize)]
pub struct HostLoopReport {
    pub host_did: String,
    pub bostrom_address: String,
    pub host_loop_mode: String,
    pub host_compliance: String,
    pub authority: String,
    pub metrics: HostMetrics,
    pub executed_commands: Vec<RobotCommand>,
}

/// Execute a single-cycle host loop: read commands, check metrics, and drive hardware.
pub fn run_once_from_file(path: &str) -> Result<HostLoopReport> {
    // 1. Load command envelope JSON.
    let mut file = File::open(path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;

    let envelope: CommandEnvelope = serde_json::from_str(&contents)?;
    if envelope.authority != CYBERCORE_AUTHORITY_MIGRATION {
        return Err(anyhow!("invalid authority marker in command envelope"));
    }

    // 2. Evaluate RoH/capability metrics for commands.
    let metrics = evaluate_metrics(&envelope.commands);
    if !metrics_ok(&metrics) {
        return Err(anyhow!("command envelope does not satisfy RoH/capability constraints"));
    }

    // 3. Initialize host-local AFM and motion hardware.
    let mut stage = DummyStage::default();
    let axis_cfg = AxisConfig {
        id: 1,
        max_velocity_mm_s: 1.0,
        max_acc_mm_s2: 1.0,
    };
    stage.configure_axis(axis_cfg)?;

    let mut afm = DummyAfm::default();
    let scan_params = AfmScanParams {
        mode: AfmMode::Contact,
        size_nm: 500.0,
        resolution_px: 64,
        line_rate_hz: 1.0,
        setpoint_n: 1e-9,
    };
    afm.configure_scan(scan_params)?;
    afm.start_scan()?;

    // 4. Execute commands: update motion targets and optionally adjust modes.
    let mut executed = Vec::new();

    for cmd in &envelope.commands {
        if let Some((x_nm, y_nm, _z_nm)) = cmd.target_position_nm {
            // Convert nanoscale target to mm-scale movement (example scaling),
            // consistent with AFM nanopositioners and closed-loop controllers.[web:101][web:102][web:103][web:107][web:109]
            let target_mm = MotionTarget {
                axis_id: 1,
                position_mm: (x_nm / 1_000_000.0).abs(), // nm -> mm
                velocity_mm_s: 0.01,
            };
            stage.move_to(target_mm)?;
        }

        // In a full system, AFM scan parameters or feedback gains could be adjusted based on new_mode,
        // similar to how AFM controllers tune PLL/PID loops in different modes.[web:102][web:104][web:107]

        executed.push(cmd.clone());
    }

    // 5. Build host-loop report.
    let report = HostLoopReport {
        host_did: envelope.host_did,
        bostrom_address: envelope.bostrom_address,
        host_loop_mode: default_host_loop_mode().to_string(),
        host_compliance: default_host_compliance().to_string(),
        authority: CYBERCORE_AUTHORITY_MIGRATION.to_string(),
        metrics,
        executed_commands: executed,
    };

    Ok(report)
}

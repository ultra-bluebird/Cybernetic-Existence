// crates/swarm-intelligence/examples/afm_dna_swarm.rs

use std::fs::File;
use std::io::Read;

use nanoswarm_telemetry::table::TelemetryTable;
use swarm_intelligence::state::SwarmContext;
use swarm_intelligence::policy::{AfmGradientPolicy, DnaStructurePolicy, SwarmPolicy, RobotCommand};
use swarm_intelligence::governance::{
    CYBERCORE_AUTHORITY_MIGRATION,
    default_swarm_governance_mode,
    default_swarm_compliance,
};

fn main() -> anyhow::Result<()> {
    // 1. Load telemetry envelope JSON produced by afm_dna_loop.
    // In a real deployment, this would be written by crates/nanoswarm-telemetry/examples/afm_dna_loop.rs,
    // or streamed via Cybercore/Data_Lake.[web:71][web:72][web:73][web:94]
    let mut file = File::open("afm_dna_envelope.json")?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;

    // 2. Decode the envelope and extract the TelemetryTable.
    #[derive(Debug, serde::Deserialize)]
    struct GovernedEnvelope {
        host_did: String,
        bostrom_address: String,
        cybermode: String,
        nanoswarm_compliance: String,
        authority: String,
        telemetry: TelemetryTable,
    }

    let envelope: GovernedEnvelope = serde_json::from_str(&contents)?;
    assert_eq!(envelope.authority, CYBERCORE_AUTHORITY_MIGRATION);

    // 3. Construct a SwarmContext from the telemetry.
    let mut ctx = SwarmContext::new(
        envelope.host_did.clone(),
        envelope.bostrom_address.clone(),
        "swarm-afm-dna-1".to_string(),
    );
    ctx.ingest(envelope.telemetry.rows);

    // 4. Run AfmGradientPolicy and DnaStructurePolicy.
    let mut afm_policy = AfmGradientPolicy::default();
    let mut dna_policy = DnaStructurePolicy::default();

    let afm_commands = afm_policy.compute_commands(&ctx);
    let dna_commands = dna_policy.compute_commands(&ctx);

    // 5. Merge commands per robot (simple override: DNA-structure-aware commands win if present).
    let merged_commands = merge_commands(afm_commands, dna_commands);

    // 6. Build a governed command envelope tagged with Cybercore authority and swarm compliance.
    #[derive(Debug, serde::Serialize)]
    struct CommandEnvelope {
        host_did: String,
        bostrom_address: String,
        swarm_governance_mode: String,
        swarm_compliance: String,
        authority: String,
        commands: Vec<RobotCommand>,
    }

    let command_envelope = CommandEnvelope {
        host_did: envelope.host_did,
        bostrom_address: envelope.bostrom_address,
        swarm_governance_mode: default_swarm_governance_mode().to_string(),
        swarm_compliance: default_swarm_compliance().to_string(),
        authority: CYBERCORE_AUTHORITY_MIGRATION.to_string(),
        commands: merged_commands,
    };

    let json = serde_json::to_string_pretty(&command_envelope)?;
    println!("Swarm command envelope:\n{}", json);

    Ok(())
}

/// Merge AFM and DNA commands: DNA-structure-aware commands override AFM-only ones per robot.
fn merge_commands(afm_commands: Vec<RobotCommand>, dna_commands: Vec<RobotCommand>) -> Vec<RobotCommand> {
    use std::collections::HashMap;

    let mut merged: HashMap<String, RobotCommand> = HashMap::new();

    for cmd in afm_commands {
        merged.insert(cmd.robot_id.clone(), cmd);
    }

    for cmd in dna_commands {
        merged.insert(cmd.robot_id.clone(), cmd);
    }

    merged.into_values().collect()
}

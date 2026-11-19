// crates/nanorobotics-host-loop/examples/run_host_loop.rs

use nanorobotics_host_loop::host_loop::run_once_from_file;

fn main() -> anyhow::Result<()> {
    // Path to command envelope JSON produced by swarm-intelligence/examples/afm_dna_swarm.rs.
    let report = run_once_from_file("swarm_commands.json")?;

    let json = serde_json::to_string_pretty(&report)?;
    println!("Host loop report:\n{}", json);

    Ok(())
}

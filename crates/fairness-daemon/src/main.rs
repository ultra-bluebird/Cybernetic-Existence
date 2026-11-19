mod monitor;

use clap::Parser;
use tracing::info;

#[derive(Parser, Debug)]
struct Args {
    #[arg(short, long, default_value = "./contracts/fairness.rego")]
    config: String,
}

fn main() -> anyhow::Result<()> {
    let _ = tracing_subscriber::fmt::try_init();
    let args = Args::parse();

    info!("Loading fairness policy from: {}", args.config);
    // Load policy (in production, this uses the rego rust bindings or evaluates via HTTP)
    // For this pre-wire, we simply pass the path to the monitor.
    monitor::start_monitor(&args.config)?;

    Ok(())
}

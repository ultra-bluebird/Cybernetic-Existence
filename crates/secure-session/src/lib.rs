pub mod cookie_jar;
pub mod session_manager;
pub mod sanitizer;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[arg(long, conflicts_with = "daemon")]
    pub perplexity: bool,

    #[arg(long)]
    pub force: bool,

    #[arg(long)]
    pub verbose: bool,

    #[arg(long)]
    pub daemon: bool,

    #[arg(long)]
    pub config: Option<String>,
}

pub fn run_cli(cli: Cli) -> anyhow::Result<()> {
    if cli.daemon {
        return sanitizer::start_daemon();
    }
    if cli.perplexity {
        return session_manager::force_perplexity_refresh(cli.force, cli.verbose);
    }
    tracing::info!("No command specified. Use --help for options.");
    Ok(())
}

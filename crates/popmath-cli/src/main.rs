#![forbid(unsafe_code)]

use std::env;
use std::fs;
use std::path::Path;

use popmath_cli::{
    build_result_envelope, parse_run_arguments, parse_scenario, serialize_result_envelope,
    CliError,
};

fn main() {
    if let Err(error) = run() {
        eprintln!("popmath-cli: {error}");
        std::process::exit(2);
    }
}

fn run() -> Result<(), CliError> {
    let arguments = env::args().skip(1).collect::<Vec<_>>();

    if arguments.len() == 1 && arguments[0] == "--help" {
        print_help();
        return Ok(());
    }

    if arguments.len() == 1 && arguments[0] == "--version" {
        println!("popmath-cli {}", popmath_cli::CLI_CRATE_VERSION);
        return Ok(());
    }

    let arguments = parse_run_arguments(&arguments)?;
    let scenario_source = read_utf8_file(&arguments.scenario_path, "scenario")?;
    let scenario = parse_scenario(&scenario_source)?;
    let result = build_result_envelope(scenario);
    let serialized = serialize_result_envelope(&result)?;

    if let Some(parent) = arguments.output_path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|error| {
                CliError::Serialization(format!(
                    "unable to create output directory '{}': {error}",
                    parent.display()
                ))
            })?;
        }
    }

    fs::write(&arguments.output_path, serialized).map_err(|error| {
        CliError::Serialization(format!(
            "unable to write result output '{}': {error}",
            arguments.output_path.display()
        ))
    })?;

    Ok(())
}

fn read_utf8_file(path: &Path, label: &str) -> Result<String, CliError> {
    fs::read_to_string(path).map_err(|error| {
        CliError::ScenarioSyntax(format!(
            "unable to read {label} file '{}': {error}",
            path.display()
        ))
    })
}

fn print_help() {
    println!(
        "\
Population.Math local scenario runner

Usage:
  popmath-cli run --scenario <scenario.json> --output <result.json>
  popmath-cli --help
  popmath-cli --version

The command validates a local scenario JSON document and writes a deterministic
advisory ResultEnvelope JSON artifact to the requested output path."
    );
}

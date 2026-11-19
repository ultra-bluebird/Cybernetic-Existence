// File: crates/nanoswarm-bio/src/bin/nanoswarm-bio-json-debug.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/bin/nanoswarm-bio-json-debug.rs

#![forbid(unsafe_code)]

use std::env;
use std::fs;

use nanoswarm_bio::{BiocompatibilityProfile, NanoswarmStateVector};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Input {
    state: NanoswarmStateVector,
    profile: BiocompatibilityProfile,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Output {
    roh_with_biocompat: Option<f32>,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: nanoswarm-bio-json-debug <input.json>");
        std::process::exit(1);
    }

    let path = &args[1];
    let data = fs::read_to_string(path).expect("failed to read JSON file");
    let input: Input = serde_json::from_str(&data).expect("invalid nanoswarm-bio Input JSON");

    let roh = nanoswarm_bio::roh_with_biocompat(&input.state, &input.profile);
    let out = Output { roh_with_biocompat: roh };

    let json = serde_json::to_string_pretty(&out).expect("failed to serialize Output");
    println!("{json}");
}

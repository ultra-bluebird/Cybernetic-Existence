#![forbid(unsafe_code)]
#![feature(rust_2024_preview)]

use std::fs::File;
use std::io::{self, Read};
use std::path::PathBuf;

use sacrifice_zone_envelope::{
    summarize_zone_model,
    SacrificeZoneModel,
};

fn main() -> io::Result<()> {
    let mut args = std::env::args().skip(1);
    let path = match args.next() {
        Some(p) => PathBuf::from(p),
        None => {
            eprintln!("usage: sacrifice-zone-envelope-cli <zone-model.json>");
            std::process::exit(1);
        }
    };

    let mut buf = String::new();
    File::open(&path)?.read_to_string(&mut buf)?;

    let model: SacrificeZoneModel = serde_json::from_str(&buf).map_err(|e| {
        eprintln!("failed to parse SacrificeZoneModel: {e}");
        io::Error::new(io::ErrorKind::InvalidData, "invalid JSON")
    })?;

    match summarize_zone_model(&model) {
        Ok(summary) => {
            println!("{summary}");
            Ok(())
        }
        Err(err) => {
            eprintln!("invalid Sacrifice Zone model: {err}");
            std::process::exit(2);
        }
    }
}

#![forbid(unsafe_code)]

use crypto_agility::{
    CipherSuiteRegistry, CryptoOperation, NegotiationRequest,
};
use std::env;
use std::fs;
use std::process::ExitCode;

fn main() -> ExitCode {
    match run() {
        Ok(message) => {
            println!("{message}");
            ExitCode::SUCCESS
        }
        Err(message) => {
            eprintln!("crypto-agility error: {message}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<String, String> {
    let arguments = env::args().skip(1).collect::<Vec<_>>();

    match arguments.as_slice() {
        [command, registry_path] if command == "validate" => {
            let registry = load_registry(registry_path)?;
            registry.validate().map_err(|error| error.to_string())?;

            Ok(format!(
                "registry_valid=true\npolicy_version={}\npolicy_epoch={}\nsuite_count={}",
                registry.policy_version,
                registry.policy_epoch,
                registry.suites.len()
            ))
        }
        [
            command,
            registry_path,
            peer_suite_ids,
            current_epoch,
            last_accepted_policy_epoch,
            operation,
        ] if command == "select" => {
            let registry = load_registry(registry_path)?;
            let peer_supported_suite_ids = parse_peer_suite_ids(peer_suite_ids)?;
            let current_epoch = parse_u64("current_epoch", current_epoch)?;
            let last_accepted_policy_epoch =
                parse_u64("last_accepted_policy_epoch", last_accepted_policy_epoch)?;
            let operation = parse_operation(operation)?;

            let result = registry
                .select_suite(&NegotiationRequest {
                    peer_supported_suite_ids: &peer_supported_suite_ids,
                    current_epoch,
                    last_accepted_policy_epoch,
                    required_minimum_security_rank: registry.minimum_security_rank,
                    required_minimum_protocol_version: registry.minimum_protocol_version,
                    operation,
                })
                .map_err(|error| error.to_string())?;

            Ok(format!(
                "selected_suite_id={}\nselected_protocol_version={}\nselected_security_rank={}\nselected_policy_epoch={}\noperation={}",
                result.suite.suite_id,
                result.suite.protocol_version,
                result.suite.security_rank,
                result.selected_policy_epoch,
                operation_name(result.operation)
            ))
        }
        _ => Err(usage()),
    }
}

fn load_registry(path: &str) -> Result<CipherSuiteRegistry, String> {
    let source = fs::read_to_string(path)
        .map_err(|error| format!("unable to read registry file: {error}"))?;

    serde_json::from_str(&source)
        .map_err(|error| format!("registry is not valid JSON: {error}"))
}

fn parse_peer_suite_ids(value: &str) -> Result<Vec<String>, String> {
    let suite_ids = value
        .split(',')
        .map(str::trim)
        .filter(|suite_id| !suite_id.is_empty())
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>();

    if suite_ids.is_empty() {
        return Err("peer_suite_ids must contain at least one suite identifier".to_owned());
    }

    Ok(suite_ids)
}

fn parse_u64(name: &str, value: &str) -> Result<u64, String> {
    value
        .parse::<u64>()
        .map_err(|_| format!("{name} must be an unsigned integer"))
}

fn parse_operation(value: &str) -> Result<CryptoOperation, String> {
    match value {
        "encrypt" => Ok(CryptoOperation::EncryptNewData),
        "decrypt" => Ok(CryptoOperation::DecryptExistingData),
        _ => Err("operation must be either encrypt or decrypt".to_owned()),
    }
}

fn operation_name(operation: CryptoOperation) -> &'static str {
    match operation {
        CryptoOperation::EncryptNewData => "encrypt",
        CryptoOperation::DecryptExistingData => "decrypt",
    }
}

fn usage() -> String {
    [
        "Usage:",
        "  crypto-agility validate <registry.json>",
        "  crypto-agility select <registry.json> <peer_suite_ids_csv> <current_epoch> <last_accepted_policy_epoch> <encrypt|decrypt>",
    ]
    .join("\n")
}

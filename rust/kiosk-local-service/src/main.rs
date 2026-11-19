use kiosk_local_service::LocalServiceCatalog;
use std::env;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
Usage:
  kiosk-local-service search <database-path> <query>
  kiosk-local-service list <database-path> <category>

Examples:
  kiosk-local-service search var/kiosk/content/service-catalog.sqlite \"drinking water\"
  kiosk-local-service list var/kiosk/content/service-catalog.sqlite cooling

The command reads only a local SQLite service catalog.
It does not connect to a network and does not write user interaction data.
";

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut arguments = env::args_os();
    let executable = arguments.next();

    let command = arguments
        .next()
        .ok_or_else(|| format!("{USAGE}\nMissing command."))?;

    let database_path = arguments
        .next()
        .map(PathBuf::from)
        .ok_or_else(|| format!("{USAGE}\nMissing database path."))?;

    let catalog = LocalServiceCatalog::open_read_only(&database_path)
        .map_err(|error| format!("Could not open the local service catalog: {error}"))?;

    match command.to_string_lossy().as_ref() {
        "search" => {
            let query = arguments
                .next()
                .ok_or_else(|| format!("{USAGE}\nMissing search query."))?
                .to_string_lossy()
                .into_owned();

            if arguments.next().is_some() {
                return Err(format!("{USAGE}\nSearch accepts exactly one query argument."));
            }

            let results = catalog
                .search(&query)
                .map_err(|error| format!("Search failed: {error}"))?;

            print_results(&results);
            Ok(())
        }
        "list" => {
            let category = arguments
                .next()
                .ok_or_else(|| format!("{USAGE}\nMissing service category."))?
                .to_string_lossy()
                .into_owned();

            if arguments.next().is_some() {
                return Err(format!("{USAGE}\nList accepts exactly one category argument."));
            }

            let results = catalog
                .list_category(&category)
                .map_err(|error| format!("Category listing failed: {error}"))?;

            print_results(&results);
            Ok(())
        }
        _ => {
            let program = executable
                .as_deref()
                .map(|value| value.to_string_lossy())
                .unwrap_or_else(|| "kiosk-local-service".into());

            Err(format!(
                "{USAGE}\nUnsupported command. Run `{program} search` or `{program} list`."
            ))
        }
    }
}

fn print_results(results: &[kiosk_local_service::ServiceResult]) {
    if results.is_empty() {
        println!("No locally verified services matched this request.");
        println!("Try browsing a category or using different words.");
        return;
    }

    for service in results {
        println!("{}", service.name);
        println!("Category: {}", service.category);
        println!("Address: {}", service.address);

        if let Some(cross_street) = &service.cross_street {
            println!("Cross street: {cross_street}");
        }

        println!("Hours: {}", service.hours_text);
        println!("Accessibility: {}", service.access_notes);
        println!("Last verified: {}", service.verified_at);
        println!("Source: {}", service.source_name);

        if let Some(phone) = &service.phone_public {
            println!("Public phone: {phone}");
        }

        if let Some(url) = &service.url_public {
            println!("Public website: {url}");
        }

        println!("Package version: {}", service.package_version);
        println!();
    }
}

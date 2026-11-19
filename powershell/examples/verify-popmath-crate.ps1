$repositoryRoot = (Resolve-Path "$PSScriptRoot/../..").Path

Push-Location $repositoryRoot

try {
    cargo fmt --check -p popmath
    cargo test -p popmath
    cargo clippy -p popmath --all-targets --all-features -- -D warnings
    cargo check -p popmath --no-default-features
}
finally {
    Pop-Location
}

# Population.Math Git Hooks

The repository hook validates staged JSON scenario files under `scenarios/` and `examples/` before a commit is created.

## Requirements

- Git
- PowerShell 7.2 or later available as `pwsh`
- `schemas/popmath-scenario.schema.json`

## Enable repository hooks

Run this command from the repository root:

```powershell
git config core.hooksPath scripts/git-hooks
```

Verify the configured hook directory:

```powershell
git config --get core.hooksPath
```

## Validate staged scenarios

Stage one or more scenario files and commit normally:

```powershell
git add scenarios examples
git commit -m "Add deterministic continuity scenarios"
```

The hook reads the staged Git content rather than the working-tree copy. This ensures its validation matches the exact JSON that Git would commit.

## Disable the repository hook path

```powershell
git config --unset core.hooksPath
```

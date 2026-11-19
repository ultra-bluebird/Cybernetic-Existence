# CyberMind: Execute the Existing Synthetic Validation Runner

## Goal

Finish the verification step for the existing:

cybermind/run_synthetic_validation.lua

Do not create another runner, redesign the schemas, or expand the research scope.

The reported Lua installation is:

/usr/local/bin/lua5.4

Treat that path and version as reported information until verified by an actual
command in this session.

## Restrictions

- Do not run cargo commands.
- Do not use Rust.
- Do not install tools, packages, test frameworks, or dependencies.
- Do not rebuild or reinstall Lua unless the reported installation is genuinely
  absent or unusable.
- If replacement is necessary, Lua 5.4.7 or later is the only permitted runtime
  installation.
- Use existing Shell, Python, Lua, Matlab, or C++ tooling.
- Do not search GitHub, clone repositories, or inspect unrelated files.
- Do not modify project research documents or unrelated materials.
- Do not commit, push, publish, or access live systems.

Work from the authorized local checkout containing cybermind/.

## Qwen3-Coder Service Warning

Use one active coding request at a time.

If the service reports:

"Oops! There was an issue connecting to Qwen3-Coder.
Too many concurrent requests."

Do not start parallel agents or rapid retries.

Wait for outstanding requests. Respect Retry-After if available; otherwise use
bounded increasing delays. After three unsuccessful retries, preserve the
current state and report the service blocker.

Do not confuse coding-service quota failure with a Lua test failure.

## Step 1: Verify Only the Necessary Paths

Check:

- /usr/local/bin/lua5.4
- cybermind/run_synthetic_validation.lua
- cybermind/validation/synthetic-validation-report.json

Do not perform recursive discovery.

If the report already exists, preserve it. Inspect the runner's existing output
handling before running anything that might overwrite evidence.

## Step 2: Verify the Runtime and Syntax

Run from the checkout root:

```sh
LUA=/usr/local/bin/lua5.4

if [ ! -x "$LUA" ]; then
    printf '%s\n' "BLOCKED: reported Lua executable is unavailable."
    exit 2
fi

if [ ! -f cybermind/run_synthetic_validation.lua ]; then
    printf '%s\n' "BLOCKED: target runner is missing."
    exit 2
fi

"$LUA" -v

"$LUA" -e '
local chunk, message = loadfile("cybermind/run_synthetic_validation.lua", "t")
if not chunk then
    io.stderr:write(tostring(message), "\n")
    os.exit(3)
end
io.stdout:write("Runner syntax check passed; runner not executed by this check.\n")
'
```

Check the actual version output. Confirm Lua 5.4.7 or later.

If syntax fails:

- Inspect only the indicated area of the runner.
- Make the smallest correction.
- Repeat the syntax check.
- Do not weaken tests or edit libraries merely to hide the runner failure.

A syntax pass is not a self-test pass.

## Step 3: Execute the Runner

If the syntax check passed and existing output will not be overwritten:

```sh
LUA=/usr/local/bin/lua5.4

if "$LUA" cybermind/run_synthetic_validation.lua; then
    runner_status=0
else
    runner_status=$?
fi

printf 'Runner process exit status: %s\n' "$runner_status"

case "$runner_status" in
    0)
        printf '%s\n' "Runner reports completion; verify report contents."
        ;;
    1)
        printf '%s\n' "Inspect reported test failures and stderr."
        ;;
    2)
        printf '%s\n' "Inspect missing modules, runtime requirements, or interfaces."
        ;;
    3)
        printf '%s\n' "Inspect runner infrastructure, input, or serialization errors."
        ;;
    *)
        printf '%s\n' "Unexpected exit status; retain output and investigate."
        ;;
esac
```

An exit status of 1 from an unhandled runtime error is not automatically a
well-classified test failure. Check the output before interpreting the number.

Do not repeatedly rerun an unchanged failing command.

## Step 4: Fix Demonstrated Blockers Only

Likely areas requiring narrow inspection include:

- Placeholder text left in executable code.
- Misspelled variables in JSON serialization or report writing.
- Incorrect module search-path construction.
- A returned error treated as a successful result.
- A missing output directory.
- Unsupported assumptions about module exports.

Inspect the relevant lines only.

If a target dependency is missing:

- Record its exact expected relative path.
- Mark dependent checks not executed.
- Continue independent checks if the runner supports doing so.
- Do not search the full repository for substitutes.
- Do not reconstruct an entire missing module during this session.

If the runner starts and tests fail, it should preserve a failure report where
its existing design permits. A JSON report should not be reserved only for
successful tests.

Do not fabricate a report after a syntax failure that suggests tests ran.

## Step 5: Verify the Expected CyberCongress Branch Results

Confirm the runner actually exercises:

| Test | Required expected error |
|---|---|
| Synthetic environment with participant-report origin | ENVIRONMENT_CONFLICT |
| Publication eligibility without public-summary permission, after other review conditions are satisfied | PUBLIC_SUMMARY_PERMISSION_REQUIRED |
| Decision recorded before complaint receipt | DECISION_TIME_ORDER |
| Revoked mandate with a recommendation disposition | REVIEW_ASSERTIONS_REQUIRED |

A correctly rejected invalid fixture is a passed test.

A missing module or an unexecuted branch is not a passed test.

Record existing self_test() calls as suite invocations unless the suite exposes
its own internal test counts. Do not invent assertion counts.

## Step 6: Verify the Synthetic Dashboard

For the supplied synthetic fixture, confirm:

- Acknowledgement numerator: 1.
- Acknowledgement denominator: 1.
- Due-action verification numerator: 0.
- Due-action verification denominator: 1.
- Disclosure-review coverage: 0 out of 1.
- Benefit among assessed actions: not estimable.
- Publication authority: none.
- Readiness gaps remain visible.

Do not treat unverified completion as confirmed improvement.

Do not claim this fixture validates real accessibility, expression approval,
retaliation protection, or participant satisfaction.

## Step 7: Check the Report Without Installing Anything

Expected report:

cybermind/validation/synthetic-validation-report.json

If Python 3 is already available, this standard-library check validates JSON
syntax, rejects non-standard numeric constants and repeated object keys, and
prints only the top-level field names:

```sh
if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json
from pathlib import Path

path = Path("cybermind/validation/synthetic-validation-report.json")

if not path.is_file() or path.stat().st_size == 0:
    raise SystemExit("Report missing or empty")

def reject_constant(value):
    raise ValueError("Non-standard JSON numeric constant: " + value)

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Repeated JSON object key: " + key)
        result[key] = value
    return result

with path.open("r", encoding="utf-8") as handle:
    report = json.load(
        handle,
        parse_constant=reject_constant,
        object_pairs_hook=unique_object,
    )

if not isinstance(report, dict):
    raise SystemExit("Report must be a JSON object")

print("JSON syntax check passed")
print("Top-level fields:", ", ".join(sorted(report)))
print("This check does not validate test truth or report-schema conformance.")
PY
else
    printf '%s\n' "Python JSON check not executed: python3 unavailable."
fi
```

Then inspect the report against the runner's actual output contract.

Confirm that:

- Runtime evidence reflects the interpreter actually used.
- Executed, failed, and not-executed counts are distinct.
- Self-test suites and added branch tests are not double-counted.
- Adversarial classifications derive from actual comparisons.
- Missing dependencies remain visible.
- No source hash, signature, or external attestation is invented.
- No private content or credentials appear.
- publication_authority remains none.

## Completion Criterion

Stop after obtaining one honest execution result and validating its report,
or after identifying a concrete blocker that cannot be resolved within the
permitted scope.

Do not add features merely because the verification session has time remaining.

If a correction was necessary, rerun the affected check and the available
runner suites, then record both the original failure and the retest outcome.

## Final Response Format

Report:

1. Files changed during this verification session.
2. Commands actually executed.
3. Observed Lua version and interpreter path.
4. Syntax-check outcome.
5. Runner exit status.
6. Exact suite and added-test outcomes.
7. Report existence and JSON-check outcome.
8. Remaining failures or unexecuted checks.
9. The smallest justified next step.

Do not state that CyberCongress is validated.

Do not state that the runner passed unless it executed and its report supports
that statement.

## Attribution

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Credit and workstream metadata only—not identity, consent, execution evidence,
or authority over another person or system.

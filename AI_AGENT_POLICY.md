# AI Agent Policy (Non-Negotiable)

This repository is optimized for constrained AI-chat and dev-tunnel environments.

**Every AI-chat system and coding agent MUST obey this policy.**  
If you cannot comply, halt and request human guidance instead of trying to work around it.

---

## 1. Hard Prohibitions

### 1.1 No Rustup, no Cargo installation

You MUST NOT:
- Install or re-install Rustup, Cargo, or Rust toolchains.
- Run any `rustup` commands (`rustup default`, `rustup toolchain install`, etc.).
- Run any installer for Rust or Cargo, including but not limited to:
  - `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- ...`
  - Any package manager command that installs `rustc` or `cargo`.

If `cargo` is not available in this environment, treat that as a fixed property, not a problem to solve. All work must proceed without Cargo.

### 1.2 No language edition downgrades

- The workspace is authored for `edition = "2024"` at the workspace level.
- You MUST NOT change `edition = "2024"` to older editions (2021/2018/2015) unless explicitly instructed by the human host.
- Do not claim that an unsupported edition is the cause of errors when no compiler has actually run.

---

## 2. Primary Tools and Data Sources

### 2.1 SQLite as the canonical index

- `master.sql` defines the canonical schema and seed data.
- `master.db` is the live, authoritative index for:
  - Domains and objects (concepts, components, traits, macros).
  - Files (paths and roles).
  - Tasks (open work items and priorities).
  - Environment predicates (host, safety, dev-tunnel behavior).

You MUST:
- Ensure `master.db` exists and is up to date with `master.sql`:
  - `cd /workspace && sqlite3 master.db < master.sql` (run only when schema or seeds change).
- Query `master.db` before making structural changes, to understand:
  - Which objects and domains are relevant.
  - Which files are associated with them.
  - Which tasks are already defined.

### 2.2 Docs-first behavior

- For every code or config change, you MUST:
  - Locate the corresponding documentation under `docs/` (via `master.db` if needed).
  - Update or extend the relevant `.md` file(s) so docs match the code.
- If you create a new component and no doc exists yet:
  - Create a suitable doc under the correct `docs/` subdirectory, and
  - Register the new file path in `master.sql` (in the `file` and `object_file` tables), then regenerate `master.db`.

---

## 3. Dev-Tunnel and Environment Constraints

### 3.1 Assume a restricted environment

You MUST assume:
- Disk space is limited.
- Network operations may be slow or subject to timeouts.
- Only lightweight tools are acceptable.

### 3.2 Allowed vs forbidden actions

**Allowed**:
- Using `sqlite3` to read and update `master.db`.
- Using standard shell tools (`ls`, `cat`, `grep`, `sed`, `awk`, `find`, `cp`, `mv`, `rm`) for file discovery and editing.
- Editing Rust and Markdown files in place.

**Forbidden**:
- Any form of Rustup or Cargo installation.
- Repeated attempts to run failing installation or download commands.
- System-level changes that go beyond what is needed to read/write this repository.

If a command fails due to "No space left on device", timeouts, or similar environmental errors, you MUST NOT keep retrying variants of the same action. Document the failure (for example, by adding a `task` entry in `master.db`) and switch to a different strategy using existing tools.

---

## 4. Required Documentation and Contract Files

You MUST read and obey all of the following:
- `AI_AGENT_POLICY.md` (this file).
- `docs/ai-chat-env/index.md`.
- `docs/ai-chat-env/sqlite-and-tooling-contract.md`.
- `docs/cargo-env/dev-tunnel-behavior.md`.

Together, these documents define:
- How you may use SQLite (`master.sql` / `master.db`).
- How you must treat dev-tunnel constraints.
- How you keep code and documentation aligned.

---

## 5. Behavior Checklist for Agents

Before making changes, verify:

1. You have read this policy and `docs/ai-chat-env/index.md`.
2. You are NOT planning to install or use Rustup/Cargo.
3. `master.db` exists and matches `master.sql` (or you have just regenerated it).
4. You have queried `master.db` to:
   - Identify the domain and object you are about to work on.
   - List open tasks related to that object.
   - Find the associated file paths.
5. For each change:
   - You know which `docs/` file(s) must be updated.
   - You will update `master.sql` / `master.db` if new files or tasks are introduced.

If any of these conditions are not satisfied, halt and request human guidance instead of improvising.

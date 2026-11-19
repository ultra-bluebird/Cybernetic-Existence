# Minimal Privacy Deck Setup

## Purpose

This deck supports local writing, encrypted notes, local documentation, and a
local Git clone of `mk-bluebird/Augmented-Hub`. It does not require cloud sync.

## Local-First Baseline

- Use full-disk encryption or an encrypted data volume.
- Keep a separate local encrypted workspace for notes and repositories.
- Disable automatic synchronization clients unless they are deliberately needed.
- Prefer local documentation mirrors and locally installed toolchains.
- Keep Wi-Fi and Bluetooth disabled when they are not needed for an approved task.
- Use a USB-C power bank that matches the deck's negotiated power needs.
- Maintain at least one offline encrypted backup under the user's direct control.
- Test restore procedures before relying on a backup.

## Local Git Workflow

```sh
git clone --filter=blob:none --no-checkout <approved-remote>
cd Augmented-Hub
git checkout main

git config --local fetch.prune true
git config --local gc.auto 0
git config --local core.autocrlf false
git config --local advice.detachedHead false
```

The remote endpoint must be chosen and approved by the user. Do not embed
credentials in Git remotes, repository configuration, shell history, or notes.

## Offline Work Routine

1. Start the deck with networking disabled unless a specific task requires it.
2. Unlock encrypted storage locally.
3. Open the local notes directory and local repository.
4. Write, build, test, and commit locally.
5. Review changes and generate artifacts locally.
6. Export or synchronize only after choosing the destination and reviewing scope.
7. Lock or power down when work is complete.

## Recovery Check

At least once per maintenance cycle:

1. Boot from a recovery environment.
2. Confirm encrypted storage unlocks with the intended local method.
3. Restore a non-sensitive test file from offline backup.
4. Verify the restored file checksum.
5. Remove the test restoration if no longer needed.

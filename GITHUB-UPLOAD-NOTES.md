# WoW Server Control Center - GitHub source sync

This package is the latest conversation snapshot: **1.6.46 — Transmog All Characters**.

## Upload

1. Extract this archive on your Mac.
2. Double-click `PUBLISH-LATEST-TO-GITHUB.command` from inside the extracted project folder.
3. The command clones `iSHUSHL/WoW-Custom-Server-Manager`, copies the 1.6.46 source, stages the diff, commits it and pushes to `main` without force-pushing.

GitHub authentication must be configured on the Mac (e.g., `gh auth login` and `gh auth setup-git` if using GitHub CLI). A macOS terminal may require Command Line Tools (`xcode-select --install`).

## Included

SwiftUI application source, WotLK PlayerBots integration, transmog module and MogIt install scripts, all-account transmog unlock command, GameEvent crash patch, TBC/Cata tools, build commands, images/resources and release notes.

## Deliberately not uploaded

The nested historical `WoWServerControlCenter-1.5.78-FullTooltipRepair.zip`, transient Python `__pycache__`, compiled outputs, local databases, private credentials, and runtime profiles. Repository's existing `.github` workflows are preserved.

## Verification

The ZIP itself is packaging only: no on-Mac SwiftUI compilation, game-server runtime verification, or GitHub push has occurred when this archive is downloaded. The publish script reports success only when GitHub accepts the push.

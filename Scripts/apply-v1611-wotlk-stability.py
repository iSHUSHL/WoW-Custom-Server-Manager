#!/usr/bin/env python3
from pathlib import Path

root = Path('.')
install = root/'Scripts/install-profile.sh'
watchdog = root/'Scripts/run-core-build-watchdog.py'
server = root/'Sources/WoWServerControlCenter/ServerModel.swift'
build = root/'Build.command'
notes = root/'RELEASE-NOTES.md'

# WotLK: single-job compile for maximum stability on the user's Apple Silicon build.
s = install.read_text()
old = 'if [[ "$PROFILE" == "wotlk" && "$JOBS" -gt 2 ]]; then JOBS=2; fi'
new = 'if [[ "$PROFILE" == "wotlk" ]]; then JOBS=1; fi'
if old not in s:
    raise SystemExit('WotLK JOBS cap not found')
s = s.replace(old, new, 1)
s = s.replace('log "Building with $JOBS parallel job(s) + aggressive live stall watchdog"', 'log "Building with $JOBS job(s) + live stall watchdog"', 1)
install.write_text(s)

# Restore a stable machine-readable heartbeat prefix the Swift UI already recognizes.
s = watchdog.read_text()
old = "heartbeat=f'[ {progress:>4}] WoWCC BUILDING {args.label} {progress_detail or progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | quiet {silent}s | compiler CPU {cpu:.1f}% | {active_short}\\n'"
new = "heartbeat=f'[build:{args.label}] BUILDING {progress_detail or progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | quiet {silent}s | compiler CPU {cpu:.1f}% | {active_short}\\n'"
if old not in s:
    raise SystemExit('Current watchdog heartbeat not found')
s = s.replace(old, new, 1)
watchdog.write_text(s)

# Never rebuild a core while that realm is still live. This also frees CPU/RAM and
# prevents install-time replacement of binaries that are still running.
s = server.read_text()
old = '    func installSelectedProfile() { runScript("install-profile.sh", args: [selectedExpansion.rawValue]) }'
new = '''    func installSelectedProfile() {
        let expansion = selectedExpansion
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        stopAll()
        statusMessage = "Stopping \\(expansion.shortTitle) services before core rebuild…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.runScript("install-profile.sh", args: [expansion.rawValue])
        }
    }'''
if old not in s:
    raise SystemExit('installSelectedProfile one-line function not found')
s = s.replace(old, new, 1)
server.write_text(s)

# Version.
s = build.read_text().replace('<string>1.6.10</string>', '<string>1.6.11</string>').replace('<string>1610</string>', '<string>1611</string>')
build.write_text(s)

header = '''# v1.6.11 — WotLK Rebuild Stability Mode\n\n- WotLK core rebuild now stops World, Auth and managed MySQL before compiling; rebuilds can no longer run while the realm is still online.\n- WotLK core compilation uses one Ninja job for maximum stability on Apple Silicon.\n- Fixed the build-status regression where the watchdog emitted a new prefix but the Swift UI still searched for `[build:...]`; live progress/CPU heartbeats are visible again.\n- Resumable Ninja build cache from 1.6.10 remains enabled, so interrupted builds reuse completed objects.\n- A long-running compiler is left alone while CPU is active; a genuinely idle build is terminated by the existing watchdog.\n\n'''
notes.write_text(header + notes.read_text())
print('Applied v1.6.11 WotLK rebuild stability patch')

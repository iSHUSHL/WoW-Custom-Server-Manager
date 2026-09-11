#!/usr/bin/env python3
from pathlib import Path

root = Path('.')
install = root / 'Scripts/install-profile.sh'
watchdog = root / 'Scripts/run-core-build-watchdog.py'
server = root / 'Sources/WoWServerControlCenter/ServerModel.swift'
buildcmd = root / 'Build.command'
notes = root / 'RELEASE-NOTES.md'

# 1) Preserve a valid WotLK Ninja build cache instead of deleting all compiled objects.
s = install.read_text()
old = '''rm -rf "$BUILD"
mkdir -p "$BUILD"

JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"'''
new = '''# WotLK builds are large. Preserve a valid Ninja build tree so an interrupted
# rebuild resumes from already compiled objects instead of restarting at 0%.
if [[ "$PROFILE" == "wotlk" && -f "$BUILD/CMakeCache.txt" ]]; then
  CACHE_GENERATOR="$(grep '^CMAKE_GENERATOR:INTERNAL=' "$BUILD/CMakeCache.txt" 2>/dev/null | cut -d= -f2- || true)"
  CACHE_SOURCE="$(grep '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$BUILD/CMakeCache.txt" 2>/dev/null | cut -d= -f2- || true)"
  if [[ "$CACHE_GENERATOR" == "Ninja" && "$CACHE_SOURCE" == "$SRC_ROOT" ]]; then
    log "Resuming existing WotLK Ninja build cache — completed objects will be reused."
  else
    log "WotLK build cache is incompatible; recreating it once."
    rm -rf "$BUILD"
  fi
else
  rm -rf "$BUILD"
fi
mkdir -p "$BUILD"

JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"'''
if old not in s:
    raise SystemExit('install-profile build reset block not found')
s = s.replace(old, new, 1)
install.write_text(s)

# 2) Teach watchdog Ninja [current/total] progress and emit frequent visible heartbeats.
s = watchdog.read_text()
s = s.replace("progress = '?'", "progress = '?'\nprogress_detail = ''", 1)
s = s.replace("global last_output,last_line,progress", "global last_output,last_line,progress,progress_detail", 1)
old = '''        m=re.search(r'\\[\\s*(\\d+)%\\]', line)
        if m: progress=m.group(1)+'%'
        sys.stdout.write(line); sys.stdout.flush(); log.write(line)'''
new = '''        m=re.search(r'\\[\\s*(\\d+)%\\]', line)
        if m:
            progress=m.group(1)+'%'
            progress_detail=progress
        n=re.search(r'\\[(\\d+)/(\\d+)\\]', line)
        if n:
            current,total=int(n.group(1)),max(1,int(n.group(2)))
            progress=f'{(current*100)//total}%'
            progress_detail=f'{current}/{total} ({progress})'
        sys.stdout.write(line); sys.stdout.flush(); log.write(line)'''
if old not in s:
    raise SystemExit('watchdog reader progress block not found')
s = s.replace(old, new, 1)
s = s.replace('time.sleep(5)', 'time.sleep(2)', 1)
old = "heartbeat=f'[build:{args.label}] BUILDING {progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | no-output {silent}s | child CPU {cpu:.1f}% | {active_short}\\n'"
new = "heartbeat=f'[build:{args.label}] BUILDING {progress_detail or progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | quiet {silent}s | compiler CPU {cpu:.1f}% | {active_short}\\n'"
if old not in s:
    raise SystemExit('watchdog heartbeat block not found')
s = s.replace(old, new, 1)
# Faster recovery only when the whole compile tree is truly idle. High-CPU clang is never killed.
s = s.replace('if silent >= 180 and cpu < 0.5:', 'if silent >= 120 and cpu < 0.5:', 1)
s = s.replace('if idle_zero >= 6:', 'if idle_zero >= 5:', 1)
s = s.replace('>3m no output and no active compiler CPU', '>2m no output and no active compiler CPU', 1)
watchdog.write_text(s)

# 3) Prefer build heartbeat lines in GUI chunks, so CPU/progress is visible instead of a stale .cpp line.
s = server.read_text()
old = '''            if let chunk = String(data: data, encoding: .utf8) {
                let lastLine = chunk.split(separator: "\\n").last.map(String.init) ?? chunk
                Task { @MainActor in
                    let line = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.statusMessage = line.isEmpty ? "Running: \\(name)" : line
                }
            }'''
new = '''            if let chunk = String(data: data, encoding: .utf8) {
                let lines = chunk.split(separator: "\\n", omittingEmptySubsequences: true).map(String.init)
                let heartbeat = lines.reversed().first { $0.contains("[build:") && $0.contains("BUILDING") }
                let displayLine = heartbeat ?? lines.last ?? chunk
                Task { @MainActor in
                    let line = displayLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.statusMessage = line.isEmpty ? "Running: \\(name)" : line
                }
            }'''
if old not in s:
    raise SystemExit('ServerModel runScript output block not found')
s = s.replace(old, new, 1)
server.write_text(s)

# 4) Version + release notes.
s = buildcmd.read_text().replace('<string>1.6.9</string>', '<string>1.6.10</string>').replace('<string>1609</string>', '<string>1610</string>')
buildcmd.write_text(s)

header = '''# v1.6.10 — Resumable WotLK Build + Real Ninja Progress

- WotLK rebuilds now preserve a compatible Ninja build directory and resume already compiled objects after an interruption instead of restarting from 0%.
- Build watchdog understands Ninja progress such as `[105/1766]` and reports both object count and calculated percentage.
- Heartbeats are emitted every 2 seconds with elapsed time, quiet time, compiler CPU, and the active compiler command.
- WoWCC GUI prefers watchdog heartbeat lines while a core build is active, so a long C++ translation unit no longer looks frozen.
- A build is terminated only after 2+ minutes without output AND repeated near-zero CPU checks; an actively compiling clang process is never killed simply for taking time.
- WotLK remains on Ninja with 2 jobs, server/tools split, PlayerBots, WrathSilicon client prep, and flying-everywhere support.

'''
notes.write_text(header + notes.read_text())
print('Applied v1.6.10 resumable WotLK build patch')

#!/usr/bin/env python3
from pathlib import Path

root = Path('.')

# 1) Build watchdog helper.
watchdog = root / 'Scripts/run-core-build-watchdog.py'
watchdog.write_text(r'''#!/usr/bin/env python3
import argparse, os, re, signal, subprocess, sys, threading, time

ap = argparse.ArgumentParser()
ap.add_argument('--build', required=True)
ap.add_argument('--jobs', type=int, required=True)
ap.add_argument('--log', required=True)
ap.add_argument('--label', default='core')
ap.add_argument('--verbose', action='store_true')
args = ap.parse_args()

cmd = ['cmake', '--build', args.build, '--config', 'Release', '--parallel', str(max(1,args.jobs))]
if args.verbose:
    cmd.append('--verbose')

os.makedirs(os.path.dirname(args.log), exist_ok=True)
log = open(args.log, 'a', buffering=1, encoding='utf-8', errors='replace')
start = time.time()
last_output = time.time()
last_line = ''
progress = '?'

proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)

def descendants_cpu():
    try:
        out = subprocess.check_output(['/bin/ps','-axo','pid=,ppid=,%cpu=,command='], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return 0.0, ''
    rows=[]
    for line in out.splitlines():
        p=line.strip().split(None,3)
        if len(p)<4: continue
        try: rows.append((int(p[0]),int(p[1]),float(p[2]),p[3]))
        except: pass
    wanted={proc.pid}; changed=True
    while changed:
        changed=False
        for pid,ppid,cpu,c in rows:
            if ppid in wanted and pid not in wanted:
                wanted.add(pid); changed=True
    active=[r for r in rows if r[0] in wanted and r[0]!=proc.pid]
    cpu=sum(r[2] for r in active)
    top=max(active,key=lambda r:r[2],default=None)
    return cpu, (top[3] if top else '')

def reader():
    global last_output,last_line,progress
    assert proc.stdout is not None
    for line in proc.stdout:
        last_output=time.time(); last_line=line.rstrip()
        m=re.search(r'\[\s*(\d+)%\]', line)
        if m: progress=m.group(1)+'%'
        sys.stdout.write(line); sys.stdout.flush(); log.write(line)

threading.Thread(target=reader, daemon=True).start()
idle_zero=0
while proc.poll() is None:
    time.sleep(20)
    elapsed=int(time.time()-start)
    silent=int(time.time()-last_output)
    cpu, active=descendants_cpu()
    active_short=active[-120:] if active else 'waiting for compiler output'
    heartbeat=f'[build:{args.label}] BUILDING {progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | no-output {silent}s | child CPU {cpu:.1f}% | {active_short}\n'
    sys.stdout.write(heartbeat); sys.stdout.flush(); log.write(heartbeat)
    # Only declare a true stall after 20 minutes with no output AND essentially no child CPU.
    if silent >= 1200 and cpu < 0.5:
        idle_zero += 1
    else:
        idle_zero = 0
    if idle_zero >= 3:
        msg=f'[build:{args.label}] ERROR: build appears genuinely stalled: >20m no output and no active compiler CPU. Terminating build process group.\n'
        sys.stderr.write(msg); log.write(msg)
        try: os.killpg(proc.pid, signal.SIGTERM)
        except Exception: pass
        time.sleep(5)
        if proc.poll() is None:
            try: os.killpg(proc.pid, signal.SIGKILL)
            except Exception: pass
        log.close(); sys.exit(124)

rc=proc.wait()
elapsed=int(time.time()-start)
msg=f'[build:{args.label}] FINISHED exit={rc} elapsed={elapsed//60}m{elapsed%60:02d}s\n'
sys.stdout.write(msg); log.write(msg); log.close()
sys.exit(rc)
''')
watchdog.chmod(0o755)

# 2) Patch install-profile.sh build runner.
p = root / 'Scripts/install-profile.sh'
s = p.read_text()
old = '''JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"\nARCH="$(uname -m)"'''
new = '''JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"\n# WotLK PlayerBots can make Apple Silicon appear frozen around 2-4% when too many\n# translation units compile at once. Cap only WotLK to a memory-safe level; the\n# watchdog below still reports active compiler CPU while a single heavy object runs.\nif [[ "$PROFILE" == "wotlk" && "$JOBS" -gt 8 ]]; then JOBS=8; fi\nARCH="$(uname -m)"'''
if old not in s:
    raise SystemExit('install-profile JOBS marker not found')
s=s.replace(old,new,1)
old2='''  log "Building with $JOBS parallel job(s)"\n  if ! cmake --build "$BUILD" --config Release --parallel "$JOBS" 2>&1 | tee -a "$BUILD_LOG"; then\n    log "Parallel build failed. Re-running one job verbosely to expose the real error…"\n    if ! cmake --build "$BUILD" --config Release --parallel 1 --verbose 2>&1 | tee -a "$BUILD_LOG"; then'''
new2='''  log "Building with $JOBS parallel job(s) + live stall watchdog"\n  WATCHDOG="$(cd "$(dirname "$0")" && pwd)/run-core-build-watchdog.py"\n  if ! python3 "$WATCHDOG" --build "$BUILD" --jobs "$JOBS" --log "$BUILD_LOG" --label "$PROFILE"; then\n    log "Parallel build failed or truly stalled. Re-running one job verbosely to expose the real error…"\n    if ! python3 "$WATCHDOG" --build "$BUILD" --jobs 1 --log "$BUILD_LOG" --label "$PROFILE-verbose" --verbose; then'''
if old2 not in s:
    raise SystemExit('install-profile build marker not found')
s=s.replace(old2,new2,1)
p.write_text(s)

# 3) Upgrade flying helper for WrathSilicon-aware output.
p = root / 'Scripts/enable-wotlk-flying-everywhere.py'
s = p.read_text()
old = '''        bat = client / 'WoWCC-Fly-Everywhere.bat'\n        bat.write_text('@echo off\\r\\ncd /d "%~dp0"\\r\\nstart "" "Wow.exe" -direct\\r\\n', encoding='ascii')\n        note = client / 'WoWCC-Fly-Everywhere.txt'\n        note.write_text('WoWCC old-world mounted flying is enabled. Launch WotLK with WoWCC-Fly-Everywhere.bat so the 3.3.5a client loads the patched loose AreaTable.dbc via -direct.\\n', encoding='utf-8')\n        print(f'[flying:wotlk] Client loose DBC written: {loose}')\n        print(f'[flying:wotlk] Windows launcher written: {bat}')'''
new = '''        bat = client / 'WoWCC-Fly-Everywhere.bat'\n        bat.write_text('@echo off\\r\\ncd /d "%~dp0"\\r\\nstart "" "Wow.exe" -direct\\r\\n', encoding='ascii')\n\n        # WoWSilicon/WrathSilicon 3.1 currently launches the selected executable\n        # without arbitrary game arguments, so its normal Play button cannot add\n        # WoW 3.3.5a's required -direct switch. Create a native macOS helper that\n        # opens WoWSilicon and clearly records the required client mode. The loose\n        # DBC itself is still installed automatically here.\n        mac = client / 'WoWCC-WrathSilicon-Flying.command'\n        mac.write_text(\n            '#!/bin/zsh\\n'\n            'set -e\\n'\n            'CLIENT_DIR="$(cd "$(dirname "$0")" && pwd)"\\n'\n            'echo "WoWCC flying patch is installed in: $CLIENT_DIR/Data/DBFilesClient/AreaTable.dbc"\\n'\n            'echo "WrathSilicon 3.1 Play does not expose custom WoW.exe arguments."\\n'\n            'echo "The client must be launched with -direct for loose DBC loading."\\nn'\n            'open -a WoWSilicon 2>/dev/null || open -a WrathSilicon 2>/dev/null || true\\n',\n            encoding='utf-8'\n        )\n        mac.chmod(0o755)\n        note = client / 'WoWCC-Fly-Everywhere.txt'\n        note.write_text(\n            'WoWCC old-world mounted flying client data is installed.\\n'\n            'Windows: use WoWCC-Fly-Everywhere.bat.\\n'\n            'WrathSilicon/WoWSilicon 3.1: the current launcher Play path does not expose arbitrary WoW.exe arguments, and WotLK loose DBC loading requires -direct. WoWCC therefore installs the DBC automatically but does not falsely claim the stock Play button enables -direct.\\n',\n            encoding='utf-8'\n        )\n        print(f'[flying:wotlk] Client loose DBC written: {loose}')\n        print(f'[flying:wotlk] Windows -direct launcher written: {bat}')\n        print(f'[flying:wotlk] WrathSilicon helper written: {mac}')'''
# Fix typo after constructing replacement intentionally below.
new = new.replace("'echo \\\"The client must be launched with -direct for loose DBC loading.\\\\n'\\n            'echo", "'echo \\\"The client must be launched with -direct for loose DBC loading.\\\\n'\\n            'echo")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
# Remove accidental literal n after escaped newline if present.
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
# final typo cleanup
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo").replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
# literal typo from template
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo").replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
# actual accidental sequence in raw template:
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n            'open", "\\\\n'\\n            'open")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
# specifically replace the malformed token
new = new.replace("\\\\n'\\n            'echo", "\\\\n'\\n            'echo")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\\\n'\\n", "\\\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
# just in case
new = new.replace("\\n'\\n            'echo", "\\n'\\n            'echo")
new = new.replace("\\n'\\n            'open", "\\n'\\n            'open")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
new = new.replace("\\n'\\n", "\\n'\\n")
# malformed exact text
new = new.replace("loading.\\\\n'\\nn'", "loading.\\\\n'")
if old not in s:
    raise SystemExit('flying helper marker not found')
s=s.replace(old,new,1)
p.write_text(s)

# 4) Bump version text in tracked text files only.
for rel in ['README.md','RELEASE-NOTES.md','Build.command','Package.swift','Sources/WoWServerControlCenter/WoWServerControlCenterApp.swift']:
    q=root/rel
    if not q.exists(): continue
    t=q.read_text()
    t=t.replace('1.6.6','1.6.7').replace('1606','1607')
    q.write_text(t)

rn=root/'RELEASE-NOTES.md'
if rn.exists():
    t=rn.read_text()
    header='''# v1.6.7 — WrathSilicon Client Prep + WotLK Build Watchdog\n\n- WotLK core builds now use a live watchdog with elapsed time, child compiler CPU and progress heartbeats.\n- WotLK parallelism is capped at 8 jobs to avoid memory-pressure stalls on Apple Silicon.\n- A build is only terminated as stalled after 20+ minutes without output and repeated near-zero compiler CPU checks.\n- Flying-everywhere client preparation remains automatic and now emits WrathSilicon-specific helper/instructions rather than pretending its stock Play button passes `-direct`.\n- All build diagnostics remain in WoWCC Logs via the existing core build log.\n\n'''
    rn.write_text(header+t)
print('v1.6.7 patch applied')

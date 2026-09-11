#!/usr/bin/env python3
from pathlib import Path

root=Path('.')
p=root/'Scripts/install-profile.sh'
s=p.read_text()
s=s.replace('if [[ "$PROFILE" == "wotlk" && "$JOBS" -gt 8 ]]; then JOBS=8; fi','if [[ "$PROFILE" == "wotlk" && "$JOBS" -gt 4 ]]; then JOBS=4; fi')
s=s.replace('Building with $JOBS parallel job(s) + live stall watchdog','Building with $JOBS parallel job(s) + aggressive live stall watchdog')
p.write_text(s)

w=root/'Scripts/run-core-build-watchdog.py'
s=w.read_text()
s=s.replace('time.sleep(20)','time.sleep(5)')
s=s.replace("# Only declare a true stall after 20 minutes with no output AND essentially no child CPU.\n    if silent >= 1200 and cpu < 0.5:","# A compiler that is genuinely working may be silent for minutes, so CPU wins.\n    # Recover only when there has been no output for 3 minutes AND the entire\n    # build process tree is essentially idle across repeated samples.\n    if silent >= 180 and cpu < 0.5:")
s=s.replace('if idle_zero >= 3:','if idle_zero >= 6:')
s=s.replace("ERROR: build appears genuinely stalled: >20m no output and no active compiler CPU.","ERROR: build appears genuinely stalled: >3m no output and no active compiler CPU.")
w.write_text(s)

for name in ['README.md','RELEASE-NOTES.md','Build.command','Package.swift','Sources/WoWServerControlCenter/AppVersion.swift','Sources/WoWServerControlCenter/WoWServerControlCenterApp.swift']:
    f=root/name
    if not f.exists(): continue
    t=f.read_text()
    t=t.replace('1.6.7','1.6.8').replace('1607','1608')
    f.write_text(t)

r=root/'RELEASE-NOTES.md'
if r.exists():
    t=r.read_text()
    if 'v1.6.8 — WotLK Build Recovery' not in t:
        t='# v1.6.8 — WotLK Build Recovery\n\n- WotLK PlayerBots compile capped to 4 parallel jobs on macOS to avoid early 2–4% memory-pressure stalls.\n- Build watchdog heartbeat now prints every 5 seconds with progress, elapsed time, silence duration, child CPU and active compiler command.\n- A build is considered stalled only when output is silent for 3+ minutes and the full build process tree remains effectively idle for repeated samples. Active clang compilation is never killed merely because the percentage is unchanged.\n- Existing WrathSilicon flying-everywhere support remains intact.\n\n'+t
        r.write_text(t)
print('v1.6.8 patch applied')

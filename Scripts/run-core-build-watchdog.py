#!/usr/bin/env python3
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
progress_detail = ''

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
    global last_output,last_line,progress,progress_detail
    assert proc.stdout is not None
    for line in proc.stdout:
        last_output=time.time(); last_line=line.rstrip()
        m=re.search(r'\[\s*(\d+)%\]', line)
        if m:
            progress=m.group(1)+'%'
            progress_detail=progress
        n=re.search(r'\[(\d+)/(\d+)\]', line)
        if n:
            current,total=int(n.group(1)),max(1,int(n.group(2)))
            progress=f'{(current*100)//total}%'
            progress_detail=f'{current}/{total} ({progress})'
        sys.stdout.write(line); sys.stdout.flush(); log.write(line)

threading.Thread(target=reader, daemon=True).start()
idle_zero=0
while proc.poll() is None:
    time.sleep(2)
    elapsed=int(time.time()-start)
    silent=int(time.time()-last_output)
    cpu, active=descendants_cpu()
    active_short=active[-120:] if active else 'waiting for compiler output'
    heartbeat=f'[build:{args.label}] BUILDING {progress_detail or progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | quiet {silent}s | compiler CPU {cpu:.1f}% | {active_short}\n'
    sys.stdout.write(heartbeat); sys.stdout.flush(); log.write(heartbeat)
    # A compiler that is genuinely working may be silent for minutes, so CPU wins.
    # Recover only when there has been no output for 3 minutes AND the entire
    # build process tree is essentially idle across repeated samples.
    if silent >= 120 and cpu < 0.5:
        idle_zero += 1
    else:
        idle_zero = 0
    if idle_zero >= 5:
        msg=f'[build:{args.label}] ERROR: build appears genuinely stalled: >2m no output and no active compiler CPU. Terminating build process group.\n'
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

#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit('usage: apply-wotlk-gameevent-crash-fix.py CORE_ROOT')

p = Path(sys.argv[1]) / 'src/server/game/Events/GameEventMgr.cpp'
if not p.exists():
    raise SystemExit(f'ERROR: GameEventMgr.cpp not found: {p}')

s = p.read_text()
marker = 'WoWCC: SmartAI callbacks may respawn/remove creatures'
if marker in s:
    print('[core:wotlk] GameEvent SmartAI iterator-safety patch already present')
    raise SystemExit(0)

# Find the worker first, then its Visit() method. Do not depend on exact upstream
# whitespace, parameter type spelling, or one-line formatting.
worker = s.find('GameEventAIHookWorker')
if worker < 0:
    raise SystemExit('ERROR: GameEventAIHookWorker not found in GameEventMgr.cpp')

m = re.search(r'\bvoid\s+Visit\s*\((?P<params>[^)]*)\)\s*\{', s[worker:], re.S)
if not m:
    raise SystemExit('ERROR: GameEventAIHookWorker::Visit not found; upstream API changed')

sig_start = worker + m.start()
body_open = worker + m.end() - 1
params = m.group('params')

# Extract the map parameter name from the current upstream signature.
name_match = re.search(r'([A-Za-z_]\w*)\s*(?:\[[^]]*\])?\s*$', params.strip())
if not name_match:
    raise SystemExit(f'ERROR: cannot determine Visit map parameter from: {params!r}')
map_name = name_match.group(1)

# Match the function's closing brace with a small C++ aware scanner so nested
# if/for blocks do not confuse the patcher.
def matching_brace(text, start):
    depth = 0
    i = start
    state = 'code'
    while i < len(text):
        c = text[i]
        n = text[i + 1] if i + 1 < len(text) else ''
        if state == 'code':
            if c == '/' and n == '/': state = 'line'; i += 2; continue
            if c == '/' and n == '*': state = 'block'; i += 2; continue
            if c == '"': state = 'string'; i += 1; continue
            if c == "'": state = 'char'; i += 1; continue
            if c == '{': depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0: return i
        elif state == 'line':
            if c == '\n': state = 'code'
        elif state == 'block':
            if c == '*' and n == '/': state = 'code'; i += 2; continue
        elif state in ('string', 'char'):
            if c == '\\': i += 2; continue
            if (state == 'string' and c == '"') or (state == 'char' and c == "'"):
                state = 'code'
        i += 1
    return -1

body_close = matching_brace(s, body_open)
if body_close < 0:
    raise SystemExit('ERROR: unmatched braces in GameEventAIHookWorker::Visit')

# Keep the exact upstream function signature; replace only its body.
indent_match = re.search(r'(?m)^(\s*)void\s+Visit\s*\(', s[sig_start:body_open + 1])
indent = indent_match.group(1) if indent_match else '        '
i1 = indent + '    '
i2 = i1 + '    '

new_body = '''{
I1// WoWCC: SmartAI callbacks may respawn/remove creatures from this map.
I1// Snapshot GUIDs first so no unordered_map iterator survives a callback.
I1std::vector<ObjectGuid> wowccCreatureGuids;
I1wowccCreatureGuids.reserve(MAP.size());
I1for (auto const& wowccPair : MAP)
I2wowccCreatureGuids.push_back(wowccPair.first);

I1for (ObjectGuid const& wowccGuid : wowccCreatureGuids)
I1{
I2auto wowccItr = MAP.find(wowccGuid);
I2if (wowccItr == MAP.end())
I2    continue;

I2Creature* wowccCreature = wowccItr->second;
I2if (wowccCreature && wowccCreature->IsInWorld() && !wowccCreature->IsDuringRemoveFromWorld() && wowccCreature->FindMap() && wowccCreature->IsAIEnabled && wowccCreature->AI())
I2    wowccCreature->AI()->sOnGameEvent(_activate, _eventId);
I1}
IND}'''.replace('I1', i1).replace('I2', i2).replace('IND', indent).replace('MAP', map_name)

s = s[:body_open] + new_body + s[body_close + 1:]

# std::vector is used by the patch. Add an explicit include if upstream does not
# already provide one transitively.
if not re.search(r'^\s*#\s*include\s*<vector>\s*$', s, re.M):
    includes = list(re.finditer(r'^\s*#\s*include[^\n]*$', s, re.M))
    if includes:
        pos = includes[-1].end()
        s = s[:pos] + '\n#include <vector>' + s[pos:]
    else:
        s = '#include <vector>\n' + s

p.write_text(s)
print('[core:wotlk] Applied GameEvent SmartAI iterator-safety crash patch (layout-independent)')

#!/usr/bin/env python3
from pathlib import Path
import re, sys

root = Path(sys.argv[1])
candidates = [
    root / "src/game/Entities/GameObject.cpp",
    root / "src/game/GameObject.cpp",
]
go = next((p for p in candidates if p.exists()), None)
if go is None:
    raise SystemExit("ERROR: GameObject.cpp not found in known CMaNGOS TBC locations.")

s = go.read_text(errors="strict")

# Restrict the edit to GameObject::Use and, inside it, only the
# GAMEOBJECT_TYPE_SPELLCASTER case. This avoids depending on comments,
# indentation, or harmless upstream formatting changes.
func_start = s.find("void GameObject::Use(")
if func_start < 0:
    raise SystemExit("ERROR: GameObject::Use function not found.")

func_end = s.find("\n}\n", func_start)
if func_end < 0:
    raise SystemExit("ERROR: Could not determine end of GameObject::Use.")

func = s[func_start:func_end + 3]
case_start = func.find("case GAMEOBJECT_TYPE_SPELLCASTER")
if case_start < 0:
    raise SystemExit("ERROR: GAMEOBJECT_TYPE_SPELLCASTER case not found in GameObject::Use.")

next_case = func.find("\n        case ", case_start + 1)
if next_case < 0:
    raise SystemExit("ERROR: Could not determine end of GAMEOBJECT_TYPE_SPELLCASTER case.")

block = func[case_start:next_case]

# Safety checks: this is the exact vulnerable logical branch observed in LLDB.
if "info->spellcaster.charges" not in block or "onSuccess" not in block:
    raise SystemExit(
        "ERROR: Spellcaster GameObject block no longer contains the expected onSuccess/charges logic; "
        "refusing to patch a different code path."
    )

safe_pat = re.compile(r"onSuccess\s*=\s*\[\s*this\s*,\s*info\s*\]\s*\(\s*\)")
vuln_pat = re.compile(r"onSuccess\s*=\s*\[\s*&\s*\]\s*\(\s*\)")

if safe_pat.search(block):
    print(f"[core:tbc] GameObject::Use lifetime fix already applied: {go}")
    raise SystemExit(0)

matches = list(vuln_pat.finditer(block))
if len(matches) != 1:
    raise SystemExit(
        f"ERROR: Expected exactly one vulnerable onSuccess capture in the spellcaster block; found {len(matches)}."
    )

patched_block = vuln_pat.sub("onSuccess = [this, info]()", block, count=1)
patched_func = func[:case_start] + patched_block + func[next_case:]
patched = s[:func_start] + patched_func + s[func_end + 3:]

# Post-write verification before committing the source.
new_func = patched[func_start:func_start + len(patched_func)]
new_case_start = new_func.find("case GAMEOBJECT_TYPE_SPELLCASTER")
new_next_case = new_func.find("\n        case ", new_case_start + 1)
new_block = new_func[new_case_start:new_next_case]
if not safe_pat.search(new_block) or vuln_pat.search(new_block):
    raise SystemExit("ERROR: GameObject::Use patch verification failed; source was not written.")

go.write_text(patched)
print(f"[core:tbc] Applied confirmed GameObject::Use lifetime fix: {go}")

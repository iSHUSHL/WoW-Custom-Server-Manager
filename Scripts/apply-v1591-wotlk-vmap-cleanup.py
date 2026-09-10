from pathlib import Path

root = Path(__file__).resolve().parents[1]
prep = root / 'Scripts/prepare-client.sh'
build = root / 'Build.command'
notes = root / 'RELEASE-NOTES.md'

s = prep.read_text()
old = '''  echo "[client:wotlk] Extracting VMap source…"\n  ./vmap4extractor\n\n  [[ -d Buildings ]] || { echo "ERROR: vmap4extractor completed but Buildings/ was not created." >&2; exit 42; }\n  rm -rf vmaps\n'''
new = '''  # vmap4extractor requires a completely clean output directory. A previous\n  # interrupted/retried Prepare Client can leave Buildings/ behind and the\n  # extractor then aborts with “output directory seems to be polluted”.\n  echo "[client:wotlk] Cleaning stale VMap extraction output…"\n  rm -rf Buildings vmaps\n\n  echo "[client:wotlk] Extracting VMap source…"\n  ./vmap4extractor\n\n  [[ -d Buildings ]] || { echo "ERROR: vmap4extractor completed but Buildings/ was not created." >&2; exit 42; }\n  rm -rf vmaps\n'''
if old not in s:
    raise SystemExit('WotLK VMap block not found')
s = s.replace(old, new, 1)
prep.write_text(s)

b = build.read_text()
b2 = b.replace('<string>1.5.90</string>', '<string>1.5.91</string>', 1).replace('<string>1590</string>', '<string>1591</string>', 1)
if b2 == b:
    raise SystemExit('Build.command version markers not found')
build.write_text(b2)

n = notes.read_text()
notes.write_text('''# v1.5.91 — WotLK VMap Retry Cleanup\n\n- Fixes `Your output directory seems to be polluted` when rerunning WotLK Prepare Client.\n- Automatically removes stale `Buildings/` and `vmaps/` before `vmap4extractor`.\n- Makes Prepare Client repeatable after interrupted or failed extraction attempts.\n- Release artifacts are uploaded as a folder so the downloaded ZIP contains the project directly instead of another ZIP.\n\n''' + n)

print('Applied v1.5.91 WotLK VMap cleanup')

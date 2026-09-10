from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'Scripts/prepare-client.sh'
s = p.read_text()
start = s.index('  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.')
end = s.index('\n\n  cd "$CLIENTDIR"', start)
replacement = '''  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.\n  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do\n    [[ -x "$PR/bin/$tool" ]] || { echo "ERROR: Missing WotLK extractor '$tool'. Core binaries exist, but the extractor target was not produced. Use WotLK → Rebuild Core + PlayerBots once with WoWCC 1.5.87 or newer. See Core Build log in WoWCC Logs." >&2; exit 41; }\n    cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"\n    chmod +x "$CLIENTDIR/$tool"\n  done'''
s = s[:start] + replacement + s[end:]
p.write_text(s)
print('Normalized prepare-client block for v1.5.89 patcher')

from pathlib import Path

p = Path('Scripts/prepare-client.sh')
s = p.read_text()
old = '''elif [[ "$PROFILE" == "cataclysm" || "$PROFILE" == "mop" ]]; then
  # Trinity/SkyFire community branches normally ship extractor binaries with the core.
  # Copy whichever tools the selected branch actually built, then run the compatible ones.
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator vmapextractor; do
    [[ -x "$PR/bin/$tool" ]] && cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
  done
  cd "$CLIENTDIR"
  [[ -x ./mapextractor ]] && ./mapextractor || true
  [[ -x ./vmap4extractor ]] && ./vmap4extractor || true
  [[ -x ./vmapextractor ]] && ./vmapextractor || true
  if [[ -x ./vmap4assembler && -d Buildings ]]; then mkdir -p vmaps; ./vmap4assembler Buildings vmaps || true; fi
  [[ -x ./mmaps_generator ]] && { mkdir -p mmaps; ./mmaps_generator || true; }
  for d in dbc db2 maps vmaps mmaps gt Cameras cameras; do
    [[ -d "$CLIENTDIR/$d" ]] && { rm -rf "$PR/data/$d"; cp -R "$CLIENTDIR/$d" "$PR/data/$d"; }
  done
  echo "$PROFILE client realmlist configured and available extractor output copied."
'''
new = '''elif [[ "$PROFILE" == "cataclysm" ]]; then
  echo "[client:cataclysm] Preparing Cataclysm 4.3.4 client/server data…"
  mkdir -p "$PR/data" "$PR/data/db2"

  # Trinity 4.3.4 mapextractor is the tool that extracts BOTH dbc/db2 and maps.
  # This is mandatory for Cata because the Collection Browser builds its catalog
  # from Item.db2 + Item-sparse.db2.
  [[ -x "$PR/bin/mapextractor" ]] || {
    echo "ERROR: Cataclysm mapextractor is missing from $PR/bin. Reinstall the Cataclysm core first so extractor tools are built." >&2
    exit 72
  }
  cp -f "$PR/bin/mapextractor" "$CLIENTDIR/mapextractor"
  chmod +x "$CLIENTDIR/mapextractor"

  # Copy optional geometry tools if the core built them. Their failure must not
  # hide the mandatory DB2 extraction result.
  for tool in vmap4extractor vmap4assembler mmaps_generator vmapextractor; do
    if [[ -x "$PR/bin/$tool" ]]; then
      cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
      chmod +x "$CLIENTDIR/$tool"
    fi
  done

  cd "$CLIENTDIR"
  echo "[client:cataclysm] Extracting DBC/DB2 and maps with mapextractor…"
  ./mapextractor

  find_cata_db2() {
    local wanted="$1" found=""
    found="$(find "$CLIENTDIR" -type f -iname "$wanted" -print 2>/dev/null | head -n 1 || true)"
    [[ -n "$found" ]] || return 1
    printf '%s\\n' "$found"
  }

  ITEM_DB2="$(find_cata_db2 'Item.db2' || true)"
  SPARSE_DB2="$(find_cata_db2 'Item-sparse.db2' || true)"
  [[ -n "$ITEM_DB2" ]] || {
    echo "ERROR: mapextractor finished but Item.db2 was not produced. Verify this is a complete Cataclysm 4.3.4 (15595) client." >&2
    exit 73
  }
  [[ -n "$SPARSE_DB2" ]] || {
    echo "ERROR: mapextractor finished but Item-sparse.db2 was not produced. Verify this is a complete Cataclysm 4.3.4 (15595) client with locale MPQ data." >&2
    exit 74
  }

  # Normalize the two catalog-critical DB2 files into one deterministic managed
  # location regardless of whether upstream extractor emitted dbc/ or db2/.
  cp -f "$ITEM_DB2" "$PR/data/db2/Item.db2"
  cp -f "$SPARSE_DB2" "$PR/data/db2/Item-sparse.db2"

  [[ -s "$PR/data/db2/Item.db2" ]] || { echo "ERROR: Managed Item.db2 copy is empty." >&2; exit 75; }
  [[ -s "$PR/data/db2/Item-sparse.db2" ]] || { echo "ERROR: Managed Item-sparse.db2 copy is empty." >&2; exit 76; }

  for d in dbc db2 maps gt Cameras cameras; do
    if [[ -d "$CLIENTDIR/$d" ]]; then
      rm -rf "$PR/data/$d"
      cp -R "$CLIENTDIR/$d" "$PR/data/$d"
    fi
  done
  # Re-copy normalized files after whole-directory sync in case upstream used db2/.
  mkdir -p "$PR/data/db2"
  cp -f "$ITEM_DB2" "$PR/data/db2/Item.db2"
  cp -f "$SPARSE_DB2" "$PR/data/db2/Item-sparse.db2"

  [[ -x ./vmap4extractor ]] && ./vmap4extractor || true
  [[ -x ./vmapextractor ]] && ./vmapextractor || true
  if [[ -x ./vmap4assembler && -d Buildings ]]; then mkdir -p vmaps; ./vmap4assembler Buildings vmaps || true; fi
  [[ -x ./mmaps_generator ]] && { mkdir -p mmaps; ./mmaps_generator || true; }
  for d in vmaps mmaps; do
    [[ -d "$CLIENTDIR/$d" ]] && { rm -rf "$PR/data/$d"; cp -R "$CLIENTDIR/$d" "$PR/data/$d"; }
  done

  echo "[client:cataclysm] READY — Item.db2 and Item-sparse.db2 extracted and copied to managed data/db2/."
  echo "Cataclysm client data prepared; Repair Realm can now build the full item catalog."
elif [[ "$PROFILE" == "mop" ]]; then
  # Keep the MoP path independent; do not apply Cataclysm DB2 requirements to it.
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator vmapextractor; do
    [[ -x "$PR/bin/$tool" ]] && cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
  done
  cd "$CLIENTDIR"
  [[ -x ./mapextractor ]] && ./mapextractor || true
  [[ -x ./vmap4extractor ]] && ./vmap4extractor || true
  [[ -x ./vmapextractor ]] && ./vmapextractor || true
  if [[ -x ./vmap4assembler && -d Buildings ]]; then mkdir -p vmaps; ./vmap4assembler Buildings vmaps || true; fi
  [[ -x ./mmaps_generator ]] && { mkdir -p mmaps; ./mmaps_generator || true; }
  for d in dbc db2 maps vmaps mmaps gt Cameras cameras; do
    [[ -d "$CLIENTDIR/$d" ]] && { rm -rf "$PR/data/$d"; cp -R "$CLIENTDIR/$d" "$PR/data/$d"; }
  done
  echo "mop client realmlist configured and available extractor output copied."
'''
if old not in s:
    raise SystemExit('prepare-client community block not found')
s = s.replace(old, new, 1)
p.write_text(s)

b = Path('Build.command')
bs = b.read_text()
bs = bs.replace('<string>1.5.84</string>', '<string>1.5.85</string>', 1)
bs = bs.replace('<string>1584</string>', '<string>1585</string>', 1)
b.write_text(bs)

rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.85 — Cataclysm Client DB2 Extraction Fix\n\n- Makes Cataclysm mapextractor mandatory instead of silently ignoring a missing/failed extractor.\n- Validates that Item.db2 and Item-sparse.db2 were actually produced.\n- Finds those DB2 files regardless of extractor output folder and normalizes them into managed data/db2/.\n- Keeps Cata Repair Realm dependent on real extracted 4.3.4 client data instead of failing later with a misleading missing-file error.\n- Leaves MoP preparation independent from the Cataclysm DB2 rules.\n\n'''
if not notes.startswith('# v1.5.85'):
    rn.write_text(header + notes)

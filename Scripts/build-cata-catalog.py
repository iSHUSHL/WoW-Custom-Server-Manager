#!/usr/bin/env python3
import argparse
import os
import struct
import sys
from pathlib import Path

ITEM_FMT = "niiiiiii"
ITEM_SPARSE_FMT = "niiiffiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiifiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiisssssiiiiiiiiiiiiiiiiiiiiiifiiifii"


def find_file(root: Path, wanted: str):
    wanted = wanted.lower()
    for p in root.rglob('*'):
        if p.is_file() and p.name.lower() == wanted:
            return p
    return None


def read_db2(path: Path, fmt: str):
    data = path.read_bytes()
    if len(data) < 20:
        raise RuntimeError(f"{path.name} is too small")
    magic = data[:4]
    if magic not in (b'WDB2', b'WDBC'):
        raise RuntimeError(f"Unsupported {path.name} magic {magic!r}; expected WDB2/WDBC")
    records, fields, record_size, string_size = struct.unpack_from('<4I', data, 4)
    expected = len(fmt) * 4
    if record_size != expected:
        raise RuntimeError(f"{path.name} record size {record_size} does not match expected Cataclysm layout {expected}")
    header_size = 48 if magic == b'WDB2' else 20
    records_end = header_size + records * record_size
    strings_end = records_end + string_size
    if strings_end > len(data):
        raise RuntimeError(f"{path.name} is truncated")
    string_block = data[records_end:strings_end]

    def get_string(offset: int):
        if offset <= 0 or offset >= len(string_block):
            return ''
        end = string_block.find(b'\0', offset)
        if end < 0:
            end = len(string_block)
        return string_block[offset:end].decode('utf-8', errors='replace')

    rows = []
    for r in range(records):
        base = header_size + r * record_size
        vals = []
        for i, code in enumerate(fmt):
            off = base + i * 4
            if code == 'f':
                vals.append(struct.unpack_from('<f', data, off)[0])
            else:
                raw = struct.unpack_from('<I', data, off)[0]
                vals.append(get_string(raw) if code == 's' else raw)
        rows.append(vals)
    return rows


def s32(v):
    v = int(v)
    return v - 0x100000000 if v & 0x80000000 else v


def sql_str(value):
    s = str(value or '')
    return "'" + s.replace('\\', '\\\\').replace("'", "''").replace('\x00', '') + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data-root', required=True)
    ap.add_argument('--output', required=True)
    args = ap.parse_args()

    root = Path(args.data_root)
    item_path = find_file(root, 'Item.db2')
    sparse_path = find_file(root, 'Item-sparse.db2')
    if not item_path or not sparse_path:
        missing = []
        if not item_path: missing.append('Item.db2')
        if not sparse_path: missing.append('Item-sparse.db2')
        raise SystemExit('ERROR: Missing Cataclysm DB2 file(s): ' + ', '.join(missing) + '. Run Prepare Client Data first and make sure the 4.3.4 extractor copied db2/.')

    items = {int(r[0]): r for r in read_db2(item_path, ITEM_FMT)}
    sparse_rows = read_db2(sparse_path, ITEM_SPARSE_FMT)
    if len(sparse_rows) < 10000:
        raise SystemExit(f'ERROR: Item-sparse.db2 only contains {len(sparse_rows)} records; expected a full Cataclysm client data set.')

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    cols = [
        'entry','name','Quality','class','subclass','InventoryType','ItemLevel','itemset','AllowableClass',
        'RequiredLevel','RequiredSkill','RequiredSkillRank','RequiredSpell','RequiredReputationFaction','RequiredReputationRank',
        'SellPrice','Stackable','Bonding','Description','Delay',
        'stat_type1','stat_value1','stat_type2','stat_value2','stat_type3','stat_value3','stat_type4','stat_value4','stat_type5','stat_value5',
        'stat_type6','stat_value6','stat_type7','stat_value7','stat_type8','stat_value8','stat_type9','stat_value9','stat_type10','stat_value10',
        'spellid_1','spelltrigger_1','spellid_2','spelltrigger_2','spellid_3','spelltrigger_3','spellid_4','spelltrigger_4','spellid_5','spelltrigger_5',
        'socketcolor_1','socketcontent_1','socketcolor_2','socketcontent_2','socketcolor_3','socketcontent_3','socketbonus'
    ]

    with out.open('w', encoding='utf-8') as f:
        f.write('DROP TABLE IF EXISTS world.wowcc_item_template;\n')
        f.write('CREATE TABLE world.wowcc_item_template (\n')
        f.write(' entry INT UNSIGNED NOT NULL PRIMARY KEY, name TEXT NOT NULL, Quality INT NOT NULL, class INT NOT NULL, subclass INT NOT NULL, InventoryType INT NOT NULL, ItemLevel INT NOT NULL, itemset INT NOT NULL, AllowableClass BIGINT NOT NULL,\n')
        f.write(' RequiredLevel INT NOT NULL, RequiredSkill INT NOT NULL, RequiredSkillRank INT NOT NULL, RequiredSpell INT NOT NULL, RequiredReputationFaction INT NOT NULL, RequiredReputationRank INT NOT NULL, SellPrice BIGINT NOT NULL, Stackable INT NOT NULL, Bonding INT NOT NULL, Description TEXT NOT NULL, Delay INT NOT NULL,\n')
        for i in range(1,11):
            f.write(f' stat_type{i} INT NOT NULL, stat_value{i} INT NOT NULL,\n')
        for i in range(1,6):
            f.write(f' spellid_{i} INT NOT NULL, spelltrigger_{i} INT NOT NULL,\n')
        f.write(' socketcolor_1 INT NOT NULL, socketcontent_1 INT NOT NULL, socketcolor_2 INT NOT NULL, socketcontent_2 INT NOT NULL, socketcolor_3 INT NOT NULL, socketcontent_3 INT NOT NULL, socketbonus INT NOT NULL\n')
        f.write(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n')

        batch = []
        for s in sparse_rows:
            iid = int(s[0])
            it = items.get(iid)
            cls = int(it[1]) if it else 0
            sub = int(it[2]) if it else 0
            inv = int(s[9]) or (int(it[6]) if it else 0)
            row = [
                iid, sql_str(s[99]), int(s[1]), cls, sub, inv, int(s[12]), int(s[113]), s32(s[10]),
                s32(s[13]), int(s[14]), int(s[15]), s32(s[16]), int(s[19]), int(s[20]), int(s[8]), s32(s[22]), s32(s[98]), sql_str(s[103]), int(s[66])
            ]
            for i in range(10):
                row.extend([s32(s[24+i]), s32(s[34+i])])
            for i in range(5):
                row.extend([s32(s[68+i]), s32(s[73+i])])
            for i in range(3):
                row.extend([s32(s[118+i]), int(s[121+i])])
            row.append(s32(s[124]))
            batch.append('(' + ','.join(str(x) if not isinstance(x, str) or not x.startswith("'") else x for x in row) + ')')
            if len(batch) >= 200:
                f.write('INSERT INTO world.wowcc_item_template (' + ','.join(cols) + ') VALUES\n' + ',\n'.join(batch) + ';\n')
                batch.clear()
        if batch:
            f.write('INSERT INTO world.wowcc_item_template (' + ','.join(cols) + ') VALUES\n' + ',\n'.join(batch) + ';\n')
        f.write('CREATE INDEX idx_wowcc_catalog_quality ON world.wowcc_item_template(Quality);\n')
        f.write('CREATE INDEX idx_wowcc_catalog_level ON world.wowcc_item_template(ItemLevel);\n')
        f.write('CREATE INDEX idx_wowcc_catalog_set ON world.wowcc_item_template(itemset);\n')

    print(f'Built Cataclysm catalog SQL from {len(sparse_rows)} Item-sparse.db2 rows and {len(items)} Item.db2 rows')

if __name__ == '__main__':
    main()

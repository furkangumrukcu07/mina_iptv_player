#!/bin/bash
# Usage: ./tool/i18n_fill_chunk.sh kLocalePartialZh zh-CN 0 50
set -euo pipefail
cd "$(dirname "$0")/.."
MAP="$1"
TARGET="$2"
OFFSET="${3:-0}"
LIMIT="${4:-50}"
tool/.i18n_venv/bin/python3 - "$MAP" "$TARGET" "$OFFSET" "$LIMIT" <<'PY'
import sys
from pathlib import Path
from tool.i18n_fill_missing import (
    parse_en,
    parse_map_block,
    translate_batch,
    inject_into_map,
    FILE_FOR,
    dart_quote,
)

map_name, target, offset_s, limit_s = sys.argv[1:5]
offset, limit = int(offset_s), int(limit_s)
en = parse_en()
path = FILE_FOR[map_name]
content = path.read_text(encoding="utf-8")
existing = parse_map_block(content, map_name)
missing = sorted(k for k in en if k not in existing)
batch = missing[offset : offset + limit]
if not batch:
    print(f"{map_name}: nothing to do at offset {offset}")
    sys.exit(0)
print(f"{map_name}: batch {offset}-{offset+len(batch)} / {len(missing)}")
translated = translate_batch([en[k] for k in batch], target)
additions = dict(zip(batch, translated))
content = inject_into_map(content, map_name, additions)
path.write_text(content, encoding="utf-8")
print(f"added {len(additions)} keys")
PY

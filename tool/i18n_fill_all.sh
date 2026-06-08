#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PY=tool/.i18n_venv/bin/python3
SCRIPT=tool/i18n_fill_missing.py

run() {
  echo "======== $(date) $1 ========"
  "$PY" "$SCRIPT" "$1" || echo "FAILED $1"
}

run kLocalePartialZh
run kLocalePartialRu
run kLocalePartialKo
run kLocalePartialHe
run kLocalePartialDa
run kLocalePartialSv
run kLocalePartialHi
run kLocalePartialTh
run kLocalePartialIt
run kLocalePartialPt
run kLocalePartialId

echo "======== DONE $(date) ========"

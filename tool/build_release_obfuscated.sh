#!/usr/bin/env bash
# Obfuscated release: Dart (isim karmaşası) + Android R8 (build.gradle.kts).
# Sembol haritasını saklayın; crash stack decode için gerekir.
#
# Play Integrity API anahtarı: tool/secrets/play_integrity.env (gitignore).
# android/app/build.gradle.kts bu dosyayı okuyup dart-define olarak Gradle derlemesine ekler;
# ekstra --dart-define gerekmez.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SYM_DIR="${ROOT}/build/app/outputs/symbols"
mkdir -p "$SYM_DIR"

MODE="${1:-aab}"
shift || true

if [[ "$MODE" == "apk" ]]; then
  flutter build apk --release --obfuscate --split-debug-info="$SYM_DIR" "$@"
else
  flutter build appbundle --release --obfuscate --split-debug-info="$SYM_DIR" "$@"
fi

echo ""
echo "Sembol dizini (yedekleyin): $SYM_DIR"
echo "AAB: flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols"
echo "APK: flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols"

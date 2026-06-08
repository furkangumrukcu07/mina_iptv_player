#!/usr/bin/env python3
"""Report translation key counts vs English base."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "lib" / "core" / "i18n"


def parse_map(marker: str, content: str) -> set[str]:
    m = re.search(rf"const Map<String, String> {marker} = \{{", content)
    if not m:
        return set()
    depth = 0
    sub_start = content.find("{", m.start())
    for j in range(sub_start, len(content)):
        if content[j] == "{":
            depth += 1
        elif content[j] == "}":
            depth -= 1
            if depth == 0:
                section = content[sub_start : j + 1]
                return {mm.group(1) for mm in re.finditer(r"'([^']+)'\s*:", section)}
    return set()


def main() -> None:
    en = parse_map("_en", (I18N / "app_translations.dart").read_text(encoding="utf-8"))
    partials = (I18N / "locale_partials.dart").read_text(encoding="utf-8")
    for path, name in [
        (I18N / "locale_es.dart", "kLocalePartialEs"),
        (I18N / "locale_ja.dart", "kLocalePartialJa"),
    ]:
        keys = parse_map(name, path.read_text(encoding="utf-8"))
        print(f"{name}: {len(keys)}/{len(en)} missing {len(en - keys)}")
    for name in sorted(set(re.findall(r"kLocalePartial\w+", partials))):
        if name in ("kLocalePartialEs", "kLocalePartialJa"):
            continue
        keys = parse_map(name, partials)
        print(f"{name}: {len(keys)}/{len(en)} missing {len(en - keys)}")


if __name__ == "__main__":
    main()

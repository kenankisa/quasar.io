"""Extract translation key additions from agent transcript StrReplace on lang_service."""
import json
import re
from pathlib import Path

TRANSCRIPTS = Path(
    r"C:\Users\shado\.cursor\projects\c-flutter-uygulamalar-Quasar-io-quasar-io\agent-transcripts"
)
MISSING_KEYS = Path(__file__).parent / "missing_keys.txt"

# Load missing keys from dart tool output if present
missing = set()
if MISSING_KEYS.exists():
    missing = {line.strip() for line in MISSING_KEYS.read_text(encoding="utf-8").splitlines() if line.strip()}

# key -> value per locale (later overrides earlier)
locales = ["en", "tr", "de", "ru", "es", "fr"]
found = {loc: {} for loc in locales}

entry_re = re.compile(r"'([^']+)':\s*(?:'((?:\\'|[^'])*)'|\n\s*'((?:\\'|[^'])*)')", re.MULTILINE)

def parse_entries(block: str) -> dict[str, str]:
    out = {}
    # multiline string values
    i = 0
    lines = block.split("\n")
    while i < len(lines):
        m = re.match(r"\s+'([^']+)':\s*(.*)$", lines[i])
        if not m:
            i += 1
            continue
        key, rest = m.group(1), m.group(2).strip()
        if rest.startswith("'") and rest.endswith("',"):
            val = rest[1:-2].replace("\\'", "'")
            out[key] = val
            i += 1
            continue
        if rest == "'":
            parts = []
            i += 1
            while i < len(lines):
                t = lines[i].strip()
                if t.endswith("',"):
                    parts.append(t[:-2])
                    break
                parts.append(t.strip("'"))
                i += 1
            out[key] = "\n".join(parts).replace("\\'", "'")
        i += 1
    return out

for jsonl in TRANSCRIPTS.rglob("*.jsonl"):
    for line in jsonl.read_text(encoding="utf-8", errors="replace").splitlines():
        if "lang_service.dart" not in line or "StrReplace" not in line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecode:
            continue
        content = obj.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for item in content:
            if item.get("type") != "tool_use":
                continue
            inp = item.get("input", {})
            if inp.get("path", "").endswith("lang_service.dart") and "new_string" in inp:
                ns = inp["new_string"]
                # detect locale context from surrounding keys - crude: scan for locale blocks isn't in replace
                entries = parse_entries(ns)
                for k, v in entries.items():
                    # assign to all locales when replace is monolingual chunk - detect by turkish chars?
                    if any(ord(c) > 127 for c in v) and "ü" in v or "ş" in v or "ğ" in v or "ı" in v or "ö" in v or "ç" in v:
                        found["tr"][k] = v
                    elif "Версия" in v or "алмаз" in v.lower():
                        found["ru"][k] = v
                    elif "Versión" in v or "ñ" in v:
                        found["es"][k] = v
                    elif "ä" in v or "ö" in v or "ß" in v or "ü" in v:
                        if "Sürüm" not in v:
                            found["de"][k] = v
                    elif "é" in v or "è" in v or "à" in v:
                        found["fr"][k] = v
                    else:
                        found["en"][k] = v

# print stats
for loc in locales:
    keys = found[loc]
    if missing:
        hit = sum(1 for k in missing if k in keys)
        print(f"{loc}: {len(keys)} total extracted, {hit} match missing list")
    else:
        print(f"{loc}: {len(keys)} total extracted")

# write patch files for missing only
if missing:
    for loc in locales:
        lines = []
        for k in sorted(missing):
            if k in found[loc]:
                v = found[loc][k].replace("'", "\\'")
                if "\n" in v:
                    lines.append(f"      '{k}':\n          '{v.split(chr(10))[0]}'")
                else:
                    lines.append(f"      '{k}': '{v}',")
        out = Path(__file__).parent / f"patch_{loc}.txt"
        out.write_text("\n".join(lines), encoding="utf-8")
        print(f"wrote {out} ({len(lines)} keys)")

    still = [k for k in sorted(missing) if not any(k in found[l] for l in locales)]
    Path(__file__).parent.joinpath("still_missing.txt").write_text("\n".join(still), encoding="utf-8")
    print(f"still missing: {len(still)}")

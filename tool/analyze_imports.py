#!/usr/bin/env python3
"""Analyze lib/ import graph for unused/unreachable dart files."""
import os
import re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
PACKAGE = "quasar_io"

IMPORT_RE = re.compile(
    r"""^(?:import|export)\s+['"]([^'"]+)['"]""", re.MULTILINE
)


def norm(p: Path) -> str:
    return str(p).replace("\\", "/")


def to_package_path(file_path: Path) -> str:
    rel = file_path.relative_to(LIB).as_posix()
    return f"package:{PACKAGE}/{rel}"


def resolve_relative(importer: Path, imp: str) -> Path | None:
    if imp.startswith("package:") or imp.startswith("dart:"):
        return None
    base = importer.parent
    try:
        resolved = (base / imp).resolve()
        if resolved.suffix != ".dart":
            resolved = resolved.with_suffix(".dart")
        if resolved.is_file() and norm(resolved).startswith(norm(LIB)):
            return resolved
    except (OSError, ValueError):
        pass
    return None


def main():
    files = sorted(LIB.rglob("*.dart"))
    file_to_pkg = {f: to_package_path(f) for f in files}
    pkg_to_file = {v: k for k, v in file_to_pkg.items()}

    file_imports: dict[Path, set[Path]] = {}
    imported_pkgs: set[str] = set()

    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        targets: set[Path] = set()
        for m in IMPORT_RE.finditer(text):
            imp = m.group(1)
            if imp.startswith(f"package:{PACKAGE}/"):
                imported_pkgs.add(imp)
                if imp in pkg_to_file:
                    targets.add(pkg_to_file[imp])
            else:
                resolved = resolve_relative(f, imp)
                if resolved:
                    targets.add(resolved)
                    imported_pkgs.add(to_package_path(resolved))
        file_imports[f] = targets

    main_files = [f for f in files if f.name == "main.dart"]
    reachable: set[Path] = set()
    stack = list(main_files)
    while stack:
        f = stack.pop()
        if f in reachable:
            continue
        reachable.add(f)
        for t in file_imports.get(f, ()):
            if t not in reachable:
                stack.append(t)

    never_imported = []
    for f in files:
        pkg = file_to_pkg[f]
        if f.name == "main.dart":
            continue
        if pkg not in imported_pkgs:
            never_imported.append(f)

    unreachable = [f for f in files if f not in reachable]

    # Count imports per file
    import_counts = []
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        imports = len(IMPORT_RE.findall(text))
        lines = text.count("\n") + 1
        import_counts.append((imports, lines, f))

  # Directory structure
    dirs = defaultdict(int)
    for f in files:
        rel = f.relative_to(LIB)
        top = rel.parts[0] if len(rel.parts) > 1 else "(root)"
        dirs[top] += 1

    print(f"TOTAL_FILES={len(files)}")
    print("\n=== DIRECTORY COUNTS ===")
    for d, c in sorted(dirs.items(), key=lambda x: -x[1]):
        print(f"  {d}: {c}")

    print("\n=== NEVER IMPORTED ({}) ===".format(len(never_imported)))
    for f in sorted(never_imported, key=lambda x: norm(x)):
        print(norm(f))

    print("\n=== UNREACHABLE FROM main.dart ({}) ===".format(len(unreachable)))
    for f in sorted(unreachable, key=lambda x: norm(x)):
        print(norm(f))

    print("\n=== HEAVIEST IMPORT COUNTS (top 20) ===")
    for imports, lines, f in sorted(import_counts, reverse=True)[:20]:
        print(f"  imports={imports:3d} lines={lines:5d}  {f.relative_to(ROOT)}")

    print("\n=== LARGEST FILES (top 25) ===")
    for imports, lines, f in sorted(import_counts, key=lambda x: x[1], reverse=True)[:25]:
        print(f"  lines={lines:5d} imports={imports:3d}  {f.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

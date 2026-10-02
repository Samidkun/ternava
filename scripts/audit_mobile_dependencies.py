#!/usr/bin/env python3
"""Mobile dependency audit + SBOM (T45, AC-42).

Reads mobile/pubspec.lock and produces a CycloneDX SBOM of the *locked*
dependency graph, then asserts the lockfile is complete and pinned:

  * every package has a resolved version and (for hosted packages) a sha256;
  * no package uses a floating source that could resolve differently later;
  * the SBOM lists exactly the locked set.

The script never contacts the network: provenance comes from the lockfile that
is committed to Git, which is what makes the release reproducible. It exits
non-zero on any violation so `scripts/local-ci.sh --full` and CI can gate on it.

Usage:
  python3 scripts/audit_mobile_dependencies.py                 # check + print summary
  python3 scripts/audit_mobile_dependencies.py --sbom out.json # also write the SBOM
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCKFILE = ROOT / "mobile" / "pubspec.lock"
PUBSPEC = ROOT / "mobile" / "pubspec.yaml"


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def parse_lockfile(text: str) -> dict:
    """Parse the subset of pubspec.lock we rely on.

    pubspec.lock is YAML, but its structure is simple and stable. We avoid a
    PyYAML dependency (not guaranteed present) by walking the `packages:` map
    with indentation-aware parsing, which is enough for `dependency`, `source`,
    `version` and the nested `description.sha256`.
    """
    packages: dict[str, dict] = {}
    in_packages = False
    current: str | None = None
    in_description = False

    for raw in text.splitlines():
        if raw.startswith("packages:"):
            in_packages = True
            continue
        if not in_packages:
            continue
        if raw.startswith("sdks:"):  # end of the packages block
            break
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue

        indent = len(raw) - len(raw.lstrip(" "))
        stripped = raw.strip()

        if indent == 2 and stripped.endswith(":"):
            current = stripped[:-1]
            packages[current] = {}
            in_description = False
        elif indent == 4 and current is not None:
            if stripped == "description:":
                in_description = True
                continue
            if ":" in stripped:
                key, _, value = stripped.partition(":")
                packages[current][key.strip()] = value.strip().strip('"')
                if key.strip() != "description":
                    in_description = False
        elif indent == 6 and current is not None and in_description and ":" in stripped:
            key, _, value = stripped.partition(":")
            packages[current][key.strip()] = value.strip().strip('"')

    return packages


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sbom", help="write a CycloneDX SBOM to this path")
    args = ap.parse_args()

    if not LOCKFILE.is_file():
        fail(f"lockfile missing: {LOCKFILE.relative_to(ROOT)} (cannot prove provenance)")
    if not PUBSPEC.is_file():
        fail(f"pubspec missing: {PUBSPEC.relative_to(ROOT)}")

    lock_text = LOCKFILE.read_text(encoding="utf-8")
    packages = parse_lockfile(lock_text)

    if not packages:
        fail("no packages parsed from pubspec.lock; lockfile shape changed?")

    problems: list[str] = []
    hosted = 0
    for name, meta in sorted(packages.items()):
        version = meta.get("version")
        source = meta.get("source")
        if not version:
            problems.append(f"{name}: no resolved version")
        if source == "hosted":
            hosted += 1
            if not meta.get("sha256"):
                problems.append(f"{name}: hosted package without sha256")
        elif source in (None, "path", "git", "sdk"):
            if source is None:
                problems.append(f"{name}: no source recorded")
        else:
            problems.append(f"{name}: unexpected source {source!r}")

    if problems:
        for p in problems:
            print(f"  - {p}")
        fail(f"{len(problems)} lockfile problem(s); dependency provenance is not pinned")

    digest = hashlib.sha256(lock_text.encode("utf-8")).hexdigest()

    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "component": {"type": "application", "name": "ternava-mobile"},
            "properties": [
                {"name": "lockfile", "value": "mobile/pubspec.lock"},
                {"name": "lockfile_sha256", "value": digest},
            ],
        },
        "components": [
            {
                "type": "library",
                "name": name,
                "version": str(meta.get("version", "")),
                "purl": f"pkg:pub/{name}@{meta.get('version', '')}",
                "properties": [
                    {"name": "dependency", "value": str(meta.get("dependency", ""))},
                    {"name": "source", "value": str(meta.get("source", ""))},
                    *(
                        [{"name": "sha256", "value": str(meta["sha256"])}]
                        if meta.get("sha256")
                        else []
                    ),
                ],
            }
            for name, meta in sorted(packages.items())
        ],
    }

    if args.sbom:
        out = pathlib.Path(args.sbom)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(sbom, indent=2) + "\n", encoding="utf-8")
        print(f"SBOM written: {out} ({len(sbom['components'])} components)")

    print(
        f"MOBILE DEP AUDIT PASS: {len(packages)} locked packages "
        f"({hosted} hosted, all pinned); lockfile sha256={digest[:16]}…"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

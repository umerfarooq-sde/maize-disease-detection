"""Query OSV for hosted package versions in the committed Flutter lockfile.

No keys, source images or application configuration are read. A failed query is
an audit failure, never a clean result. SDK packages have no independent Pub release.
"""

import argparse
import json
import re
from datetime import UTC, datetime
from pathlib import Path
from urllib.request import Request, urlopen


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    lock = (root / "mobile/pubspec.lock").read_text(encoding="utf-8")
    packages = []
    sdk = []
    for match in re.finditer(
        r"^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  \w+:|^sdks:|\Z)",
        lock,
        re.MULTILINE | re.DOTALL,
    ):
        name, block = match.groups()
        version = re.search(r'^    version: "([^"]+)"$', block, re.MULTILINE)
        if "    source: sdk\n" in block:
            sdk.append(name)
        elif "    source: hosted\n" in block and version:
            packages.append({"package": {"ecosystem": "Pub", "name": name}, "version": version[1]})
        else:
            raise ValueError("Unsupported lockfile package source; audit needs explicit coverage")
    if not packages:
        raise ValueError("No hosted versions found")
    request = Request(
        "https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": packages}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=30) as response:
        result = json.load(response)
    rows = result["results"]
    if len(rows) != len(packages) or any(row.get("next_page_token") for row in rows):
        raise ValueError("Incomplete advisory results; refusing a clean audit claim")
    findings = [
        {**package, "vulnerabilities": row["vulns"]}
        for package, row in zip(packages, rows, strict=True)
        if row.get("vulns")
    ]
    proof = {
        "queriedAtUtc": datetime.now(UTC).isoformat(),
        "provider": "https://api.osv.dev/v1/querybatch",
        "hostedPackages": packages,
        "sdkPackagesNotIndependentPubReleases": sdk,
        "findings": findings,
        "complete": True,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(
        f"OSV: {len(packages)} hosted Flutter packages queried; {len(findings)} affected packages."
    )
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())

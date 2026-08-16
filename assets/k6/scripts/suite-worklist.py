#!/usr/bin/env python3
"""Print suite worklist lines for k6/scripts/run.sh (LOAD / VOLUME / SMOKE / FAIL)."""
import json
import os
import pathlib
import re
import sys


def fail(msg, code=1):
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def warn(msg):
    print("warning: " + msg, file=sys.stderr)


def truthy(value):
    return str(value or "").strip().lower() in ("1", "true", "yes", "on")


def check_rel(rel):
    if not rel or ".." in rel.split("/"):
        fail("refusing path: " + rel)
    if rel.startswith("k6/"):
        fail("pass a path relative to k6/, not %r (use %s)" % (rel, rel[3:]))
    if not (rel.startswith("journeys/") or rel.startswith("composites/")):
        fail(
            "path must be k6-relative under journeys/ or composites/: %s\n"
            "(bare filenames are rejected because the same name can exist in nested folders)"
            % rel
        )
    return rel


def extract(block, name):
    found = re.search(rf"""{name}\s*:\s*['"]([^'"]+)['"]""", block)
    return found.group(1) if found else ""


def extract_csv(block, name):
    found = re.search(rf"{name}\s*:\s*\[(.*?)\]", block, re.S)
    if not found:
        return []
    return re.findall(r"""['"]([^'"]+)['"]""", found.group(1))


def meta_for(root, rel):
    src = (root / rel).read_text(encoding="utf-8")
    match = re.search(r"export\s+const\s+testchimp\s*=\s*\{", src)
    block = ""
    if match:
        start = match.end() - 1
        depth = 0
        for i, ch in enumerate(src[start:], start=start):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    block = src[start : i + 1]
                    break
    return {
        "kind": extract(block, "kind"),
        "types": extract_csv(block, "testTypes"),
        "volumeKind": extract(block, "volumeKind"),
    }


def all_journeys(root):
    journeys = root / "journeys"
    if not journeys.is_dir():
        return []
    return [p.relative_to(root).as_posix() for p in sorted(journeys.rglob("*.js"))]


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    args = [p for p in os.environ.get("TC_SUITE_PATHS", "").split("\n") if p]
    impacted = os.environ.get("IMPACTED") == "1"
    branch = os.environ.get("BRANCH") or ""
    plans = os.environ.get("PLANS") or ""
    strict = truthy(os.environ.get("STRICT"))
    smoke = os.environ.get("SMOKE") == "1"

    files = []
    if impacted:
        if not branch or ".." in branch:
            fail("k6/scripts/run.sh --impacted: set TESTCHIMP_BRANCH_NAME (or run inside git)")
        artifact = (
            str(pathlib.Path(plans) / "smart-smoke" / branch / "related-perf-tests.json")
            if plans
            else ""
        )
        if not artifact or not pathlib.Path(artifact).is_file():
            warn(
                "related-perf-tests.json not found (%s). Running all journeys."
                % (artifact or "no plans root")
            )
            if strict:
                return 1
            files = all_journeys(root)
        else:
            try:
                data = json.loads(pathlib.Path(artifact).read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                fail("related-perf-tests.json is not valid JSON (%s): %s" % (artifact, exc))
            if data.get("schemaVersion") != 1:
                fail("unsupported related-perf-tests schemaVersion")
            files = [
                str(item.get("file") or "")
                for item in (data.get("selected") or [])
                if item.get("file")
            ]
            if not files:
                # run-qa writes this file when k6/journeys exists, including
                # selected: [] when the PR hits no journeys. That means skip,
                # not the full suite.
                warn(
                    "related-perf-tests.json has selected: [] (%s). Nothing to run."
                    % artifact
                )
    elif not args:
        files = all_journeys(root)
    else:
        files = args

    for rel in files:
        check_rel(rel)
        if not (root / rel).is_file():
            print("FAIL\t%s\tmissing" % rel)
            continue
        info = meta_for(root, rel)
        types = info["types"]
        is_volume = "volume" in types
        is_load = "load" in types or not types
        if info["kind"] == "composite" and is_volume:
            print("FAIL\t%s\tcomposite+volume" % rel)
            continue
        if smoke:
            print("SMOKE\t%s" % rel)
            continue
        if is_load:
            print("LOAD\t%s" % rel)
        if is_volume:
            if not info["volumeKind"]:
                print("FAIL\t%s\tmissing-volumeKind" % rel)
            else:
                print("VOLUME\t%s\t%s" % (rel, info["volumeKind"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Extract export const testchimp = {...} fields as shell assignments."""
import re
import shlex
import sys


def main() -> int:
    if len(sys.argv) < 2:
        return 0
    src = open(sys.argv[1], encoding="utf-8").read()
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

    def quoted(name: str) -> str:
        found = re.search(rf"""{name}\s*:\s*['"]([^'"]+)['"]""", block)
        return found.group(1) if found else ""

    def csv(name: str) -> str:
        found = re.search(rf"{name}\s*:\s*\[(.*?)\]", block, re.S)
        if not found:
            return ""
        return ",".join(re.findall(r"""['"]([^'"]+)['"]""", found.group(1)))

    def emit(name: str, value: str) -> None:
        if value:
            print(f"{name}={shlex.quote(value)}")

    emit("EXTRACTED_PERF_ID", quoted("id"))
    emit("EXTRACTED_PERF_KIND", quoted("kind"))
    emit("EXTRACTED_PERF_TEST_TYPES", csv("testTypes"))
    emit("EXTRACTED_PERF_SCENARIOS", csv("scenarios"))
    emit("EXTRACTED_PERF_MEMBERS", csv("members"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

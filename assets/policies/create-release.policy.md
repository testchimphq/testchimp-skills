---
workflow-id: create-release
version: 1.0.0
---

[SEED POLICY - REQUIRE USER DECISIONS TO LOCK-IN]

### Summary

# Fill after lock-in. Until then this file is a skeleton only — agents must not
# treat blank keys as decisions.

### Tag convention

# unset until locked — e.g. semver major.minor.patch ; optional prefix (release-)

### Scope default

# unset until locked
# MAJOR: full
# MINOR: changed
# HOTFIX: changed

### By release type

## MAJOR

# unset until locked:
# - upkeep:                 # yes | no
# - suite_execution:        # full | smart-smoke  (CI find/link is runtime preference, not a policy value)
# - explorechimp:           # yes | no
# - perf:                   # upkeep-and-run | run | never
# - security_static:        # yes | no
# - security_dast:          # ask | never

## MINOR

# unset until locked:
# - upkeep:
# - suite_execution:
# - explorechimp:
# - perf:
# - security_static:
# - security_dast:

## HOTFIX

# unset until locked:
# - upkeep:
# - suite_execution:
# - explorechimp:
# - perf:
# - security_static:
# - security_dast:

### Subflows

# Catalog ids agents may nest once policy enables them:
# upkeep, execute-tests, run-smart-smoke, run-explorechimp,
# upkeep-perf, run-perf-tests, run-release-check

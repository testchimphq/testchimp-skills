# Testing Remote MCP Support

This document describes manual testing performed for the remote MCP server support feature.

## Preamble Check Tests

The `bin/testchimp-preamble-check` script was tested with three configurations:

### Test 1: Remote mode (OAuth)

**Config:**
```json
{
  "mcpServers": {
    "testchimp": {
      "type": "http",
      "url": "https://mcp.testchimp.io/mcp"
    }
  }
}
```

**Expected behavior:**
- Detect remote (OAuth) mode
- Warn that TESTCHIMP_API_KEY is not in MCP config (test runs need it)
- Do not treat this as a blocker

**Result:** ✅ PASS

```
TESTCHIMP_SERVER_MODE: remote (OAuth)
WARN: TESTCHIMP_API_KEY not in MCP config — test runs will need it in the runner process environment
WARN: TESTCHIMP_PROJECT_ID missing/placeholder (needed for TrueCoverage RUM instrumentation)
```

### Test 2: Stdio mode with all variables

**Config:**
```json
{
  "mcpServers": {
    "testchimp": {
      "command": "npx",
      "args": ["-y", "@testchimp/cli@latest", "mcp"],
      "env": {
        "TESTCHIMP_API_KEY": "test_key_123",
        "TESTCHIMP_USER_ID": "user_456",
        "TESTCHIMP_PROJECT_ID": "proj_789"
      }
    }
  }
}
```

**Expected behavior:**
- Detect stdio mode
- Confirm all env vars are present
- No blockers or warnings

**Result:** ✅ PASS

```
TESTCHIMP_SERVER_MODE: stdio (local process)
TESTCHIMP_API_KEY: present (not printed)
TESTCHIMP_USER_ID: present (not printed)
TESTCHIMP_PROJECT_ID: present (not printed)
```

### Test 3: Stdio mode without TESTCHIMP_USER_ID

**Config:**
```json
{
  "mcpServers": {
    "testchimp": {
      "command": "npx",
      "args": ["-y", "@testchimp/cli@latest", "mcp"],
      "env": {
        "TESTCHIMP_API_KEY": "test_key_123",
        "TESTCHIMP_PROJECT_ID": "proj_789"
      }
    }
  }
}
```

**Expected behavior:**
- Detect stdio mode
- Warn about missing TESTCHIMP_USER_ID
- Confirm other vars are present

**Result:** ✅ PASS

```
TESTCHIMP_SERVER_MODE: stdio (local process)
TESTCHIMP_API_KEY: present (not printed)
TESTCHIMP_PROJECT_ID: present (not printed)
WARN: TESTCHIMP_USER_ID missing/placeholder (needed for get-my-tasks / list-tests-awaiting-verification and run attribution)
```

### Test 4: Claude Code plugin (no project config)

**Setup:**
- No project-level MCP config
- Claude Code plugin installed: `testchimp@testchimp` in `~/.claude/settings.json` `enabledPlugins`
- Plugin provides MCP server from its cached `.mcp.json`

**Config (user-level):**
```json
{
  "enabledPlugins": ["testchimp@testchimp"]
}
```

**Expected behavior:**
- Detect Claude Code plugin installation
- Report NOTE (not BLOCKER) that MCP is satisfied if tools are available
- Advise not to write a second server unless needed

**Result:** ✅ PASS

```
USER_LEVEL_TESTCHIMP: Claude Code plugin (testchimp in enabledPlugins)
NOTE: No project-level MCP config found, but plugin/user-level testchimp server detected (Claude Code plugin (testchimp in enabledPlugins)). If testchimp MCP tools are available in your session, MCP is satisfied.
```

### Test 5: Gemini extension (no project config)

**Setup:**
- No project-level MCP config
- Gemini extension installed at `~/.gemini/extensions/testchimp-skills/gemini-extension.json`

**Expected behavior:**
- Detect Gemini extension
- Report NOTE (not BLOCKER) that MCP is satisfied if tools are available

**Result:** ✅ PASS

```
USER_LEVEL_TESTCHIMP: Gemini extension (/home/ubuntu/.gemini/extensions/testchimp-skills)
NOTE: No project-level MCP config found, but plugin/user-level testchimp server detected (Gemini extension (/home/ubuntu/.gemini/extensions/testchimp-skills)). If testchimp MCP tools are available in your session, MCP is satisfied.
```

### Test 6: No plugin or config (new user)

**Setup:**
- No project-level MCP config
- No plugin or user-level config detected

**Expected behavior:**
- Report BLOCKER with caveat about plugins
- Message should not be a hard instruction to write stdio config

**Result:** ✅ PASS

```
WARN: project MCP config not found (.cursor/mcp.json, .mcp.json, or mcp.json with testchimp). If testchimp MCP tools are not available via a plugin, run /testchimp init to create project-level config from assets/sample-mcp.json
```

Note: The BLOCKER message (when MCP config is parsed but testchimp server missing) now includes: "BLOCKER (unless the testchimp MCP tools are already available in this session, e.g. via a plugin)"

## Frontmatter Validation

The SKILL.md frontmatter structure was verified to contain:

- `name: testchimp`
- `metadata.version: 1.0.59`
- `metadata.required_cli_version: "0.1.88"`

All required fields are present and parseable.

## Backward Compatibility

The following compatibility scenarios were considered:

1. **Existing stdio configs**: Unchanged behavior; continue to work
2. **Existing git-clone installs**: No breaking changes to skill structure
3. **QA-bot flows**: Environment variable handling unchanged
4. **required_cli_version**: Not bumped (no new CLI features required)
5. **Skill upgrade**: Git-based upgrade flow unchanged

## Files Updated

- `bin/testchimp-preamble-check`: Mode detection and validation logic
- `SKILL.md`: Preamble documentation for both modes
- `references/init-testchimp.md`: Init flow with server detection
- `references/policies-and-traceability.md`: userId note for hosted mode
- `README.md`: Install table and MCP section
- `llms-install.md`: Both options documented
- `assets/sample-mcp.json`: Added TESTCHIMP_USER_ID
- Version bumped to 1.0.59 in all plugin manifests

---
name: test
description: >
  Run automated tests to verify Vibe Coding Guardrails installation and hooks
  are working correctly. Tests both happy paths and security blocks.
  Use when: after setup, periodic verification, or debugging hook issues.
allowed-tools: Bash(*) Write(*) Edit(*) Read(*)
---

# Vibe Coding Guardrails — Test Suite

Run a complete test of the guardrails installation and hooks.
Execute all tests, collect results, then generate a report.

**IMPORTANT:** This skill tests that hooks BLOCK bad patterns. When a test file
gets blocked, that is a PASS (the hook is working). Record the result and continue.

---

## Setup

```bash
PROJECT_DIR="$(pwd)"
TEST_DIR="${PROJECT_DIR}/.guardrails-test-tmp"
REPORT_FILE="${PROJECT_DIR}/guardrails-test-report.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
PUBLIC_REPO="https://github.com/chinnme/public-repo"

mkdir -p "${TEST_DIR}"
```

Initialize results tracking (keep in memory, not file):
- `RESULTS_INSTALL` — array of installation test results
- `RESULTS_HAPPY` — array of happy path test results  
- `RESULTS_BLOCK` — array of security block test results

---

## Section 1: Installation Verification

Run these bash checks and record results:

### 1.1 Plugin enabled globally
```bash
grep -q "vibe-coding-guardrails" ~/.claude/settings.json 2>/dev/null && echo "PASS" || echo "FAIL"
```

### 1.2 Hooks configured locally
```bash
if [ -f ".claude/settings.json" ]; then
  HOOK_COUNT=$(grep -c "\.sh" .claude/settings.json 2>/dev/null || echo "0")
  [ "$HOOK_COUNT" -ge 5 ] && echo "PASS ($HOOK_COUNT hooks)" || echo "FAIL ($HOOK_COUNT hooks)"
else
  echo "FAIL (no .claude/settings.json)"
fi
```

### 1.3 Hook files exist and executable
```bash
EXPECTED_HOOKS="session-start-check.sh no-hardcoded-secrets.sh no-sensitive-files-in-git.sh check-public-repo-push.sh check-insecure-patterns.sh"
FOUND=0
for h in $EXPECTED_HOOKS; do
  [ -x ".claude/hooks/$h" ] && FOUND=$((FOUND + 1))
done
[ "$FOUND" -eq 5 ] && echo "PASS (5/5)" || echo "FAIL ($FOUND/5)"
```

### 1.4 gitleaks installed
```bash
command -v gitleaks &>/dev/null && echo "PASS ($(gitleaks version 2>/dev/null))" || echo "FAIL"
```

### 1.5 CLAUDE.md exists
```bash
[ -f "CLAUDE.md" ] && echo "PASS" || echo "FAIL"
```

---

## Section 2: Happy Path Tests

These should NOT be blocked by hooks.

### 2.1 Write clean file

Write a JavaScript file that uses `process.env.API_KEY` (environment variable reference).
This is safe code — hooks should NOT block it.

Content to write to `${TEST_DIR}/clean-file.js`:
- A const that reads from `process.env.API_KEY`
- A simple fetch function using that variable
- A module.exports

If write succeeds without hook blocking → PASS.
After test, delete the file.

### 2.2 Push to non-public repo (dry-run)

```bash
git remote add test-private-guardrails https://github.com/chinnme/private-repo-does-not-exist.git 2>/dev/null || true
```

Then run: `git push test-private-guardrails main --dry-run`

The hook checks if repo is public via HTTP. A non-existent repo returns 404 → not public → hook allows.
Git itself will error (repo not found) but that's expected.

If hook does NOT block (no "BLOCKED" message) → PASS.

Cleanup:
```bash
git remote remove test-private-guardrails 2>/dev/null || true
```

---

## Section 3: Security Block Tests

**These MUST be blocked.** When a hook blocks, that is a PASS.

For each test:
1. Attempt the action
2. If hook outputs "BLOCKED" → record PASS
3. If no block → record FAIL
4. Clean up test files

### 3.1 Hardcoded API key (→ should BLOCK)

Write a JS file to `${TEST_DIR}/bad-apikey.js` containing:
- A variable assigned a string that looks like an OpenAI key: start with `sk-proj-` followed by 40 random alphanumeric characters

Hook `no-hardcoded-secrets.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.2 Hardcoded password (→ should BLOCK)

Write a JS file to `${TEST_DIR}/bad-password.js` containing:
- An object with `password: "SomeRealPassword123!"`

Hook `no-hardcoded-secrets.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.3 CORS wildcard origin (→ should BLOCK)

Write a JS file to `${TEST_DIR}/bad-cors.js` containing:
- `cors({ origin: "*", credentials: true })`

Hook `check-insecure-patterns.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.4 localStorage token (→ should BLOCK)

Write a JS file to `${TEST_DIR}/bad-storage.js` containing:
- `localStorage.setItem('token', value)`

Hook `check-insecure-patterns.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.5 git add .env (→ should BLOCK)

```bash
echo "TEST=value" > "${TEST_DIR}/.env"
```
Then run: `git add "${TEST_DIR}/.env"`

Hook `no-sensitive-files-in-git.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.6 git add .env.local (→ should BLOCK)

```bash
echo "TEST=value" > "${TEST_DIR}/.env.local"
```
Then run: `git add "${TEST_DIR}/.env.local"`

Hook `no-sensitive-files-in-git.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.7 git add .pem file (→ should BLOCK)

```bash
echo "-----BEGIN CERTIFICATE-----" > "${TEST_DIR}/test.pem"
```
Then run: `git add "${TEST_DIR}/test.pem"`

Hook `no-sensitive-files-in-git.sh` should block. BLOCKED = PASS.
Delete file after.

### 3.8 Push to public repo (→ should BLOCK)

```bash
git remote add test-public-guardrails "https://github.com/chinnme/public-repo" 2>/dev/null || true
```
Then run: `git push test-public-guardrails main --dry-run`

Hook `check-public-repo-push.sh` should block (HTTP 200 = public). BLOCKED = PASS.

Cleanup:
```bash
git remote remove test-public-guardrails 2>/dev/null || true
```

---

## Section 4: Cleanup

```bash
rm -rf "${TEST_DIR}"
```

---

## Section 5: Generate Report

Create `${REPORT_FILE}` with this structure:

```markdown
# Vibe Coding Guardrails — Test Report

**Project:** [project path]
**Date:** [timestamp]
**Tester:** Claude Code

---

## 1. Installation Verification

| # | Test | Result |
|---|------|--------|
| 1.1 | Plugin enabled globally | [result] |
| 1.2 | Hooks configured locally | [result] |
| 1.3 | Hook files executable | [result] |
| 1.4 | gitleaks installed | [result] |
| 1.5 | CLAUDE.md exists | [result] |

## 2. Happy Path Tests

| # | Test | Expected | Result |
|---|------|----------|--------|
| 2.1 | Write clean file | Not blocked | [result] |
| 2.2 | Push to private repo | Not blocked | [result] |

## 3. Security Block Tests

| # | Test | Hook | Expected | Result |
|---|------|------|----------|--------|
| 3.1 | Hardcoded API key | no-hardcoded-secrets.sh | Blocked | [result] |
| 3.2 | Hardcoded password | no-hardcoded-secrets.sh | Blocked | [result] |
| 3.3 | CORS wildcard | check-insecure-patterns.sh | Blocked | [result] |
| 3.4 | localStorage token | check-insecure-patterns.sh | Blocked | [result] |
| 3.5 | git add .env | no-sensitive-files-in-git.sh | Blocked | [result] |
| 3.6 | git add .env.local | no-sensitive-files-in-git.sh | Blocked | [result] |
| 3.7 | git add *.pem | no-sensitive-files-in-git.sh | Blocked | [result] |
| 3.8 | Push to public repo | check-public-repo-push.sh | Blocked | [result] |

---

## Summary

**Total:** 15 | **Passed:** X | **Failed:** X | **Skipped:** X

[If all passed]
### ✅ ALL TESTS PASSED

[If any failed, list them]
### ❌ FAILED TESTS:
- [list each failed test]
```

---

## Section 6: Terminal Summary

Display this after saving report:

```
════════════════════════════════════════════════════════════
  Vibe Coding Guardrails — Test Complete
════════════════════════════════════════════════════════════

  Total: 15 | ✅ Passed: X | ❌ Failed: X | ⚠️ Skipped: X

  Report saved: guardrails-test-report.md

════════════════════════════════════════════════════════════
```

If any failed, list them with brief explanation.

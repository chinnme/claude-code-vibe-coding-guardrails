---
name: check-before-deploy
description: >
  Run a pre-deploy security checklist before deploying or publishing any project.
  Checks for secrets in git tracking, insecure patterns in code, and missing
  safety files. Use when the user says "check before deploy", "is this safe to
  deploy", "pre-deploy check", or is about to push to a public repo or go live.
allowed-tools: Bash(git *) Bash(grep *) Bash(find *) Bash(ls *) Bash(cat *)
---

# Pre-Deploy Security Checklist

Run through this checklist before any deployment or publishing to a public repository.
Work through each check in order. Report results clearly. Stop and fix any FAIL before proceeding.

---

## Step 1 — Check git is not tracking secrets

```bash
git ls-files | grep -E '\.env$|\.env\.[^e]|\.pem$|\.key$|credentials\.json$|service-account.*\.json$'
```

- If output is **empty** → ✅ PASS
- If output has files → ❌ FAIL: these files are tracked by git and must be removed

If FAIL, tell the user:
> "These files are being tracked by git and may contain secrets. Run `git rm --cached <filename>` to untrack them, add them to `.gitignore`, and commit the change. If they were ever pushed, rotate any credentials in them immediately."

---

## Step 2 — Check .gitignore exists and covers the essentials

```bash
cat .gitignore 2>/dev/null || echo "MISSING"
```

Check that `.gitignore` contains at minimum:
- `.env` (and `.env.*` except `.env.example`)
- `*.pem` and `*.key`
- `node_modules/` or `__pycache__/` (whichever applies)

- If `.gitignore` is missing → ❌ FAIL: create it before deploying
- If entries are missing → ⚠️ WARN: add the missing entries

---

## Step 3 — Scan code for insecure patterns

```bash
grep -rn 'origin[s]\{0,1\}[[:space:]]*[=:][[:space:]]*\[*"*\*"' --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v ".git"
grep -rn 'localStorage\.setItem[[:space:]]*(.*\(token\|auth\|session\|jwt\|credential\|key\|secret\)' --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" . 2>/dev/null | grep -v node_modules | grep -v ".git"
```

- CORS `origin: "*"` found → ❌ FAIL: replace with explicit allowed origins
- `localStorage` storing token/credential found → ❌ FAIL: use `httpOnly` cookie or `sessionStorage`
- Nothing found → ✅ PASS

---

## Step 4 — Check for hardcoded secrets with gitleaks

```bash
gitleaks detect --source . --no-banner 2>&1 | tail -5
```

- Exit 0, no leaks → ✅ PASS
- Leaks found → ❌ FAIL: move secrets to `.env` and reference via environment variables
- gitleaks not installed → ⚠️ WARN: install with `brew install gitleaks`

---

## Step 5 — Summary

Report results in this format:

```
Pre-Deploy Security Checklist
──────────────────────────────
✅ PASS  No secrets tracked by git
✅ PASS  .gitignore covers essential patterns
✅ PASS  No insecure code patterns found
✅ PASS  gitleaks: no hardcoded secrets

Ready to deploy. ✅
```

Or if any item fails:

```
Pre-Deploy Security Checklist
──────────────────────────────
❌ FAIL  .env is tracked by git → untrack it and rotate credentials
✅ PASS  .gitignore covers essential patterns
❌ FAIL  CORS wildcard found in src/server.js line 12
✅ PASS  gitleaks: no hardcoded secrets

Fix the items above before deploying. 🚫
```

**Do not proceed with deployment until all FAIL items are resolved.**

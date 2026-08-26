---
name: check-secrets
description: >
  Verify that no secrets, API keys, passwords, or credentials are present
  in any files before committing to git.
  Use when: about to commit, user asks "is this safe?", or after editing config files.
---

# Check for Secrets Before Committing

When invoked, follow these steps:

## 1. Files to Check

Inspect all files modified in this session, including:
- Config files of any kind (`.json`, `.yaml`, `.yml`, `.toml`, `.ini`, `.env*`)
- All source code files created or modified
- Scripts (`.sh`, `.py`, `.js`, `.ts`)

## 2. Red Flag Patterns

```
password=<real value>              → NOT OK
api_key=<real value>               → NOT OK
secret=<real value>                → NOT OK
token=<real value>                 → NOT OK
Authorization: Bearer <real value> → NOT OK
private_key: |                     → NOT OK if followed by key content
```

**Safe patterns:**
```
password=${DB_PASSWORD}   → OK (environment variable reference)
api_key=process.env.KEY   → OK (env reference)
API_KEY=your-key-here     → OK (placeholder)
```

## 3. Check .gitignore

Verify the following are listed in `.gitignore`:
- `.env` (and `.env.*` except `.env.example`)
- `*.pem`, `*.key`, `*.p12`
- `secrets/`, `credentials/`

If `.gitignore` is missing these entries → notify the user and add them.

## 4. Report Results

Report in this format:

```
✅ No secrets found in checked files.
or
⚠️  Suspicious value found in <filename>:
   - Line XX: <suspicious line (value masked)>
   Recommendation: move this value to .env and reference it via environment variable.
```

**If secrets are found → do not proceed with the commit until the user fixes it.**

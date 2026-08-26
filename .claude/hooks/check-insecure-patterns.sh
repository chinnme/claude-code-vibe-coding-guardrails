#!/usr/bin/env bash
# Hook: check-insecure-patterns.sh
# Trigger: PostToolUse — runs after Claude writes or edits any file
# Purpose: Detect insecure web patterns that gitleaks won't catch:
#          - CORS wildcard (origin: "*") with credentials
#          - Token/session stored in localStorage

set -uo pipefail

# Read file path from stdin (Claude Code sends JSON)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(
  d.get('tool_input', {}).get('file_path') or
  d.get('tool_input', {}).get('path') or
  ''
)
" 2>/dev/null || echo "")

# No path or file doesn't exist → pass
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Only check code files — skip binaries, images, lock files
EXT="${FILE_PATH##*.}"
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs|py|rb|go|java|cs|php|swift|kt) ;;
  *) exit 0 ;;
esac

FOUND_ISSUES=0
MESSAGES=""

# ── Check 1: CORS wildcard origin ────────────────────────────────────────────
# Matches: origin: "*"  /  origin:"*"  /  origins: ["*"]  /  allow_origins=["*"]
if grep -qE 'origin[s]?\s*[=:]\s*[\["]?\s*"\*"' "$FILE_PATH" 2>/dev/null; then
  FOUND_ISSUES=1
  MESSAGES="${MESSAGES}
🚫 BLOCKED: Wildcard CORS origin detected in: $FILE_PATH

   Found: origin \"*\" — this allows any domain to make credentialed requests.

   ✅ Fix: Specify explicit allowed origins instead:
      cors({ origin: [\"https://app.example.com\"] })
"
fi

# ── Check 2: localStorage storing tokens/credentials ─────────────────────────
# Matches: localStorage.setItem("token"  / localStorage.setItem('access_token'
# Also: localStorage["token"] = / localStorage.token =
if grep -qE "localStorage\.(setItem\s*\(\s*['\"].*?(token|auth|session|jwt|credential|key|secret)|(\[|\.)\s*['\"]?(token|auth|session|jwt|credential)['\"]?\s*=)" "$FILE_PATH" 2>/dev/null; then
  FOUND_ISSUES=1
  MESSAGES="${MESSAGES}
🚫 BLOCKED: Token or credential stored in localStorage in: $FILE_PATH

   localStorage is accessible by any JavaScript on the page (XSS risk).

   ✅ Fix: Use httpOnly cookies (server-set) or sessionStorage instead:
      // sessionStorage — cleared when tab closes
      sessionStorage.setItem('token', value)
      // httpOnly cookie — set by server, not accessible via JS at all (preferred)
"
fi

# ── Report ────────────────────────────────────────────────────────────────────
if [ "$FOUND_ISSUES" -eq 1 ]; then
  echo "$MESSAGES" >&2
  exit 2
fi

exit 0

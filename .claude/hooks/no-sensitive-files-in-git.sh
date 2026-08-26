#!/usr/bin/env bash
# Hook: no-sensitive-files-in-git.sh
# Trigger: PreToolUse — runs before Claude executes git commands
# Purpose: Prevent Claude from committing sensitive files to git

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null || echo "")

# Only intercept git add and git commit
if ! echo "$COMMAND" | grep -qE '^git (add|commit)'; then
  exit 0
fi

# Files that must never be committed
BLOCKED_PATTERNS=(
  ".env$"
  ".env\.[^e]"   # .env.local, .env.prod, etc. (but not .env.example)
  "\.pem$"
  "\.key$"
  "\.p12$"
  "\.pfx$"
  "^id_rsa"
  "CLAUDE\.local\.md$"
  "settings\.local\.json$"
)

# Check git add — inspect paths being staged
if echo "$COMMAND" | grep -q "^git add"; then
  PATHS=$(echo "$COMMAND" | sed 's/^git add //')

  for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$PATHS" | grep -qE "$PATTERN"; then
      MATCHED=$(echo "$PATHS" | grep -E "$PATTERN" || true)
      echo "" >&2
      echo "🚫 BLOCKED: Cannot git add a sensitive file." >&2
      echo "   File: $MATCHED" >&2
      echo "" >&2
      echo "💡 This file may contain secrets — it must stay in .gitignore only." >&2
      echo "   If you need a template, use .env.example instead." >&2
      echo "" >&2
      exit 2
    fi
  done
fi

# Check staged files before commit
if echo "$COMMAND" | grep -q "^git commit"; then
  STAGED=$(git diff --cached --name-only 2>/dev/null || true)

  for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
    FOUND=$(echo "$STAGED" | grep -E "$PATTERN" || true)
    if [ -n "$FOUND" ]; then
      echo "" >&2
      echo "🚫 BLOCKED: Sensitive file found in staged files — cannot commit." >&2
      echo "   File: $FOUND" >&2
      echo "" >&2
      echo "💡 Run: git reset HEAD <filename> to unstage the file." >&2
      echo "   Then add the filename to .gitignore." >&2
      echo "" >&2
      exit 2
    fi
  done
fi

exit 0

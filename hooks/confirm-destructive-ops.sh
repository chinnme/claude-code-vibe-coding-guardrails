#!/usr/bin/env bash
# Hook: confirm-destructive-ops.sh
# Trigger: PreToolUse — runs before Claude executes bash commands
# Purpose: Block destructive operations and require explicit user confirmation

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
  exit 0
fi

DANGER_LEVEL=""
REASON=""

# 🔴 Critical: permanent data loss
if echo "$COMMAND" | grep -qiE 'rm -rf|DROP TABLE|TRUNCATE|DELETE FROM [a-z_]+ *;|kubectl delete.*(prod|production)|terraform destroy'; then
  DANGER_LEVEL="CRITICAL"
  REASON="This command will permanently delete data and cannot be undone."
fi

# 🔴 Critical: direct push to protected branch
if echo "$COMMAND" | grep -qE 'git push.*(origin )?(main|master|production|release)( |$)'; then
  DANGER_LEVEL="CRITICAL"
  REASON="This will push code directly to a protected branch. Use a Pull Request instead."
fi

# 🟠 High: production deploy
if echo "$COMMAND" | grep -qiE '(npm run deploy|yarn deploy|vercel --prod|netlify deploy --prod|firebase deploy|heroku releases:promote)'; then
  DANGER_LEVEL="HIGH"
  REASON="This will deploy to production — users will see the change immediately."
fi

# 🟠 High: destructive git operations
if echo "$COMMAND" | grep -qE 'git (reset --hard|clean -f|push --force|push -f)'; then
  DANGER_LEVEL="HIGH"
  REASON="This will discard commits or uncommitted changes and is hard to reverse."
fi

if [ -n "$DANGER_LEVEL" ]; then
  echo "" >&2
  if [ "$DANGER_LEVEL" = "CRITICAL" ]; then
    echo "🚫 BLOCKED — Confirmation required" >&2
  else
    echo "⚠️  WARNING — High-risk operation" >&2
  fi
  echo "" >&2
  echo "Command: $COMMAND" >&2
  echo "" >&2
  echo "⚡ $REASON" >&2
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "Claude must ask the user for confirmation before proceeding." >&2
  echo "Type 'confirm' or 'yes' to allow." >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "" >&2
  exit 2
fi

exit 0

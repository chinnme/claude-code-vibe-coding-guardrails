#!/usr/bin/env bash
# Hook: no-hardcoded-secrets.sh
# Trigger: PostToolUse — runs after Claude writes or edits any file
# Purpose: Scan for hardcoded secrets using gitleaks.
#          gitleaks is REQUIRED — if not installed, Claude is blocked from editing files.

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

# ── enforce gitleaks is installed ────────────────────────────────────────────
if ! command -v gitleaks &>/dev/null; then
  echo "" >&2
  echo "🚫 BLOCKED: gitleaks is not installed." >&2
  echo "" >&2
  echo "   Your team's security policy requires gitleaks to scan for secrets." >&2
  echo "   Claude cannot write or edit files until gitleaks is installed." >&2
  echo "" >&2
  echo "   Install:" >&2
  echo "     macOS:  brew install gitleaks" >&2
  echo "     Linux:  sudo apt install gitleaks" >&2
  echo "     Other:  https://github.com/gitleaks/gitleaks#installing" >&2
  echo "" >&2
  exit 2
fi

# ── scan file with gitleaks ───────────────────────────────────────────────────
# Use 'gitleaks stdin' — pipe file content, no git context needed.
# Use custom config if available at ~/.claude/.gitleaks.toml (installed by setup skill)
# exit 0 = no leaks, exit 1 = leaks found

GITLEAKS_CONFIG_FLAG=""
if [ -f "$HOME/.claude/.gitleaks.toml" ]; then
  GITLEAKS_CONFIG_FLAG="--config $HOME/.claude/.gitleaks.toml"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.gitleaks.toml" ]; then
  GITLEAKS_CONFIG_FLAG="--config ${CLAUDE_PLUGIN_ROOT}/.gitleaks.toml"
fi

SCAN_OUTPUT=$(cat "$FILE_PATH" | gitleaks stdin --no-banner $GITLEAKS_CONFIG_FLAG 2>&1)
SCAN_EXIT=$?

if [ "$SCAN_EXIT" -ne 0 ]; then
  echo "" >&2
  echo "🚫 BLOCKED: gitleaks found secrets in: $FILE_PATH" >&2
  echo "" >&2
  echo "$SCAN_OUTPUT" | grep -v "^[0-9]\+:\+[0-9]\+[A-Z]\+" | sed 's/^/   /' >&2
  echo "" >&2
  echo "💡 Move the secret to .env and reference it via an environment variable." >&2
  echo "   Example:  API_KEY=\${API_KEY}  or  process.env.API_KEY" >&2
  echo "   Then add .env to .gitignore." >&2
  echo "" >&2
  exit 2
fi

exit 0

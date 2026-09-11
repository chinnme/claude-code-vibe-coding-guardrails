#!/usr/bin/env bash
# Hook: no-sensitive-files-in-git.sh
# Trigger: PreToolUse — runs before Claude executes git commands
# Purpose: Prevent Claude from committing sensitive files to git

set -uo pipefail

INPUT=$(cat)

# ── Parse command via Python (handles flags like -C /path, --git-dir, etc.) ──
PARSE_RESULT=$(echo "$INPUT" | python3 -c "
import sys, json, re, shlex

d = json.load(sys.stdin)
cmd = d.get('tool_input', {}).get('command', '')

IS_ADD = False
IS_COMMIT = False
ADD_PATHS = []

# Split on shell separators to get subcommands
subcommands = re.split(r'[;&|]+', cmd)

for sub in subcommands:
    sub = sub.strip()
    try:
        tokens = shlex.split(sub)
    except ValueError:
        tokens = sub.split()

    if not tokens:
        continue

    # Find 'git' token then look for subcommand (skip flags and -C <path>)
    i = 0
    while i < len(tokens) and tokens[i] != 'git':
        i += 1
    if i >= len(tokens):
        continue

    i += 1  # skip 'git'

    # Skip git-level flags and -C <path>
    while i < len(tokens):
        tok = tokens[i]
        if tok == '-C' or tok == '--git-dir' or tok == '--work-tree':
            i += 2  # skip flag and its value
        elif tok.startswith('-'):
            i += 1  # skip other flags
        else:
            break

    if i >= len(tokens):
        continue

    subcmd = tokens[i]
    rest = tokens[i+1:]

    if subcmd == 'add':
        IS_ADD = True
        # Collect paths (skip flags like -A, --all, -u, -p, -f, -n)
        for r in rest:
            if not r.startswith('-'):
                ADD_PATHS.append(r)
    elif subcmd == 'commit':
        IS_COMMIT = True

print('IS_ADD=' + ('1' if IS_ADD else '0'))
print('IS_COMMIT=' + ('1' if IS_COMMIT else '0'))
print('ADD_PATHS=' + '|'.join(ADD_PATHS))
" 2>/dev/null || echo -e "IS_ADD=0\nIS_COMMIT=0\nADD_PATHS=")

IS_ADD=$(echo "$PARSE_RESULT" | grep '^IS_ADD=' | cut -d= -f2)
IS_COMMIT=$(echo "$PARSE_RESULT" | grep '^IS_COMMIT=' | cut -d= -f2)
ADD_PATHS_RAW=$(echo "$PARSE_RESULT" | grep '^ADD_PATHS=' | cut -d= -f2-)

# Not a git add or commit → pass
if [ "${IS_ADD:-0}" != "1" ] && [ "${IS_COMMIT:-0}" != "1" ]; then
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
if [ "${IS_ADD:-0}" = "1" ]; then
  # Use parsed paths; fallback to full command tail if none parsed
  if [ -n "$ADD_PATHS_RAW" ]; then
    PATHS="$ADD_PATHS_RAW"
  else
    COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null || echo "")
    PATHS="$COMMAND"
  fi

  for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$PATHS" | tr '|' '\n' | grep -qE "$PATTERN"; then
      MATCHED=$(echo "$PATHS" | tr '|' '\n' | grep -E "$PATTERN" || true)
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
if [ "${IS_COMMIT:-0}" = "1" ]; then
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

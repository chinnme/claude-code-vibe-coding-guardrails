#!/usr/bin/env bash
# Hook: check-public-repo-push.sh
# Trigger: PreToolUse — runs before Claude executes any Bash command
# Purpose: Block ALL pushes to PUBLIC GitHub repositories.
#
# Covers:
#   git push [flags] [remote] [refspec]  — any flag combination
#   gh pr create / gh release create / gh repo push / gh cs push
#
# Detection: unauthenticated HTTP GET to github.com/owner/repo
#   HTTP 200 → public → BLOCK
#   HTTP 404 / timeout / other → private or unknown → ALLOW

set -uo pipefail

INPUT=$(cat)

# ── Parse command + detect push type via Python (reliable on macOS) ───────────
PARSE_RESULT=$(echo "$INPUT" | python3 -c "
import sys, json, re, shlex

d = json.load(sys.stdin)
cmd = d.get('tool_input', {}).get('command', '')

IS_PUSH = False
REMOTE_HINT = ''  # empty = use 'origin'

# ── git push detection ──────────────────────────────────────────────────────
# Split on shell word boundaries conservatively: &&, ;, |, then scan each piece
# We use a simple split approach — split on ;, &&, || to get sub-commands
subcommands = re.split(r'[;&|]+', cmd)

for sub in subcommands:
    sub = sub.strip()
    # Tokenize the sub-command (handles quoted args)
    try:
        tokens = shlex.split(sub)
    except ValueError:
        tokens = sub.split()

    if not tokens:
        continue

    # Find 'git' then skip git-level flags (-C <path>, --git-dir, etc.) to find subcommand
    for i, tok in enumerate(tokens):
        if tok == 'git':
            j = i + 1
            # Skip git-level flags that take a value argument
            while j < len(tokens):
                t = tokens[j]
                if t in ('-C', '--git-dir', '--work-tree', '--namespace'):
                    j += 2  # skip flag + value
                elif t.startswith('-'):
                    j += 1  # skip standalone flag
                else:
                    break  # found subcommand

            if j < len(tokens) and tokens[j] == 'push':
                IS_PUSH = True
                # Everything after 'push'
                rest = tokens[j+1:]
                # Skip flags (start with -) to find remote name
                for r in rest:
                    if r.startswith('-'):
                        continue
                    if ':' in r or '/' in r:
                        break  # refspec, stop
                    REMOTE_HINT = r
                    break
            break

    if IS_PUSH:
        break

# ── gh push-type commands ───────────────────────────────────────────────────
if not IS_PUSH:
    GH_PUSH_PATTERNS = [
        r'\bgh\s+pr\s+create\b',
        r'\bgh\s+release\s+create\b',
        r'\bgh\s+repo\s+push\b',
        r'\bgh\s+cs\s+push\b',
        r'\bgh\s+pr\s+edit\b.*--push',
    ]
    for pat in GH_PUSH_PATTERNS:
        if re.search(pat, cmd):
            IS_PUSH = True
            break

print('IS_PUSH=' + ('1' if IS_PUSH else '0'))
print('REMOTE_HINT=' + REMOTE_HINT)
" 2>/dev/null || echo -e "IS_PUSH=0\nREMOTE_HINT=")

IS_PUSH=$(echo "$PARSE_RESULT" | grep '^IS_PUSH=' | cut -d= -f2)
REMOTE_HINT=$(echo "$PARSE_RESULT" | grep '^REMOTE_HINT=' | cut -d= -f2-)

if [ "${IS_PUSH:-0}" != "1" ]; then
  exit 0
fi

# ── Resolve remote name ───────────────────────────────────────────────────────
REMOTE="${REMOTE_HINT:-origin}"
[ -z "$REMOTE" ] && REMOTE="origin"

REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")

if [ -z "$REMOTE_URL" ]; then
  exit 0  # No remote → let git/gh handle it
fi

# Only check GitHub URLs
if ! echo "$REMOTE_URL" | grep -qiE 'github\.com'; then
  exit 0
fi

# ── Parse owner/repo ──────────────────────────────────────────────────────────
REPO_PATH=$(echo "$REMOTE_URL" | python3 -c "
import sys, re
url = sys.stdin.read().strip()
# HTTPS: https://github.com/owner/repo[.git]
m = re.match(r'https://github\.com/([^/?#]+/[^/?#.]+?)(?:\.git)?(?:[/?#].*)?$', url)
if m:
    print(m.group(1))
    sys.exit(0)
# SSH: git@github.com:owner/repo[.git]
m = re.match(r'git@github\.com:([^/]+/[^/.]+?)(?:\.git)?$', url)
if m:
    print(m.group(1))
    sys.exit(0)
" 2>/dev/null || echo "")

if [ -z "$REPO_PATH" ]; then
  exit 0  # Cannot parse — allow
fi

# ── Visibility check ──────────────────────────────────────────────────────────
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  --max-time 5 \
  "https://github.com/${REPO_PATH}" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "" >&2
  echo "🚫 BLOCKED: Cannot push to a PUBLIC repository." >&2
  echo "" >&2
  echo "   Command : $COMMAND" >&2
  echo "   Remote  : $REMOTE → $REMOTE_URL" >&2
  echo "   Repo    : https://github.com/${REPO_PATH}" >&2
  echo "   Reason  : HTTP $HTTP_STATUS — accessible without authentication = public" >&2
  echo "" >&2
  echo "   Pushing to a public repo exposes all committed code to the internet." >&2
  echo "   Get explicit user approval before pushing." >&2
  echo "" >&2
  exit 2
fi

exit 0

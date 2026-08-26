#!/usr/bin/env bash
# Hook: check-public-repo-push.sh
# Trigger: PreToolUse — runs before Claude executes any Bash command
# Purpose: Block git push to public GitHub repositories
#          Detection: unauthenticated curl returning HTTP 200 = public repo

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

# Only intercept git push
if ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi

# Extract remote name (default: origin)
REMOTE=$(echo "$COMMAND" | grep -oE 'git push\s+([a-zA-Z0-9_.-]+)' | awk '{print $3}')
if [ -z "$REMOTE" ]; then
  REMOTE="origin"
fi

# Get remote URL
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")

if [ -z "$REMOTE_URL" ]; then
  # Cannot determine remote — let it pass, git will handle the error
  exit 0
fi

# Only check GitHub URLs
if ! echo "$REMOTE_URL" | grep -qiE 'github\.com'; then
  exit 0
fi

# Parse owner/repo from URL (supports both HTTPS and SSH formats)
# HTTPS: https://github.com/owner/repo.git
# SSH:   git@github.com:owner/repo.git
REPO_PATH=$(echo "$REMOTE_URL" | sed -E \
  's#https://github\.com/([^/]+/[^/.]+)(\.git)?$#\1#;
   s#git@github\.com:([^/]+/[^/.]+)(\.git)?$#\1#')

if [ -z "$REPO_PATH" ] || [ "$REPO_PATH" = "$REMOTE_URL" ]; then
  # Could not parse — let it pass
  exit 0
fi

# Check if repo is public: unauthenticated curl returning 200 = public
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  --max-time 5 \
  "https://github.com/${REPO_PATH}" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "" >&2
  echo "🚫 BLOCKED: This appears to be a PUBLIC repository." >&2
  echo "" >&2
  echo "   Remote: $REMOTE → $REMOTE_URL" >&2
  echo "   Repo:   https://github.com/${REPO_PATH}" >&2
  echo "   Check:  HTTP $HTTP_STATUS (accessible without authentication = public)" >&2
  echo "" >&2
  echo "   Pushing to a public repo means anyone on the internet can see your code." >&2
  echo "   If you intended to push here, type 'yes push public' to confirm." >&2
  echo "" >&2
  exit 2
fi

# HTTP 404, timeout (000), or other = private/non-existent/non-GitHub → allow
exit 0

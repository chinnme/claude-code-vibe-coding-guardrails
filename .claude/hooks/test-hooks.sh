#!/usr/bin/env bash
# test-hooks.sh
# Tests all Claude Code hooks using the full JSON input format from official docs.
# Ref: https://code.claude.com/docs/en/hooks (PreToolUse / PostToolUse input schema)
#
# Usage: bash .claude/hooks/test-hooks.sh [hook-name-filter]
# Example: bash .claude/hooks/test-hooks.sh confirm-destructive-ops

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
SKIP=0
CWD="$(pwd)"

# ── helpers ───────────────────────────────────────────────────────────────────

green()  { printf '\033[32m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# Use python3 to build JSON — correctly escapes any characters in the value
bash_json() {
  python3 -c "
import json, sys
cmd = sys.argv[1]
print(json.dumps({
  'session_id': 'test-session-001',
  'prompt_id': '550e8400-e29b-41d4-a716-446655440000',
  'transcript_path': '/tmp/test-transcript.jsonl',
  'cwd': '$CWD',
  'permission_mode': 'default',
  'hook_event_name': 'PreToolUse',
  'tool_name': 'Bash',
  'tool_input': {
    'command': cmd,
    'description': 'test command',
    'timeout': 120000,
    'run_in_background': False
  },
  'tool_use_id': 'toolu_01TEST123'
}))
" "$1"
}

# SessionStart JSON
session_json() {
  local source="${1:-startup}"
  python3 -c "
import json, sys
print(json.dumps({
  'session_id': 'test-session-001',
  'transcript_path': '/tmp/test-transcript.jsonl',
  'cwd': '$CWD',
  'hook_event_name': 'SessionStart',
  'source': sys.argv[1]
}))
" "$source"
}

# PostToolUse / Edit tool JSON
edit_json() {
  python3 -c "
import json, sys
fp = sys.argv[1]
print(json.dumps({
  'session_id': 'test-session-001',
  'cwd': '$CWD',
  'permission_mode': 'default',
  'hook_event_name': 'PostToolUse',
  'tool_name': 'Edit',
  'tool_input': {'file_path': fp, 'old_string': 'old', 'new_string': 'new', 'replace_all': False},
  'tool_response': {'filePath': fp, 'success': True},
  'tool_use_id': 'toolu_01TEST123',
  'duration_ms': 42
}))
" "$1"
}

# PostToolUse / Write tool JSON
write_json() {
  python3 -c "
import json, sys
fp = sys.argv[1]
print(json.dumps({
  'session_id': 'test-session-001',
  'cwd': '$CWD',
  'permission_mode': 'default',
  'hook_event_name': 'PostToolUse',
  'tool_name': 'Write',
  'tool_input': {'file_path': fp, 'content': 'test content'},
  'tool_response': {'filePath': fp, 'success': True},
  'tool_use_id': 'toolu_01TEST123',
  'duration_ms': 15
}))
" "$1"
}

# run_test <description> <expected_exit> <json_string> <hook_script>
run_test() {
  local desc="$1"
  local expected_exit="$2"
  local json_input="$3"
  local hook_script="$4"

  if [ ! -f "$hook_script" ]; then
    yellow "  SKIP  $desc (script not found)"
    ((SKIP++)) || true
    return
  fi

  local actual_exit=0
  local stderr_out
  stderr_out=$(printf '%s' "$json_input" | bash "$hook_script" 2>&1 >/dev/null) || actual_exit=$?

  local ok=false
  case "$expected_exit" in
    "0")       [ "$actual_exit" -eq 0 ] && ok=true ;;
    "1")       [ "$actual_exit" -eq 1 ] && ok=true ;;
    "2")       [ "$actual_exit" -eq 2 ] && ok=true ;;
    "nonzero") [ "$actual_exit" -ne 0 ] && ok=true ;;
  esac

  if $ok; then
    green "  PASS  $desc (exit $actual_exit)"
    ((PASS++)) || true
  else
    red   "  FAIL  $desc"
    red   "         expected exit=$expected_exit  got exit=$actual_exit"
    if [ -n "$stderr_out" ]; then
      echo "$stderr_out" | head -5 | sed 's/^/         | /' >&2
    fi
    ((FAIL++)) || true
  fi
}

FILTER="${1:-}"
run_suite() {
  local name="$1"
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then return 1; fi
  bold ""; bold "── $name ──────────────────────────────────────────────"
  return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 0. session-start-check.sh  (SessionStart)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "session-start-check"; then
HOOK="$HOOKS_DIR/session-start-check.sh"

# SessionStart hooks cannot block (exit code is informational only per docs)
# So all cases should exit 0 — we verify no crash and correct behavior

run_test "startup: exits 0 (non-blocking)" "0" "$(session_json 'startup')" "$HOOK"
run_test "resume: exits 0 (non-blocking)"  "0" "$(session_json 'resume')"  "$HOOK"

# Verify gitleaks detection message matches installed state
if command -v gitleaks &>/dev/null; then
  # Should mention gitleaks version in stderr
  actual_stderr=$(printf '%s' "$(session_json 'startup')" | bash "$HOOK" 2>&1 >/dev/null || true)
  if echo "$actual_stderr" | grep -q "gitleaks"; then
    green "  PASS  startup: gitleaks detected and mentioned in output"
    ((PASS++)) || true
  else
    red   "  FAIL  startup: expected gitleaks mention in output"
    ((FAIL++)) || true
  fi
else
  actual_stderr=$(printf '%s' "$(session_json 'startup')" | bash "$HOOK" 2>&1 >/dev/null || true)
  if echo "$actual_stderr" | grep -q "not installed"; then
    green "  PASS  startup: install guide shown when gitleaks missing"
    ((PASS++)) || true
  else
    red   "  FAIL  startup: expected install guide when gitleaks missing"
    ((FAIL++)) || true
  fi
fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 1. confirm-destructive-ops.sh  (PreToolUse / Bash)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "confirm-destructive-ops"; then
HOOK="$HOOKS_DIR/confirm-destructive-ops.sh"

run_test "safe: ls -la"            "0" "$(bash_json 'ls -la')"                       "$HOOK"
run_test "safe: git status"        "0" "$(bash_json 'git status')"                   "$HOOK"
run_test "safe: npm run build"     "0" "$(bash_json 'npm run build')"                "$HOOK"
run_test "safe: npm test"          "0" "$(bash_json 'npm test')"                     "$HOOK"
run_test "safe: git log"           "0" "$(bash_json 'git log --oneline')"            "$HOOK"
run_test "safe: python app.py"     "0" "$(bash_json 'python app.py')"                "$HOOK"
run_test "block: rm -rf"           "2" "$(bash_json 'rm -rf /tmp/test')"             "$HOOK"
run_test "block: DROP TABLE"       "2" "$(bash_json 'psql -c "DROP TABLE users;"')"  "$HOOK"
run_test "block: git push main"    "2" "$(bash_json 'git push origin main')"         "$HOOK"
run_test "block: git push master"  "2" "$(bash_json 'git push origin master')"       "$HOOK"
run_test "block: git reset --hard" "2" "$(bash_json 'git reset --hard HEAD~1')"      "$HOOK"
run_test "block: git push --force" "2" "$(bash_json 'git push --force')"             "$HOOK"
run_test "block: git push -f"      "2" "$(bash_json 'git push -f')"                  "$HOOK"
run_test "block: vercel --prod"    "2" "$(bash_json 'vercel --prod')"                "$HOOK"
run_test "block: firebase deploy"  "2" "$(bash_json 'firebase deploy')"              "$HOOK"
run_test "edge: empty command"     "0" "$(bash_json '')"                             "$HOOK"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. no-sensitive-files-in-git.sh  (PreToolUse / Bash)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "no-sensitive-files-in-git"; then
HOOK="$HOOKS_DIR/no-sensitive-files-in-git.sh"

run_test "safe: git add src/app.py"       "0" "$(bash_json 'git add src/app.py')"            "$HOOK"
run_test "safe: git add .env.example"     "0" "$(bash_json 'git add .env.example')"          "$HOOK"
run_test "safe: git status"               "0" "$(bash_json 'git status')"                    "$HOOK"
run_test "safe: git log"                  "0" "$(bash_json 'git log --oneline')"             "$HOOK"
run_test "safe: git diff"                 "0" "$(bash_json 'git diff HEAD')"                 "$HOOK"
run_test "safe: git commit -m msg"        "0" "$(bash_json 'git commit -m "chore: init"')"   "$HOOK"
run_test "block: git add .env"            "2" "$(bash_json 'git add .env')"                  "$HOOK"
run_test "block: git add .env.local"      "2" "$(bash_json 'git add .env.local')"            "$HOOK"
run_test "block: git add .env.prod"       "2" "$(bash_json 'git add .env.prod')"             "$HOOK"
run_test "block: git add private.pem"     "2" "$(bash_json 'git add private.pem')"           "$HOOK"
run_test "block: git add server.key"      "2" "$(bash_json 'git add server.key')"            "$HOOK"
run_test "block: git add cert.p12"        "2" "$(bash_json 'git add cert.p12')"              "$HOOK"
run_test "block: git add CLAUDE.local.md" "2" "$(bash_json 'git add CLAUDE.local.md')"       "$HOOK"
run_test "block: git add settings.local.json" "2" "$(bash_json 'git add .claude/settings.local.json')" "$HOOK"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. no-hardcoded-secrets.sh  (PostToolUse — now uses gitleaks)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "no-hardcoded-secrets"; then
HOOK="$HOOKS_DIR/no-hardcoded-secrets.sh"

TMPDIR_S=$(mktemp -d)
trap 'rm -rf "$TMPDIR_S" 2>/dev/null || true' EXIT

# Files with real gitleaks-detectable secrets (AWS key, GitHub token)
DIRTY_PY="$TMPDIR_S/config.py"
cat > "$DIRTY_PY" << 'EOF'
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
GITHUB_TOKEN = "ghp_16C7e42F292c6912E7710c838347Ae178B4a"
EOF

# Clean files — env var references only
CLEAN_PY="$TMPDIR_S/safe.py"
printf 'import os\nAPI_KEY = os.environ["API_KEY"]\n' > "$CLEAN_PY"

CLEAN_JS="$TMPDIR_S/config.js"
printf 'const apiKey = process.env.API_KEY;\n' > "$CLEAN_JS"

# Placeholder values — should not trigger gitleaks
PLACEHOLDER_PY="$TMPDIR_S/placeholder.py"
printf 'API_KEY = "your-api-key-here"\nPASSWORD = "changeme"\n' > "$PLACEHOLDER_PY"

run_test "edge: nonexistent file passes"  "0" "$(edit_json '/no/such/file.py')"  "$HOOK"
run_test "edge: empty path passes"        "0" "$(edit_json '')"                  "$HOOK"

if command -v gitleaks &>/dev/null; then
  # gitleaks is installed — expect full behavior
  run_test "Edit: clean py passes"        "0" "$(edit_json "$CLEAN_PY")"         "$HOOK"
  run_test "Edit: dirty py blocked"       "2" "$(edit_json "$DIRTY_PY")"         "$HOOK"
  run_test "Edit: placeholder passes"     "0" "$(edit_json "$PLACEHOLDER_PY")"   "$HOOK"
  run_test "Edit: process.env passes"     "0" "$(edit_json "$CLEAN_JS")"         "$HOOK"
  run_test "Write: clean py passes"       "0" "$(write_json "$CLEAN_PY")"        "$HOOK"
  run_test "Write: dirty py blocked"      "2" "$(write_json "$DIRTY_PY")"        "$HOOK"
else
  # gitleaks not installed — hook must block with exit 2
  run_test "no gitleaks: Edit blocked"    "2" "$(edit_json "$CLEAN_PY")"         "$HOOK"
  run_test "no gitleaks: Write blocked"   "2" "$(write_json "$CLEAN_PY")"        "$HOOK"
  yellow "  NOTE  Install gitleaks to run full secret-scanning tests"
fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 4. check-public-repo-push.sh  (PreToolUse / Bash)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "check-public-repo-push"; then
HOOK="$HOOKS_DIR/check-public-repo-push.sh"

run_test "safe: npm install"       "0" "$(bash_json 'npm install')"             "$HOOK"
run_test "safe: git commit"        "0" "$(bash_json 'git commit -m "test"')"    "$HOOK"
run_test "safe: git pull"          "0" "$(bash_json 'git pull origin main')"    "$HOOK"
run_test "safe: git status"        "0" "$(bash_json 'git status')"              "$HOOK"
run_test "edge: push no remote"    "0" "$(bash_json 'git push')"               "$HOOK"

if command -v curl &>/dev/null; then
  TMPGIT=$(mktemp -d)
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" remote add origin "https://github.com/chinnme/public-repo-test.git"
  actual_exit=0
  cd "$TMPGIT" && printf '%s' "$(bash_json 'git push origin main')" | bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
  cd - >/dev/null; rm -rf "$TMPGIT"
  [ "$actual_exit" -eq 2 ] && { green "  PASS  live: HTTPS public repo blocked (exit 2)"; ((PASS++)) || true; } \
                            || { red "  FAIL  live: HTTPS public repo should be blocked (got $actual_exit)"; ((FAIL++)) || true; }

  TMPGIT2=$(mktemp -d)
  git -C "$TMPGIT2" init -q
  git -C "$TMPGIT2" remote add origin "https://github.com/chinnme/private-repo-test.git"
  actual_exit=0
  cd "$TMPGIT2" && printf '%s' "$(bash_json 'git push origin main')" | bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
  cd - >/dev/null; rm -rf "$TMPGIT2"
  [ "$actual_exit" -eq 0 ] && { green "  PASS  live: HTTPS private repo passes (exit 0)"; ((PASS++)) || true; } \
                            || { red "  FAIL  live: HTTPS private repo should pass (got $actual_exit)"; ((FAIL++)) || true; }

  TMPGIT3=$(mktemp -d)
  git -C "$TMPGIT3" init -q
  git -C "$TMPGIT3" remote add origin "git@github.com:chinnme/public-repo-test.git"
  actual_exit=0
  cd "$TMPGIT3" && printf '%s' "$(bash_json 'git push origin main')" | bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
  cd - >/dev/null; rm -rf "$TMPGIT3"
  [ "$actual_exit" -eq 2 ] && { green "  PASS  live: SSH public repo blocked (exit 2)"; ((PASS++)) || true; } \
                            || { red "  FAIL  live: SSH public repo should be blocked (got $actual_exit)"; ((FAIL++)) || true; }
else
  yellow "  SKIP  live repo tests (curl not available)"; ((SKIP+=3)) || true
fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 5. auto-detect-and-lint.sh  (PostToolUse)
# ══════════════════════════════════════════════════════════════════════════════
if run_suite "auto-detect-and-lint"; then
HOOK="$HOOKS_DIR/auto-detect-and-lint.sh"

TMPDIR_L=$(mktemp -d)
trap 'rm -rf "$TMPDIR_S" "$TMPDIR_L" 2>/dev/null || true' EXIT

JSON_FILE="$TMPDIR_L/data.json"; echo '{"key":"value"}' > "$JSON_FILE"
PY_CLEAN="$TMPDIR_L/clean.py"; printf 'def hello():\n    print("hello")\n' > "$PY_CLEAN"
PY_DIRTY="$TMPDIR_L/dirty.py"; printf 'import os,sys\nx=1;y=2\nprint(x+y)\n' > "$PY_DIRTY"
SH_CLEAN="$TMPDIR_L/clean.sh"; printf '#!/bin/bash\necho "hello world"\n' > "$SH_CLEAN"
SH_DIRTY="$TMPDIR_L/dirty.sh"; printf '#!/bin/bash\nx=`echo hello`\n[ $x == "hello" ] && echo "ok"\n' > "$SH_DIRTY"

run_test "edge: unsupported type (json)" "0" "$(edit_json "$JSON_FILE")"          "$HOOK"
run_test "edge: nonexistent file"        "0" "$(edit_json '/no/such/file.py')"    "$HOOK"
run_test "edge: Write tool json works"   "0" "$(write_json "$JSON_FILE")"         "$HOOK"

if command -v ruff &>/dev/null; then
  run_test "py: clean passes"            "0" "$(edit_json "$PY_CLEAN")"  "$HOOK"
  run_test "py: dirty warns"             "1" "$(edit_json "$PY_DIRTY")"  "$HOOK"
  run_test "py: Write tool works"        "0" "$(write_json "$PY_CLEAN")" "$HOOK"
else
  yellow "  SKIP  python lint tests (ruff not installed — run /setup-linting)"; ((SKIP+=3)) || true
fi

if command -v shellcheck &>/dev/null; then
  run_test "sh: clean passes"            "0" "$(edit_json "$SH_CLEAN")"  "$HOOK"
  run_test "sh: dirty warns"             "1" "$(edit_json "$SH_DIRTY")"  "$HOOK"
else
  yellow "  SKIP  shell lint tests (shellcheck not installed — run /setup-linting)"; ((SKIP+=2)) || true
fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
bold ""
bold "════════════════════════════════════════"
bold "  Results"
bold "════════════════════════════════════════"
green "  PASS: $PASS"
[ "$FAIL" -gt 0 ] && red "  FAIL: $FAIL" || echo "  FAIL: $FAIL"
[ "$SKIP" -gt 0 ] && yellow "  SKIP: $SKIP"
bold "════════════════════════════════════════"
echo ""

[ "$FAIL" -gt 0 ] && exit 1
exit 0

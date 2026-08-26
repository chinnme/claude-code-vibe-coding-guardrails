#!/usr/bin/env bash
# Hook: session-start-check.sh
# Trigger: SessionStart — runs when Claude Code starts or resumes a session
# Purpose: Ensure gitleaks is installed and up to date.
#          - If installed: auto-update via brew upgrade gitleaks (background, non-blocking)
#          - If not installed: inject context so Claude asks user if it should install

set -uo pipefail

# ── check if gitleaks is installed ───────────────────────────────────────────
if ! command -v gitleaks &>/dev/null; then

  # Detect OS for the right install command
  INSTALL_CMD="brew install gitleaks"
  if [[ "$(uname -s)" == "Linux" ]]; then
    if command -v apt &>/dev/null; then
      INSTALL_CMD="sudo apt install gitleaks"
    elif command -v snap &>/dev/null; then
      INSTALL_CMD="sudo snap install gitleaks"
    else
      INSTALL_CMD="see https://github.com/gitleaks/gitleaks#installing"
    fi
  fi

  # Use JSON additionalContext so Claude sees this and asks the user
  # Per docs: SessionStart additionalContext is injected before the first prompt
  python3 -c "
import json
msg = '''gitleaks is NOT installed on this machine.

gitleaks is REQUIRED by the team security policy (CISO requirement) to prevent secrets and credentials from leaking into code. Until it is installed, Claude cannot write or edit any files in this project.

Install command for this OS: $INSTALL_CMD

Ask the user: \"gitleaks is required but not installed. Would you like me to install it now by running [$INSTALL_CMD]? Or you can run it yourself and restart the session.\"

If the user says yes, run the install command immediately before doing anything else.
If the user says no, remind them that file editing is blocked until gitleaks is installed.'''

print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'SessionStart',
    'additionalContext': msg
  }
}))
"
  exit 0
fi

# ── gitleaks is installed — show version then auto-update ────────────────────
CURRENT_VERSION=$(gitleaks version 2>/dev/null || echo "unknown")
echo "✅ gitleaks $CURRENT_VERSION detected. Checking for updates..." >&2

# Only attempt brew upgrade on macOS with brew available
if command -v brew &>/dev/null; then
  # Run upgrade in background so session start is not delayed
  (brew upgrade gitleaks 2>&1 | tail -1 | sed 's/^/   gitleaks update: /' >&2) &
  disown $! 2>/dev/null || true
else
  echo "   (auto-update skipped — brew not available; update manually)" >&2
fi

exit 0

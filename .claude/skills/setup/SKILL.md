---
name: setup
description: >
  Install the Vibe Coding Starter Policy on this machine — copies hooks, skills,
  and settings to the right place, sets permissions, and installs gitleaks.
  Use when: a new team member wants to set up the policy, or the user asks
  "how do I install the policy?" or "set up security for me".
allowed-tools: Bash(chmod *) Bash(cp *) Bash(mkdir *) Bash(brew *) Bash(apt *) Bash(gitleaks *) Bash(ls *) Bash(echo *)
---

# Vibe Coding Starter Policy — Setup Assistant

Help the user install the Vibe Coding Starter Policy on their machine.
Work through the steps below in order. Be friendly and explain what you're doing at each step.

---

## Step 1 — Detect where this policy lives

Find the policy directory by looking for the presence of `.claude/hooks/` and `CLAUDE.md`:

```bash
# Check if we're already inside the policy directory
ls .claude/hooks/no-hardcoded-secrets.sh 2>/dev/null && echo "IN_POLICY_DIR" || echo "NOT_IN_POLICY_DIR"
```

If `NOT_IN_POLICY_DIR`, tell the user:
> "Please run this skill from inside the `vibe-coding-policy/` directory, or tell me where the policy folder is."
Then stop and wait.

---

## Step 2 — Ask: project scope or global?

Ask the user:

> "Where would you like to install this policy?
>
> 1. **This project only** — installs into `.claude/` in your current project folder
> 2. **All my projects (recommended)** — installs into `~/.claude/` and applies to every project
>
> Type 1 or 2."

Set `INSTALL_TARGET` based on their answer:
- Answer 1 → `INSTALL_TARGET=".claude"`
- Answer 2 → `INSTALL_TARGET="$HOME/.claude"`

---

## Step 3 — Install hooks and settings

```bash
# Create directories
mkdir -p ${INSTALL_TARGET}/hooks
mkdir -p ${INSTALL_TARGET}/skills

# Copy hooks
cp .claude/hooks/session-start-check.sh ${INSTALL_TARGET}/hooks/
cp .claude/hooks/no-hardcoded-secrets.sh ${INSTALL_TARGET}/hooks/
cp .claude/hooks/no-sensitive-files-in-git.sh ${INSTALL_TARGET}/hooks/
cp .claude/hooks/confirm-destructive-ops.sh ${INSTALL_TARGET}/hooks/
cp .claude/hooks/check-public-repo-push.sh ${INSTALL_TARGET}/hooks/
cp .claude/hooks/auto-detect-and-lint.sh ${INSTALL_TARGET}/hooks/

# Make all hooks executable
chmod +x ${INSTALL_TARGET}/hooks/*.sh

# Copy skills
cp -r .claude/skills/check-secrets ${INSTALL_TARGET}/skills/
cp -r .claude/skills/new-project ${INSTALL_TARGET}/skills/
cp -r .claude/skills/setup-linting ${INSTALL_TARGET}/skills/
cp -r .claude/skills/setup ${INSTALL_TARGET}/skills/
```

After this step, tell the user what was copied and confirm it succeeded.

---

## Step 4 — Merge settings.json

Check if `${INSTALL_TARGET}/settings.json` already exists:

```bash
ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "EXISTS" || echo "NOT_EXISTS"
```

**If NOT_EXISTS:** copy directly:
```bash
cp .claude/settings.json ${INSTALL_TARGET}/settings.json
```

**If EXISTS:** tell the user:
> "You already have a `settings.json`. I'll show you what needs to be merged — the hooks and permissions sections from this policy."

Then show the user the relevant sections from `.claude/settings.json` and explain how to merge them manually, or ask if they want you to merge automatically (by reading both files and combining them).

---

## Step 5 — Copy CLAUDE.md (optional)

Ask the user:

> "Would you like to copy the base `CLAUDE.md` policy file to your project?
> This gives Claude the security rules to follow. You can customize it later.
>
> Type yes or no."

If yes:
```bash
cp CLAUDE.md ${INSTALL_TARGET}/../CLAUDE.md 2>/dev/null || cp CLAUDE.md ./CLAUDE.md
```

Explain: "This is a starting point — you can add your project's build commands and known Claude mistakes to this file."

---

## Step 6 — Install gitleaks

Check if gitleaks is already installed:

```bash
command -v gitleaks &>/dev/null && echo "INSTALLED: $(gitleaks version)" || echo "NOT_INSTALLED"
```

**If INSTALLED:** Tell the user gitleaks is already present and skip to Step 7.

**If NOT_INSTALLED:** Detect the OS and offer to install:

```bash
uname -s
```

- If `Darwin` (macOS):
  > "I'll install gitleaks using Homebrew. This requires Homebrew to be installed. Shall I proceed? (yes/no)"
  If yes: `brew install gitleaks`

- If `Linux`:
  > "What package manager does your system use? (apt / snap / other)"
  - `apt`: `sudo apt install -y gitleaks`
  - `snap`: `sudo snap install gitleaks`
  - `other`: show the manual install link: https://github.com/gitleaks/gitleaks#installing

---

## Step 7 — Verify installation

Run a quick check to confirm everything is in place:

```bash
echo "=== Hooks ===" && ls ${INSTALL_TARGET}/hooks/*.sh
echo "=== Skills ===" && ls ${INSTALL_TARGET}/skills/
echo "=== gitleaks ===" && (command -v gitleaks &>/dev/null && gitleaks version || echo "NOT INSTALLED")
echo "=== settings.json ===" && (ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "present" || echo "missing")
```

---

## Step 8 — Summary and next steps

Tell the user what was installed and what to do next:

```
✅ Vibe Coding Starter Policy installed!

Installed to: ${INSTALL_TARGET}

What's active now:
- Hooks run automatically on every file edit and git command
- Skills available: /safe-project-setup, /check-secrets-before-commit, /setup-linting

Next steps:
1. Restart your Claude Code session (or run /reload-plugins) for hooks to take effect
2. Run /safe-project-setup when starting a new project
3. Run /setup-linting to configure linting for your language
4. Customize CLAUDE.md with your project's build commands and known issues
```

If gitleaks was NOT installed, add:
```
⚠️  gitleaks is not installed — Claude will block file edits until it's installed.
   Install it with: brew install gitleaks  (macOS)
                    sudo apt install gitleaks  (Linux)
```

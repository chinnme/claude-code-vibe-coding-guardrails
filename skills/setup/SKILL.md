---
name: setup
description: >
  Install the Vibe Coding Guardrail on this machine — copies hooks, skills,
  and settings to the right place, sets permissions, and installs gitleaks.
  Use when: a new team member wants to set up the policy, or the user asks
  "how do I install the policy?" or "set up security for me".
allowed-tools: Bash(chmod *) Bash(cp *) Bash(mkdir *) Bash(brew *) Bash(apt *) Bash(gitleaks *) Bash(ls *) Bash(echo *) Bash(uname *) Bash(command *)
---

# Vibe Coding Guardrail — Setup Assistant

Help the user install the Vibe Coding Guardrail on their machine.
Work through the steps below in order. Be friendly and explain what you're doing at each step.

The policy files are bundled with this plugin. Reference them using `${CLAUDE_SKILL_DIR}/../..` which resolves to the plugin root containing `hooks/`, `skills/`, etc.

Set this at the start:
```bash
POLICY_DIR="${CLAUDE_SKILL_DIR}/../.."
```

---

## Step 1 — Ask: global or project only?

Ask the user:

> "Where would you like to install this policy?
>
> 1. **All my projects (recommended)** — installs into `~/.claude/` and applies to every project on this machine
> 2. **This project only** — installs into `.claude/` in the current folder
>
> Type 1 or 2."

Set `INSTALL_TARGET` based on their answer:
- Answer 1 → `INSTALL_TARGET="$HOME/.claude"`
- Answer 2 → `INSTALL_TARGET=".claude"`

---

## Step 2 — Install hooks

```bash
mkdir -p ${INSTALL_TARGET}/hooks

cp ${POLICY_DIR}/hooks/session-start-check.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-hardcoded-secrets.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/no-sensitive-files-in-git.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/confirm-destructive-ops.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-public-repo-push.sh ${INSTALL_TARGET}/hooks/
cp ${POLICY_DIR}/hooks/check-insecure-patterns.sh ${INSTALL_TARGET}/hooks/

chmod +x ${INSTALL_TARGET}/hooks/*.sh
```

Tell the user which hooks were copied.

---

## Step 3 — Install skills

```bash
mkdir -p ${INSTALL_TARGET}/skills

cp -r ${POLICY_DIR}/skills/check-secrets ${INSTALL_TARGET}/skills/
cp -r ${POLICY_DIR}/skills/new-project ${INSTALL_TARGET}/skills/
cp -r ${POLICY_DIR}/skills/check-before-deploy ${INSTALL_TARGET}/skills/
```

Note: the `setup` skill is intentionally not copied — it's already available via the plugin as `/vibe-coding-guardrail:setup`.

---

## Step 4 — Merge settings.json

Check if `${INSTALL_TARGET}/settings.json` already exists:

```bash
ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "EXISTS" || echo "NOT_EXISTS"
```

**If NOT_EXISTS:** copy directly:
```bash
cp ${POLICY_DIR}/settings.json ${INSTALL_TARGET}/settings.json
```

**If EXISTS:** tell the user:
> "You already have a `settings.json`. I'll show you what needs to be added — the hooks and permissions sections from this policy."

Read both files and merge the `hooks` and `permissions.deny` sections. Ask the user to confirm before writing.

---

## Step 5 — Copy CLAUDE.md (optional)

Ask the user:

> "Would you like to copy the base `CLAUDE.md` to your current project?
> It gives Claude the security rules to follow. You can customize it later.
>
> Type yes or no."

If yes:
```bash
cp ${POLICY_DIR}/CLAUDE.md ./CLAUDE.md
```

Explain: "This is a starting point — add your project's build commands and known Claude mistakes here."

---

## Step 6 — Install gitleaks

Check if gitleaks is already installed:

```bash
command -v gitleaks &>/dev/null && echo "INSTALLED: $(gitleaks version)" || echo "NOT_INSTALLED"
```

**If INSTALLED:** Tell the user it's already present and skip to Step 7.

**If NOT_INSTALLED:** Detect OS and offer to install:

```bash
uname -s
```

- `Darwin` (macOS): ask "Shall I install gitleaks via Homebrew now? (yes/no)" → `brew install gitleaks`
- `Linux`: ask which package manager (apt / snap / other)
  - `apt` → `sudo apt install -y gitleaks`
  - `snap` → `sudo snap install gitleaks`
  - other → show: https://github.com/gitleaks/gitleaks#installing

---

## Step 7 — Verify

```bash
echo "=== Hooks ===" && ls ${INSTALL_TARGET}/hooks/*.sh
echo "=== Skills ===" && ls ${INSTALL_TARGET}/skills/
echo "=== gitleaks ===" && (command -v gitleaks &>/dev/null && gitleaks version || echo "NOT INSTALLED")
echo "=== settings.json ===" && (ls ${INSTALL_TARGET}/settings.json 2>/dev/null && echo "present" || echo "missing")
```

---

## Step 8 — Summary

```
✅ Vibe Coding Guardrail installed!

Installed to: ${INSTALL_TARGET}

Hooks active (automatic — no action needed):
- Secret scanning on every file edit (gitleaks)
- Blocks .env / .pem / .key from git commits
- Blocks pushes to public GitHub repos
- Blocks rm -rf, force push, production deploys
- Blocks CORS wildcard and localStorage token storage

Skills available:
- /vibe-coding-guardrail:new-project        — bootstrap a new project safely
- /vibe-coding-guardrail:check-secrets      — scan for secrets before committing
- /vibe-coding-guardrail:check-before-deploy — run full pre-deploy security checklist

Next steps:
1. Run /reload-plugins or restart Claude Code for hooks to take effect
2. Run /vibe-coding-guardrail:new-project when starting a new project
3. Customize CLAUDE.md with your project's build commands and known issues
```

If gitleaks was NOT installed, add:
```
⚠️  gitleaks is not installed — Claude will block all file edits until it's installed.
   Install: brew install gitleaks  (macOS)
            sudo apt install gitleaks  (Linux)
```

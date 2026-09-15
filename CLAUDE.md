# Claude Code Policy — Vibe Coding Team (Non-Dev)

> **Who this is for:** Team members using Claude Code to build personal projects,
> automation scripts, or internal tooling — no professional developer background required.
>
> **Copy this file to the root of every project:** `./CLAUDE.md`

---

## 🔐 Security Rules (Non-Negotiable)

- **Never** write passwords, API keys, tokens, or secrets directly into any file.
  Use environment variables instead — e.g. `process.env.API_KEY` or read from a `.env` file.
- **The `.env` file must always be in `.gitignore`** — never commit it to git.
- For example env files, use `.env.example` with placeholders only — e.g. `API_KEY=your-api-key-here`.
- **Never** push code directly to `main` or `master` — create a new branch and open a Pull Request.
- **Never** push to a public GitHub repository without explicit user confirmation — a hook will block this automatically.

---

## 📢 Communication

- Work autonomously — don't ask for confirmation on every step.
- **Ask when genuinely unsure** about what the user wants, not to double-check routine actions.
- Before doing something that cannot be undone (deleting files, deploying, resetting git history) — briefly state what you're about to do and why, then proceed unless it's blocked by a hook.
- After completing a task, summarize what was done and list files created or changed.

---

## 📁 Never Commit These to Git

```
.env              ← real secrets
.env.*            ← except .env.example
*.pem             ← SSL certificates
*.key             ← private keys
CLAUDE.local.md   ← personal notes
node_modules/     ← dependencies
__pycache__/      ← Python cache
.DS_Store         ← macOS junk files
```

Create a `.gitignore` with these entries as **the first step of every project**.

---

## ⚡ Code Rules

- **Never** suppress errors with `// @ts-ignore`, `eslint-disable`, or `# type: ignore` — fix the root cause instead.
- **Never** log personal data (names, emails, card numbers, passwords) to console or log files.
- **Never** bump dependency versions without being asked — if an update is needed, say so explicitly.
- Always validate user input (forms, URL params, API data) before using it.

---

## 🔒 API and Web Security Rules

- **Always** use HTTPS. Never generate `http://` URLs for any endpoint that handles credentials, tokens, or sensitive data.
- **Always** add rate limiting to authentication endpoints (login, signup, password reset, token refresh).
- **Never** implement authentication from scratch — use an established auth provider (Supabase Auth, Firebase Auth, Auth0, AWS Cognito, etc.).
- **Never** place admin, service-role, or any elevated-privilege credentials on the client side (browser, mobile app). These must only exist server-side, read from environment variables.
- When using frameworks with public env prefixes (`NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`), only place **public/anonymous** credentials behind these prefixes. Never place service keys or admin credentials behind a public prefix.
- Any application that is deployed and has real users must be registered in the organization's asset inventory with a named owner before going live.

---

## ✅ Before Saying "Done"

Claude must do the following before reporting a task complete:

1. Run build or tests if available (if not, tell the user they were not run).
2. Confirm no hardcoded secrets exist in modified files.
3. Summarize what was done, with a list of files created or changed.

---

## 🚫 Always Ask Before Doing These

- Deleting files or directories that contain important data.
- Modifying database schemas or migration files.
- Deploying or publishing to production.
- Installing a new dependency not previously used in the project.
- Editing `.env` or any live config files.

---

## 💡 Notes for the Team

This file is a starting point — customize it per project.
When Claude makes the same mistake twice → add a correction to the rules above.
Personal notes that should not be committed → put them in `CLAUDE.local.md` instead.

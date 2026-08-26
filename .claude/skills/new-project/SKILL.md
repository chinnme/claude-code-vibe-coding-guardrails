---
name: new-project
description: >
  Safely bootstrap a new project from scratch — create .gitignore, .env.example,
  and initialize a git repository before writing any code.
  Use when: starting a new project, or the user asks "how do I get started?"
---

# Safe Project Setup

When starting a new project, always follow these steps **before writing any code**.

## Step 1: Gather Required Information

Ask only what is strictly necessary — the user relies on Claude, not the other way around.
If the user has already mentioned a name or language, use it without asking again.

Ask only:
1. What is the project name? (if not already known)
2. What language will this project use? (Python / JavaScript / HTML+CSS / Shell) — if not already clear from context

Do not ask about API keys, deployment targets, or anything else upfront.
Those can be addressed later when they come up naturally.

## Step 2: Create Safety Files First

### Create `.gitignore`

```gitignore
# Secrets — never commit
.env
.env.*
!.env.example
secrets/
credentials/

# Private keys & certificates
*.pem
*.key
*.p12
*.pfx
id_rsa
id_rsa.pub

# Claude personal notes
CLAUDE.local.md
.claude/settings.local.json

# OS files
.DS_Store
Thumbs.db

# Dependencies
node_modules/
.venv/
__pycache__/
*.pyc
.pytest_cache/

# Build outputs
dist/
build/
*.egg-info/
```

### Create `.env.example`

Include a placeholder for every secret the user mentioned:

```
# Copy this file to .env and fill in real values.
# Never commit .env to git!

# Example:
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
API_KEY=your-api-key-here
SECRET_KEY=your-secret-key-here
```

### Create `.env` (if the user wants it now)

Create from `.env.example` — tell the user to fill in the real values themselves.

## Step 3: Initialize Git

```bash
git init
git add .gitignore .env.example
git commit -m "chore: initial project setup with safety files"
```

## Step 4: Notify the User

Clearly tell the user:
- Which files were created
- What to do next (fill in real values in `.env`)
- Which files must **never** be shared or uploaded

```
✅ Setup complete!

Files created:
- .gitignore — prevents secrets from being committed to git
- .env.example — template for secrets
- (no .env yet — you need to create it and fill in real values)

⚠️  Next steps:
1. Copy .env.example to .env
2. Fill in real values in .env
3. Never commit .env to git
```

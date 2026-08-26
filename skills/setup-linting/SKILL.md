---
name: setup-linting
description: >
  Set up the appropriate linter and formatter for this project
  by detecting the language from intent.md, spec.md, or existing files.
  If no information is found, ask the user, then guide installation and configure everything.
  Use when: starting a new project, or running /setup-linting.
---

# Setup Linting for This Project

## Step 1 — Detect the Language

Check in this order:

### 1a. Read intent/spec files first (if they exist)

Look for these files in the project:
```
./intent.md
./intent/*.md
./spec.md
./spec/*.md
./.claude/intent.md
```

If found → read and look for language mentions:
- "Python", "FastAPI", "Django", "Flask", "script" → Python
- "React", "Next.js", "TypeScript", "Node.js", "Express", "Vue" → JS/TS
- "HTML", "CSS", "webpage", "website", "landing page" → HTML/CSS
- "shell script", "bash", "automation script" → Shell

### 1b. If no intent/spec → check existing project files

```
requirements.txt / pyproject.toml / Pipfile → Python
package.json / node_modules/               → JS/TS
*.html / *.css (multiple files)            → HTML/CSS
multiple *.sh files                        → Shell
```

### 1c. If still unknown → ask the user

```
"What language does this project use?
  1. Python
  2. JavaScript / TypeScript
  3. HTML / CSS
  4. Shell/Bash
  5. Multiple (specify)"
```

---

## Step 2 — Check if Linter is Installed, Then Guide Installation

For each language detected, check if the linter exists. If not, show the install
command for the user's OS — do not run the install automatically.

### Detect OS

```bash
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then OS="mac"; fi
if [[ "$OSTYPE" == "linux-gnu"* ]]; then OS="linux"; fi
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$WINDIR" ]]; then OS="windows"; fi
```

---

### Python → Ruff

**Check:**
```bash
command -v ruff &>/dev/null && echo "✅ ruff $(ruff --version) already installed" || echo "❌ ruff not found"
```

**If not installed, show the right command:**

| OS | Install command |
|---|---|
| macOS | `brew install ruff` |
| Linux | `pip install ruff` or `pipx install ruff` |
| Windows | `pip install ruff` or `winget install Astral.Ruff` |

Tell the user: "Run the command above, then come back and run `/setup-linting` again."

**Create config** in `pyproject.toml` once installed (if no `[tool.ruff]` section exists):
```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP"]

[tool.ruff.format]
quote-style = "double"
```

---

### JavaScript / TypeScript → Biome

**Check:**
```bash
# Check local project install first
[ -f "node_modules/.bin/biome" ] && echo "✅ biome found (local)" || command -v biome &>/dev/null && echo "✅ biome found (global)" || echo "❌ biome not found"
```

**If not installed:**

Requires Node.js. If `node` is not present:

| OS | Install Node.js |
|---|---|
| macOS | `brew install node` |
| Linux | `sudo apt install nodejs npm` or use [nvm](https://github.com/nvm-sh/nvm) |
| Windows | Download from [nodejs.org](https://nodejs.org) or `winget install OpenJS.NodeJS` |

Once Node is available:
```bash
# If package.json exists:
npm install --save-dev --save-exact @biomejs/biome
npx @biomejs/biome init

# If no package.json:
npm init -y
npm install --save-dev --save-exact @biomejs/biome
npx @biomejs/biome init
```

The generated `biome.json` works out of the box — no additional config needed.

---

### HTML / CSS → HTMLHint + Stylelint + Prettier

**Check:**
```bash
[ -f "node_modules/.bin/htmlhint" ] && echo "✅ htmlhint found" || echo "❌ htmlhint not found"
[ -f "node_modules/.bin/stylelint" ] && echo "✅ stylelint found" || echo "❌ stylelint not found"
[ -f "node_modules/.bin/prettier" ] && echo "✅ prettier found" || echo "❌ prettier not found"
```

**If not installed** (requires Node.js — see JS/TS section above for Node install):
```bash
npm install --save-dev htmlhint stylelint stylelint-config-standard prettier
```

**Create configs:**

`.stylelintrc.json`:
```json
{
  "extends": ["stylelint-config-standard"]
}
```

`.prettierrc`:
```json
{
  "singleQuote": false,
  "tabWidth": 2,
  "printWidth": 100
}
```

---

### Shell → ShellCheck + shfmt

**Check:**
```bash
command -v shellcheck &>/dev/null && echo "✅ shellcheck found" || echo "❌ shellcheck not found"
command -v shfmt &>/dev/null && echo "✅ shfmt found" || echo "❌ shfmt not found"
```

**If not installed:**

| OS | ShellCheck | shfmt |
|---|---|---|
| macOS | `brew install shellcheck` | `brew install shfmt` |
| Linux | `sudo apt install shellcheck` | `sudo apt install shfmt` or `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |
| Windows | `winget install koalaman.shellcheck` | `scoop install shfmt` or download from [GitHub releases](https://github.com/mvdan/sh/releases) |

---

## Step 3 — Add Lint Commands to CLAUDE.md

After linters are confirmed installed, add to the project's `CLAUDE.md`
(only for languages in use):

```markdown
## Linting Commands
- Python:   ruff check . && ruff format --check .
- JS/TS:    npx biome check .
- HTML:     npx htmlhint "**/*.html" && npx prettier --check "**/*.html"
- CSS/SCSS: npx stylelint "**/*.css" && npx prettier --check "**/*.css"
- Shell:    shellcheck scripts/*.sh

Run lint before reporting a task complete and show the output.
```

---

## Step 4 — Report Results

```
✅ Linting setup complete!

Language detected: <language>
Linters confirmed:
- <linter> ✅ installed

Config files created:
- <config file>

From now on, Claude will run the linter automatically after every file edit.
If a linter is missing, Claude will remind you to install it.
```

---

## Notes

- Never run `npm install` or any package manager command without telling the user first.
- If install fails or the user is on an unsupported OS → show the manual install link, do not fail the task.
- If the project uses multiple languages → handle one at a time.
- If an older version of a linter already exists → keep it, do not upgrade.

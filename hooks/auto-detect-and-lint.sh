#!/usr/bin/env bash
# Hook: auto-detect-and-lint.sh
# Trigger: PostToolUse — runs after Claude writes or edits a file
# Purpose: Automatically check code quality based on file extension.
#          If the linter is not installed → skip silently (soft fail).

set -uo pipefail

# Read file path from stdin (Claude Code sends JSON)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(
  d.get('tool_input', {}).get('file_path') or
  d.get('tool_input', {}).get('path') or
  d.get('tool_response', {}).get('file_path') or
  ''
)
" 2>/dev/null || echo "")

# No path or file doesn't exist → exit
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"
FOUND_ISSUES=0

lint_header()        { echo "🔍 Linting: $FILE_PATH ($1)" >&2; }
lint_not_installed() { echo "   ℹ️  $1 not installed — skipping (run /setup-linting to install)" >&2; }

# Helper: resolve local node_modules bin or fall back to global
node_bin() {
  local name="$1"
  if [ -f "$(pwd)/node_modules/.bin/$name" ]; then
    echo "$(pwd)/node_modules/.bin/$name"
  elif command -v "$name" &>/dev/null; then
    echo "$name"
  else
    echo ""
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PYTHON — Ruff
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$EXT" == "py" || "$EXT" == "pyw" ]]; then
  lint_header "Python"
  if command -v ruff &>/dev/null; then
    if ! ruff check "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      FOUND_ISSUES=1
    fi
    if ! ruff format --check "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: ruff format \"$FILE_PATH\" to auto-format" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "ruff"
  fi

# ══════════════════════════════════════════════════════════════════════════════
# JAVASCRIPT / TYPESCRIPT — Biome (fallback: ESLint)
# ══════════════════════════════════════════════════════════════════════════════
elif [[ "$EXT" == "js" || "$EXT" == "ts" || "$EXT" == "jsx" || "$EXT" == "tsx" || "$EXT" == "mjs" || "$EXT" == "cjs" ]]; then
  lint_header "JavaScript/TypeScript"

  BIOME_BIN=$(node_bin "biome")

  if [ -n "$BIOME_BIN" ]; then
    if ! "$BIOME_BIN" check "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: biome check --write \"$FILE_PATH\" to auto-fix" >&2
      FOUND_ISSUES=1
    fi
  elif command -v npx &>/dev/null && npx --no eslint --version &>/dev/null 2>&1; then
    if ! npx eslint "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: npx eslint --fix \"$FILE_PATH\" to auto-fix" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "biome / eslint"
  fi

# ══════════════════════════════════════════════════════════════════════════════
# HTML — HTMLHint + Prettier
# ══════════════════════════════════════════════════════════════════════════════
elif [[ "$EXT" == "html" || "$EXT" == "htm" ]]; then
  lint_header "HTML"

  HTMLHINT_BIN=$(node_bin "htmlhint")
  PRETTIER_BIN=$(node_bin "prettier")

  if [ -n "$HTMLHINT_BIN" ]; then
    if ! "$HTMLHINT_BIN" "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "htmlhint"
  fi

  if [ -n "$PRETTIER_BIN" ]; then
    if ! "$PRETTIER_BIN" --check "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: prettier --write \"$FILE_PATH\" to auto-format" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "prettier"
  fi

# ══════════════════════════════════════════════════════════════════════════════
# CSS / SCSS / LESS — Stylelint + Prettier
# ══════════════════════════════════════════════════════════════════════════════
elif [[ "$EXT" == "css" || "$EXT" == "scss" || "$EXT" == "less" ]]; then
  lint_header "CSS/SCSS"

  STYLELINT_BIN=$(node_bin "stylelint")
  PRETTIER_BIN=$(node_bin "prettier")

  if [ -n "$STYLELINT_BIN" ]; then
    if ! "$STYLELINT_BIN" "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: stylelint --fix \"$FILE_PATH\" to auto-fix" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "stylelint"
  fi

  if [ -n "$PRETTIER_BIN" ]; then
    if ! "$PRETTIER_BIN" --check "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: prettier --write \"$FILE_PATH\" to auto-format" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "prettier"
  fi

# ══════════════════════════════════════════════════════════════════════════════
# SHELL — ShellCheck + shfmt
# ══════════════════════════════════════════════════════════════════════════════
elif [[ "$EXT" == "sh" || "$EXT" == "bash" || "$EXT" == "zsh" ]]; then
  lint_header "Shell"

  if command -v shellcheck &>/dev/null; then
    if ! shellcheck "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "shellcheck"
  fi

  if command -v shfmt &>/dev/null; then
    if ! shfmt -d "$FILE_PATH" 2>&1 | sed 's/^/   /'; then
      echo "   💡 Run: shfmt -w \"$FILE_PATH\" to auto-format" >&2
      FOUND_ISSUES=1
    fi
  else
    lint_not_installed "shfmt"
  fi

else
  # Unsupported file type → skip
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
if [ "$FOUND_ISSUES" -eq 1 ]; then
  echo "" >&2
  echo "⚠️  Issues found in $FILE_PATH — Claude should fix these before reporting done." >&2
  exit 1
fi

exit 0

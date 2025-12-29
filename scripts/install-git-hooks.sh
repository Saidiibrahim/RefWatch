#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.githooks"
PRE_COMMIT="$HOOKS_DIR/pre-commit"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Missing hooks directory: $HOOKS_DIR" >&2
  exit 1
fi

if [ ! -f "$PRE_COMMIT" ]; then
  echo "Missing pre-commit hook: $PRE_COMMIT" >&2
  exit 1
fi

chmod +x "$PRE_COMMIT"

git config core.hooksPath "$HOOKS_DIR"

echo "Git hooks installed."
echo "Verify with: git config core.hooksPath"

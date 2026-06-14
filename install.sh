#!/usr/bin/env bash
# ezcpyssh bootstrap — klont (oder aktualisiert) das Repo und startet `ezcpyssh setup`.
#   curl -fsSL https://raw.githubusercontent.com/sxty9/ezcpyssh/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/sxty9/ezcpyssh"
DIR="${EZCPYSSH_DIR:-$HOME/.local/share/ezcpyssh}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ezcpyssh läuft nur auf macOS." >&2; exit 1
fi
command -v git >/dev/null 2>&1 || { echo "git wird benötigt." >&2; exit 1; }

if [ -d "$DIR/.git" ]; then
  echo "→ aktualisiere $DIR"
  git -C "$DIR" pull --ff-only
else
  echo "→ klone nach $DIR"
  mkdir -p "$(dirname "$DIR")"
  git clone --depth 1 "$REPO" "$DIR"
fi

exec "$DIR/bin/ezcpyssh" setup "$@"

#!/usr/bin/env bash
# AI Marketing Suite — installer for Hermes Agent
#
# Usage:
#   ./install.sh                 Copy skills into $HERMES_HOME/skills/marketing (default)
#   ./install.sh --external      Keep skills in this repo; register it in skills.external_dirs
#   ./install.sh --with-pdf      Also install reportlab for PDF reports (combine with either mode)
#
# Remote (clone + install):
#   AIMS_REPO_URL=https://github.com/<you>/<repo>.git bash -c "$(curl -fsSL <raw-url>/install.sh)"

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
MODE="copy"
WITH_PDF=0
for arg in "$@"; do
  case "$arg" in
    --external) MODE="external" ;;
    --copy) MODE="copy" ;;
    --with-pdf) WITH_PDF=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
red() { printf '\033[0;31m%s\033[0m\n' "$*"; }

# Locate the repository (clone it when run through curl | bash)
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ] && [ -d "$(dirname "$SCRIPT_PATH")/skills/marketing" ]; then
  REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  : "${AIMS_REPO_URL:?Set AIMS_REPO_URL to the git URL of this repository}"
  REPO_DIR="${AIMS_INSTALL_DIR:-$HOME/ai-marketing-hermes}"
  if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only
  else
    git clone --depth 1 "$AIMS_REPO_URL" "$REPO_DIR"
  fi
fi

SRC="$REPO_DIR/skills/marketing"
echo "Repository:  $REPO_DIR"
echo "Hermes home: $HERMES_HOME"
echo "Mode:        $MODE"
echo

if command -v hermes >/dev/null 2>&1; then
  green "✓ hermes CLI found"
else
  yellow "⚠ hermes CLI not found in PATH (continuing; files are installed for when it is)"
fi
mkdir -p "$HERMES_HOME"

if [ "$MODE" = "copy" ]; then
  DEST="$HERMES_HOME/skills/marketing"
  mkdir -p "$DEST"
  for skill_dir in "$SRC"/*/; do
    name="$(basename "$skill_dir")"
    rm -rf "${DEST:?}/$name"
    cp -R "$skill_dir" "$DEST/$name"
    find "$DEST/$name" -name '*.py' -exec chmod +x {} +
    green "  ✓ $name"
  done
  yellow "Note: re-running the installer overwrites local edits Hermes made to these skills."
else
  CONFIG="$HERMES_HOME/config.yaml"
  touch "$CONFIG"
  if grep -qF "$REPO_DIR/skills" "$CONFIG"; then
    green "✓ $REPO_DIR/skills already listed in $CONFIG"
  elif ! grep -qE '^skills:' "$CONFIG"; then
    printf '\nskills:\n  external_dirs:\n    - %s\n' "$REPO_DIR/skills" >> "$CONFIG"
    green "✓ Added $REPO_DIR/skills to skills.external_dirs in $CONFIG"
  else
    yellow "⚠ $CONFIG already has a 'skills:' section. Add this line under skills.external_dirs manually:"
    echo
    echo "skills:"
    echo "  external_dirs:"
    echo "    - $REPO_DIR/skills"
    echo
  fi
  echo "Update later with: git -C $REPO_DIR pull"
fi

# Skill bundles (/marketing-agency, /marketing-content)
BUNDLE_DIR="$HERMES_HOME/skill-bundles"
mkdir -p "$BUNDLE_DIR"
for bundle in "$REPO_DIR"/bundles/*.yaml; do
  cp "$bundle" "$BUNDLE_DIR/"
  green "  ✓ bundle $(basename "$bundle" .yaml)"
done

# Output folder + watchlist template
OUT_DIR="$HOME/marketing-reports"
mkdir -p "$OUT_DIR"
[ -f "$OUT_DIR/watchlist.txt" ] || cp "$SRC/market-watch/templates/watchlist.txt" "$OUT_DIR/watchlist.txt"

# Python checks
echo
if command -v python3 >/dev/null 2>&1; then
  green "✓ $(python3 --version)"
  if python3 -c "import reportlab" 2>/dev/null; then
    green "✓ reportlab installed (PDF reports ready)"
  elif [ "$WITH_PDF" = 1 ]; then
    python3 -m pip install --user 'reportlab>=4.0' \
      || red "pip install failed. On Debian/Ubuntu try: sudo apt install python3-reportlab"
  else
    yellow "⚠ reportlab missing (needed for /market report-pdf). Re-run with --with-pdf or: sudo apt install python3-reportlab"
  fi
  if [ "$(uname)" = "Linux" ] && ! ls /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf >/dev/null 2>&1; then
    yellow "⚠ DejaVu fonts not found; Vietnamese in PDFs needs a Unicode font: sudo apt install fonts-dejavu-core"
  fi
else
  red "✗ python3 not found — helper scripts will not run"
fi

echo
green "Done. Start a new Hermes session (or send any message in an open one) and try:"
echo "  /market quick https://example.com"
echo "  /market audit https://example.com"
echo "  /marketing-agency https://example.com"
echo "Weekly monitoring: /market-watch, then accept the schedule with /suggestions"

#!/usr/bin/env bash
# AI Marketing Suite — installer for Hermes Agent
#
# Usage:
#   ./install.sh                 Copy skills into $HERMES_HOME/skills/marketing (default)
#   ./install.sh --external      Keep skills in this repo; register it in skills.external_dirs
#   ./install.sh --with-pdf      Also install reportlab for PDF reports (combine with either mode)
#
# Remote (clone + install):
#   AIMS_REPO_URL=https://github.com/vibeailabs-tech/ai-marketing-hermes.git bash -c "$(curl -fsSL https://raw.githubusercontent.com/vibeailabs-tech/ai-marketing-hermes/main/install.sh)"

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
  echo "  (hermes CLI not in PATH — normal when this runs inside a Hermes container/session)"
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
  if python3 "$REPO_DIR/tools/add_external_dir.py" "$CONFIG" "$REPO_DIR/skills"; then
    green "✓ $REPO_DIR/skills is in skills.external_dirs ($CONFIG)"
  else
    red "✗ Could not edit $CONFIG automatically (see message above). Make sure there is ONE top-level skills: block with:"
    echo "    - $REPO_DIR/skills"
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

# Python checks. PDF deps fall back to a private folder when pip/apt are blocked (containers, no sudo).
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ai-marketing-hermes"
PYLIB="$DATA_DIR/pylib"
FONT_DIR="$DATA_DIR/fonts"
has_reportlab() { PYTHONPATH="$PYLIB${PYTHONPATH:+:$PYTHONPATH}" python3 -c "import reportlab" 2>/dev/null; }
has_font() {
  for f in /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf /usr/share/fonts/dejavu/DejaVuSans.ttf \
           /usr/share/fonts/truetype/noto/NotoSans-Regular.ttf /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
           /System/Library/Fonts/Supplemental/Arial.ttf "$FONT_DIR/DejaVuSans.ttf"; do
    [ -f "$f" ] && return 0
  done
  return 1
}

echo
if command -v python3 >/dev/null 2>&1; then
  green "✓ $(python3 --version)"
  if ! has_reportlab && [ "$WITH_PDF" = 1 ]; then
    RL_SPEC='reportlab>=4.0'
    python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' || RL_SPEC='reportlab>=4.0,<4.5'   # reportlab 5 needs 3.10+
    echo "Installing $RL_SPEC..."
    python3 -m pip install -q --user "$RL_SPEC" 2>/dev/null \
      || python3 -m pip install -q --target "$PYLIB" "$RL_SPEC" 2>/dev/null \
      || { command -v uv >/dev/null 2>&1 && uv pip install -q --python "$(command -v python3)" --target "$PYLIB" "$RL_SPEC" 2>/dev/null; } \
      || true
  fi
  if has_reportlab; then
    green "✓ reportlab available (PDF reports ready)"
  else
    yellow "⚠ reportlab missing (needed for /market report-pdf). Re-run with --with-pdf, or: sudo apt install python3-reportlab"
  fi
  if ! has_font && [ "$WITH_PDF" = 1 ]; then
    echo "Downloading DejaVu fonts (Vietnamese support in PDFs)..."
    TMP_FONT="$(mktemp -d)"
    if curl -fsSL -o "$TMP_FONT/dejavu.tar.bz2" \
         https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2 \
       && tar -xjf "$TMP_FONT/dejavu.tar.bz2" -C "$TMP_FONT"; then
      mkdir -p "$FONT_DIR"
      cp "$TMP_FONT"/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf "$TMP_FONT"/dejavu-fonts-ttf-2.37/ttf/DejaVuSans-Bold.ttf "$FONT_DIR/"
    fi
    rm -rf "$TMP_FONT"
  fi
  if has_font; then
    green "✓ Unicode font available for PDFs"
  else
    yellow "⚠ No Unicode font: Vietnamese in PDFs may break. Re-run with --with-pdf, or: sudo apt install fonts-dejavu-core"
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

#!/usr/bin/env bash
# AI Marketing Suite — uninstaller for Hermes Agent
# Removes the copied skills and bundles. Reports in ~/marketing-reports are kept.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

if [ -d "$HERMES_HOME/skills/marketing" ]; then
  for skill in "$HERMES_HOME"/skills/marketing/market*/; do
    rm -rf "$skill"
    echo "  ✓ removed $(basename "$skill")"
  done
  rmdir "$HERMES_HOME/skills/marketing" 2>/dev/null || true
fi

for bundle in marketing-agency marketing-content; do
  rm -f "$HERMES_HOME/skill-bundles/$bundle.yaml"
done

echo
echo "Done. If you installed with --external, also remove the repo path from skills.external_dirs in $HERMES_HOME/config.yaml."
echo "Your reports in ~/marketing-reports were not touched."

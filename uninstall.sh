#!/usr/bin/env bash
# Remove the OCX Quota widget.
set -euo pipefail
kpackagetool6 -t Plasma/Applet -r io.github.hephaestuszero.ocxplasma
echo "Removed. If it was on a panel, restart plasmashell or remove the widget first."

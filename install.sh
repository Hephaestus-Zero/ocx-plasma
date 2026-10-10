#!/usr/bin/env bash
# Install or update the OCX Quota widget for KDE Plasma 6.
#
#   ./install.sh                                      # from a checkout
#   curl -fsSL https://raw.githubusercontent.com/Hephaestus-Zero/ocx-plasma/main/install.sh | bash
#
# When piped, this downloads the latest release .plasmoid (or a tarball of main
# as a fallback) — no local checkout needed.
set -euo pipefail

REPO="Hephaestus-Zero/ocx-plasma"
PKG_ID="io.github.hephaestuszero.ocxplasma"
DOMAIN="plasma_applet_$PKG_ID"

say() { printf '%s\n' "$*"; }
die() { say "error: $*" >&2; exit 1; }

command -v plasmashell >/dev/null 2>&1 || die "plasmashell not found — KDE Plasma 6 is required"
major=$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ "${major:-0}" -ge 6 ] || die "Plasma ${major:-?} found; version >= 6 is required"
command -v python3 >/dev/null 2>&1 || die "python3 not found — required by the quota collector"
command -v kpackagetool6 >/dev/null 2>&1 || die "kpackagetool6 not found — install plasma6-tools/kpackage"
command -v curl >/dev/null 2>&1 || die "curl not found"
command -v ocx >/dev/null 2>&1 \
    || say "note: 'ocx' not found yet — install opencodex: npm i -g @bitkyc08/opencodex"

# Compile po/*.po into contents/locale/<lang>/LC_MESSAGES/<domain>.mo, if msgfmt exists.
build_locale() {
    local root="$1" p l
    command -v msgfmt >/dev/null 2>&1 || return 0
    for p in "$root"/po/*.po; do
        [ -e "$p" ] || continue
        l=$(basename "$p" .po)
        mkdir -p "$root/contents/locale/$l/LC_MESSAGES"
        msgfmt -o "$root/contents/locale/$l/LC_MESSAGES/$DOMAIN.mo" "$p"
    done
}

install_pkg() {
    kpackagetool6 -t Plasma/Applet -u "$1" 2>/dev/null \
        || kpackagetool6 -t Plasma/Applet -i "$1"
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "${HERE:-}" ] && [ -f "$HERE/metadata.json" ]; then
    say "Installing from checkout: $HERE"
    build_locale "$HERE"
    install_pkg "$HERE"
else
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    say "Fetching latest release of $REPO…"
    url=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+\.plasmoid"' | head -1 | cut -d'"' -f4 || true)
    if [ -n "$url" ]; then
        curl -fsSL "$url" -o "$tmp/pkg.plasmoid"
        install_pkg "$tmp/pkg.plasmoid"
    else
        say "No .plasmoid release asset; installing a tarball of main instead."
        curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" -o "$tmp/src.tgz"
        tar -xzf "$tmp/src.tgz" -C "$tmp"
        src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
        build_locale "$src"
        install_pkg "$src"
    fi
fi

say ""
say "Done. Add the widget to a panel:"
say "  right-click a panel → 'Add or Manage Widgets…' → search 'OCX Quota' → drag it on."
say "If the widget was already running, restart plasmashell:"
say "  systemctl --user restart plasma-plasmashell.service   (or log out/in)"

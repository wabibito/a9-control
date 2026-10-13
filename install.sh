#!/bin/sh
# A9 Control installer.
#   curl -fsSL https://raw.githubusercontent.com/wabibito/a9-control/main/install.sh | sh
# Downloads the latest release package for your distribution and installs it.
set -eu

REPO=wabibito/a9-control
API=https://api.github.com/repos/$REPO/releases/latest

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -m)" = x86_64 ] || die "this package is for x86_64 machines"
if [ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" != "A9 Mega" ]; then
    say "Note: this is not a GEEKOM A9 Mega; the service will not start on other machines."
fi
command -v curl >/dev/null || die "curl is required"

if command -v apt-get >/dev/null; then
    EXT=deb
elif command -v dnf >/dev/null; then
    EXT=rpm
elif command -v pacman >/dev/null; then
    EXT=pkg.tar.zst          # Arch, CachyOS, EndeavourOS, Manjaro
else
    die "no supported package manager found (apt, dnf or pacman)"
fi

# An existing install is upgraded in place; settings and saved profiles are kept.
CURRENT=""
case "$EXT" in
    deb) CURRENT=$(dpkg-query -W -f='${Version}' a9-control 2>/dev/null || true) ;;
    rpm) CURRENT=$(rpm -q --qf '%{VERSION}' a9-control 2>/dev/null || true) ;;
    *)   CURRENT=$(pacman -Q a9-control 2>/dev/null | awk '{sub(/-[0-9]+$/, "", $2); print $2}') ;;
esac

say "Finding the latest release…"
RELEASE=$(curl -fsSL "$API")
# Match this package by name, not just by extension.
URL=$(printf '%s' "$RELEASE" \
    | grep -o "https://[^\"]*/a9-control[-_][0-9][^\"]*\.$EXT\"" | tr -d '"' | head -1)
LATEST=$(printf '%s' "$RELEASE" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
[ -n "$URL" ] || die "no .$EXT package in the latest release"
if [ -n "$CURRENT" ]; then
    [ "$CURRENT" = "$LATEST" ] && say "Version $CURRENT is already installed; reinstalling it." \
                               || say "Updating $CURRENT to $LATEST."
else
    say "Installing version $LATEST."
fi
FILE=$(mktemp -d)/$(basename "$URL")
say "Downloading $(basename "$URL")…"
curl -fsSL -o "$FILE" "$URL"

# pkexec shows a desktop password dialog; sudo is the fallback in a plain terminal.
if [ "$(id -u)" = 0 ]; then
    RUN=""
elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v pkexec >/dev/null; then
    RUN="pkexec"
else
    RUN="sudo"
fi

say "Installing (you may be asked for your password)…"
# Upgrade, reinstall or downgrade, whichever this file turns out to be.
case "$EXT" in
    deb) $RUN apt-get install -y --reinstall --allow-downgrades "$FILE" ;;
    rpm) $RUN dnf install -y --allowerasing "$FILE" || $RUN dnf reinstall -y "$FILE" ;;
    *)   $RUN pacman -U --noconfirm "$FILE" ;;
esac

say "Done. Open “A9 Control” from your apps, or run: a9 status"
say "Later updates: System → Updates in the app, or: a9 update"
say "Log out and back in once to get the top-bar menu."

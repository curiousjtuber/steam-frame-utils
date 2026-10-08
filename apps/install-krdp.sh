#!/usr/bin/env bash
# Build and install KRdp's server, krdpserver (Plasma's Remote Desktop), as a flatpak for the
# Frame, from apps/krdp/io.github.curiousjtuber.Krdp.yml. It serves a Plasma desktop running on
# the Frame (Frametop's or the stock one) over RDP, for KRDC, Remmina or Windows Remote Desktop;
# bin/krdpd starts and stops it. https://invent.kde.org/plasma/krdp
#
# Usage:  ~/steam-frame-utils/apps/install-krdp.sh [--uninstall]
#
# --uninstall  remove the app; the SDK and builder stay (the line to drop them is printed)
#
# SteamOS has no krdp, Flathub has no krdpserver (only the KRDC client), and anything built
# against the image's Plasma breaks at the next SteamOS update, so this builds it on KDE's
# runtime, which brings its own Qt, KF6, ffmpeg and PipeWire; FreeRDP, kpipewire and krdp are
# built here, with the pins and patches the manifest explains. Unlike the other apps, it goes in
# the user flatpak installation, not system-wide: flatpak-builder works without root there, and
# the build needs the KDE 6.11 SDK (about 1 GB to download, 4 GB on disk) and org.flatpak.Builder,
# which this installs on first use. The build itself takes about half an hour on the Frame.
# Downloads and build state stay in ~/.cache/krdpd/flatpak, so a re-run after a manifest change
# rebuilds only what changed, and a run with nothing changed does nothing. No root. Run it on the
# host, not in a distrobox.
#
# The sandbox: network (the RDP port), the GPU, flatpak's Wayland socket (the desktop to capture;
# bin/krdpd points it at the right one), the host's PipeWire socket, and ~/.config/krdpd read-only
# (the TLS certificate and key bin/krdpd makes). Nothing else of the home directory.
#
# Uninstall:
#   ~/steam-frame-utils/apps/install-krdp.sh --uninstall
#   flatpak --user uninstall org.kde.Sdk//6.11 org.flatpak.Builder   # the build tools, about 4 GB

set -euo pipefail

APP=io.github.curiousjtuber.Krdp
SDK=org.kde.Sdk//6.11
REPO_FILE=https://dl.flathub.org/repo/flathub.flatpakrepo
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
manifest=$here/krdp/$APP.yml
state=${XDG_CACHE_HOME:-$HOME/.cache}/krdpd/flatpak

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }
die() { echo "install-krdp.sh: $*" >&2; exit 1; }

case ${1:-} in
  "") ;;
  --uninstall)
    flatpak --user uninstall -y --noninteractive "$APP" 2>/dev/null && echo "removed $APP" || echo "$APP wasn't installed"
    echo "the build tools stay: flatpak --user uninstall $SDK org.flatpak.Builder"
    exit 0 ;;
  -h|--help) usage; exit 0 ;;
  *) die "unknown argument: $1 (see --help)" ;;
esac

[ -e /run/.containerenv ] && die "run this on the host, not in a distrobox"
command -v flatpak >/dev/null || die "flatpak not found"
[ -f "$manifest" ] || die "manifest not found: $manifest"

flatpak --user remote-add --if-not-exists flathub "$REPO_FILE"
flatpak --user install -y --noninteractive flathub "$SDK" org.flatpak.Builder//stable \
  org.freedesktop.Platform.openh264//2.5.1 2>&1 | grep -vE '^\s*$|is already installed' || true

mkdir -p "$state"
stamp=$(cat "$manifest" "$here"/krdp/*.patch | sha256sum | cut -c1-16)
if flatpak --user info "$APP" >/dev/null 2>&1 && [ "$(cat "$state/installed" 2>/dev/null)" = "$stamp" ]; then
  echo "$APP: installed and up to date with the manifest"
  exit 0
fi
echo "building $APP (about half an hour the first time)"
flatpak run org.flatpak.Builder --user --install --force-clean --install-deps-from=flathub \
  --state-dir="$state/state" "$state/build" "$manifest"
echo "$stamp" > "$state/installed"
echo "installed $APP ($(flatpak --user info "$APP" 2>/dev/null | sed -n 's/^ *Commit: \(.\{12\}\).*/\1/p'))"
echo "start it with: krdpd start   (see krdpd --help)"

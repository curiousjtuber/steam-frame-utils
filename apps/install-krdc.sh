#!/usr/bin/env bash
# Install or update KRDC (org.kde.krdc), KDE's RDP and VNC client, from Flathub, for desktops
# served by KRdp (Plasma's Remote Desktop). https://apps.kde.org/krdc
#
# Usage:  ~/steam-frame-utils/apps/install-krdc.sh [--yes]
#
# --yes  don't ask before downloading; it needs the KDE runtime (org.kde.Platform 6.10), which
#        Stream Frame already brings, else a few hundred MB from Flathub
#
# For desktop work rather than games: KRdp streams the whole workspace, every monitor, and its
# mouse input goes through KWin in the stream's coordinates, so the pointer lines up on a
# multi-monitor host, where Sunshine's virtual absolute mouse doesn't. The Flatpak bundles
# FreeRDP. System-wide, like Stream Frame and Moonlight, so it runs flatpak through sudo: polkit
# would ask for the password too, but over SSH there is no agent to ask with. The Frame already
# has the flathub system remote; it is added if missing. /var/lib/flatpak is a bind mount of
# /home/.steamos/offload/var/lib/flatpak, so SteamOS updates keep it.
#
# The sandbox: network and the GPU, nothing of the home directory.
#
# Uninstall:
#   sudo flatpak uninstall org.kde.krdc
#   sudo flatpak uninstall --unused     # the KDE runtime, if nothing else uses it

set -euo pipefail

APP=org.kde.krdc
REMOTE=flathub
REPO_FILE=https://dl.flathub.org/repo/flathub.flatpakrepo

yes=()
for arg in "$@"; do
  case $arg in
    --yes) yes=(-y) ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg (see --help)" >&2; exit 2 ;;
  esac
done

die() { echo "install-krdc.sh: $*" >&2; exit 1; }

[[ -z ${CONTAINER_ID:-} && ! -e /run/.containerenv ]] \
  || die "run it on the Frame's host, not in a distrobox: it installs a host Flatpak"
command -v flatpak >/dev/null || die "missing required command: flatpak"

if flatpak remotes --system --columns=name | grep -qxF "$REMOTE"; then
  echo "ok             remote $REMOTE"
else
  echo "add            remote $REMOTE from $REPO_FILE"
  sudo flatpak remote-add --system --if-not-exists "$REMOTE" "$REPO_FILE"
fi

if flatpak info --system "$APP" >/dev/null 2>&1; then
  echo "update         $APP"
  sudo flatpak update --system "${yes[@]}" "$APP"
else
  echo "install        $APP"
  sudo flatpak install --system "${yes[@]}" "$REMOTE" "$APP"
fi
echo "done: start KRDC from the menu, or run: flatpak run $APP"

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
# FreeRDP. The flathub user remote is added if missing.
# Into the user installation (~/.local/share/flatpak), like Frametop and krdpserver: no root and
# no polkit, so it works over SSH, and the home directory survives SteamOS updates. The KDE
# runtime goes into the user installation too, even when a system one would do, so removing
# system Flatpaks later can't break the app. A system copy, say one Discover installed, is
# reported: the user copy takes precedence, so remove the system one.
#
# The sandbox: network and the GPU, nothing of the home directory.
#
# Uninstall:
#   flatpak uninstall --user org.kde.krdc
#   flatpak uninstall --user --unused     # the KDE runtime, if nothing else uses it

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

add_remote() { # NAME REPO_FILE
  if flatpak remotes --user --columns=name | grep -qxF "$1"; then
    echo "ok             remote $1"
  else
    echo "add            remote $1 from $2"
    flatpak remote-add --user --if-not-exists "$1" "$2"
  fi
}
add_remote "$REMOTE" "$REPO_FILE"

if flatpak info --user "$APP" >/dev/null 2>&1; then
  echo "update         $APP"
  flatpak update --user "${yes[@]}" "$APP"
else
  echo "install        $APP"
  flatpak install --user "${yes[@]}" "$REMOTE" "$APP"
fi

# A runtime in the system installation satisfies the install, so flatpak wouldn't pull it into
# the user one; removing the system Flatpaks would then break the app.
runtime=$(flatpak info --user --show-runtime "$APP")
if flatpak info --user "$runtime" >/dev/null 2>&1; then
  echo "ok             runtime $runtime"
else
  echo "install        runtime $runtime, into the user installation too"
  flatpak install --user "${yes[@]}" flathub "$runtime"
fi

if flatpak info --system "$APP" >/dev/null 2>&1; then
  echo "note           a system copy of $APP is installed too; the user copy takes precedence"
  echo "               in the menu and in flatpak run. To remove it:"
  echo "               sudo flatpak uninstall --system $APP"
fi
echo "done: start KRDC from the menu, or run: flatpak run $APP"

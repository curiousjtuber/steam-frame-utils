#!/usr/bin/env bash
# Install or update Moonlight (com.moonlight_stream.Moonlight), the game-streaming client for
# Sunshine and GeForce Experience hosts, from Flathub. https://moonlight-stream.org
#
# Usage:  ~/steam-frame-utils/apps/install-moonlight.sh [--yes]
#
# --yes  don't ask before downloading; the first install also pulls the KDE runtime
#        (org.kde.Platform 6.11) from Flathub, about 400 MB
#
# Flathub, not apt in the ubuntu box: Ubuntu 26.04 has no moonlight-qt for arm64, and Flathub
# builds it for aarch64. System-wide, like Stream Frame, so it runs flatpak through sudo: polkit
# would ask for the password too, but over SSH there is no agent to ask with. The Frame already
# has the flathub system remote; it is added if missing. /var/lib/flatpak is a bind mount of
# /home/.steamos/offload/var/lib/flatpak, so SteamOS updates keep it.
#
# The sandbox: network, devices=all for the decoder and controllers, the host OS read-only, and
# the gamescope socket, so it also runs as a non-Steam game in Game Mode.
#
# Uninstall:
#   sudo flatpak uninstall com.moonlight_stream.Moonlight
#   sudo flatpak uninstall --unused     # the KDE runtime, if nothing else uses it

set -euo pipefail

APP=com.moonlight_stream.Moonlight
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

die() { echo "install-moonlight.sh: $*" >&2; exit 1; }

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
echo "done: start Moonlight from the menu, or run: flatpak run $APP"

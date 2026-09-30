#!/usr/bin/env bash
# Install or update Stream Frame (com.boxtree.StreamFrame), Boxtree's app for watching, recording
# and screenshotting the headset, from Boxtree's Flatpak repo. https://streamframe.app
#
# Usage:  ~/steam-frame-utils/apps/install-stream-frame.sh [--yes]
#
# --yes  don't ask before downloading; the first install also pulls the KDE runtime
#        (org.kde.Platform 6.10) from Flathub, a few hundred MB
#
# It adds the repo as the system remote stream-frame, the same one Discover adds from the website,
# and installs the app from it; a re-run updates it. System-wide, like the Frame's other Flatpak
# apps, so it runs flatpak through sudo: polkit would ask for the password too, but over SSH
# there is no agent to ask with. /var/lib/flatpak is a bind mount of
# /home/.steamos/offload/var/lib/flatpak, so SteamOS updates keep it.
#
# The headset side needs nothing more: SteamOS ships ffmpeg in /usr/bin.
#
# The sandbox is thin: devices=all, ~/.ssh read-only, the SSH agent, and talk access to
# org.freedesktop.Flatpak, which lets it run commands on the host.
#
# Uninstall:
#   sudo flatpak uninstall com.boxtree.StreamFrame
#   sudo flatpak remote-delete stream-frame
#   sudo flatpak uninstall --unused     # the KDE runtime, if nothing else uses it

set -euo pipefail

APP=com.boxtree.StreamFrame
REMOTE=stream-frame
REPO_FILE=https://streamframe.app/flatpak/stream-frame.flatpakrepo

yes=()
for arg in "$@"; do
  case $arg in
    --yes) yes=(-y) ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg (see --help)" >&2; exit 2 ;;
  esac
done

die() { echo "install-stream-frame.sh: $*" >&2; exit 1; }

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
echo "done: start Stream Frame from the menu, or run: flatpak run $APP"

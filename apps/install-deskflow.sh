#!/usr/bin/env bash
# Install or update Deskflow (org.deskflow.deskflow), the keyboard-and-mouse sharing tool, from
# Flathub, so a PC's mouse and keyboard reach the Frametop desktop. https://deskflow.org
#
# Usage:  ~/steam-frame-utils/apps/install-deskflow.sh [--yes]
#
# --yes  don't ask before downloading; it needs the KDE runtime (org.kde.Platform 6.11), which
#        Moonlight already brings, else about 400 MB from Flathub
#
# The Frame is the client, the PC the server. On Wayland the client injects input through the
# RemoteDesktop portal with libei, the same route KRdp takes into the Frametop desktop, so the
# nested KWin there accepts it. The first start asks once in the headset to allow remote control;
# Deskflow keeps the portal's restore token in its settings and reconnects without asking. On the
# PC the server side needs the InputCapture portal, which Plasma 6.7's portal offers. Flathub
# builds it for aarch64. System-wide, like Stream Frame and Moonlight, so it runs flatpak through
# sudo: polkit would ask for the password too, but over SSH there is no agent to ask with. The
# Frame already has the flathub system remote; it is added if missing. /var/lib/flatpak is a bind
# mount of /home/.steamos/offload/var/lib/flatpak, so SteamOS updates keep it.
#
# The sandbox: network, Wayland and the GPU, kdeglobals read-only, nothing else of the home
# directory. Portals are open to every Flatpak, so the policy needn't name them.
#
# Uninstall:
#   sudo flatpak uninstall org.deskflow.deskflow
#   sudo flatpak uninstall --unused     # the KDE runtime, if nothing else uses it

set -euo pipefail

APP=org.deskflow.deskflow
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

die() { echo "install-deskflow.sh: $*" >&2; exit 1; }

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
echo "done: start Deskflow from the menu, or run: flatpak run $APP"

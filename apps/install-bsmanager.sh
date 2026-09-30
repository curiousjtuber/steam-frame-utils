#!/usr/bin/env bash
# Install or update BSManager, the Beat Saber version, mod and map manager, from DaVarga's arm64
# fork. https://github.com/DaVarga/bs-manager
#
# Usage:  ~/steam-frame-utils/apps/install-bsmanager.sh [--uninstall | --appimage FILE]
#
# It runs the install.sh from the fork's latest release, with the same arguments. That puts the
# arm64 AppImage at ~/Applications/BSManager.AppImage, adds a menu entry, and registers BSManager
# for the bsmanager://, beatsaver://, bsplaylist://, modelsaber:// and web+bsmap:// links behind
# BeatSaver's OneClick buttons. BSManager then updates itself in place.
#
# No root: it is all in the home directory, which SteamOS updates keep, and the distroboxes share
# it. The installer is saved to a file before it runs, so a cut-off download can't run half of it.
#
# With maps shared, the game's CustomLevels is a link into BSManager's:
#   ~/.steam/steam/steamapps/common/Beat Saber/Beat Saber_Data/CustomLevels
#     -> ~/.local/share/BSManager/SharedContent/SharedMaps/CustomLevels
#
# --uninstall removes the AppImage, the menu entry and the icon, and keeps BSManager's data in
# ~/.local/share/BSManager and ~/.config/bs-manager.

set -euo pipefail

INSTALLER=https://github.com/DaVarga/bs-manager/releases/latest/download/install.sh

case ${1:-} in
  -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
esac

die() { echo "install-bsmanager.sh: $*" >&2; exit 1; }

(( EUID )) || die "run it as your user, not with sudo: it installs into your home directory"
command -v curl >/dev/null || die "missing required command: curl"

tmp=$(mktemp -d)
trap 'command rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/install.sh" "$INSTALLER" || die "can't download $INSTALLER"
bash "$tmp/install.sh" "$@"

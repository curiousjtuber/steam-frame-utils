#!/usr/bin/env bash
# Install or update Full Keyboard, TaiKeid's full-size virtual keyboard for the Frame's dashboard
# and local apps, from its GitHub releases. https://github.com/TaiKeid/steam-frame-full-keyboard
#
# Usage:  ~/steam-frame-utils/apps/install-full-keyboard.sh [--version X.Y.Z | --uninstall]
#
# --version X.Y.Z  that release instead of the latest
# --uninstall      remove the app, and keep its settings in ~/.config/framekeyboard
#
# It is a separate app, not a replacement for the system keyboard: start Full Keyboard from the
# dashboard's app launcher, with the VR session running, and SteamOS's keyboard button still
# opens the stock one. It types into the dashboard and local apps, desktop windows included, and
# not into streamed VR games. For a Steam Library shortcut, use Add a Non-Steam Game. Close it
# before updating; a second launch recenters the running one instead of starting another.
#
# The script takes the release's SHA256SUMS, downloads the arm64 archive named in it, checks the
# sum, and runs the install.sh inside the archive. That installer puts everything in the home
# directory, which SteamOS updates keep: the release under ~/.local/share/framekeyboard/releases,
# the active one as the current link there and the one before as previous, for rollback, the
# launcher ~/.local/bin/framekeyboard (setup.sh puts ~/.local/bin on PATH), and a menu entry. It
# refuses a version that is already in releases, so a re-run with nothing newer just says so.
#
# No root. It also works from a distrobox, since the home directory is shared.
#
# Rollback, when previous exists:
#   cd ~/.local/share/framekeyboard && ln -sfn "$(readlink previous)" current
#
# --uninstall removes the launcher, the menu entry and ~/.local/share/framekeyboard, which holds
# every release. Layouts, languages, themes and the saved placement stay in ~/.config/framekeyboard.

set -euo pipefail

REPO=https://github.com/TaiKeid/steam-frame-full-keyboard
INSTALL_ROOT=$HOME/.local/share/framekeyboard
LAUNCHER=$HOME/.local/bin/framekeyboard
DESKTOP=$HOME/.local/share/applications/framekeyboard.desktop

release=latest/download
uninstall=0
while (( $# )); do
  case $1 in
    --version)
      [[ ${2:-} =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || { echo "--version needs X.Y.Z (see --help)" >&2; exit 2; }
      release=download/${2#v}
      shift ;;
    --version=*) echo "write it as --version X.Y.Z (see --help)" >&2; exit 2 ;;
    --uninstall) uninstall=1 ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "install-full-keyboard.sh: $*" >&2; exit 1; }

(( EUID )) || die "run it as your user, not with sudo: it installs into your home directory"

# The running binary is $INSTALL_ROOT/current/bin/framekeyboard, and the launcher execs it.
if pgrep -x framekeyboard >/dev/null; then
  die "Full Keyboard is running: close it from its toolbar first"
fi

if (( uninstall )); then
  for path in "$LAUNCHER" "$DESKTOP" "$INSTALL_ROOT"; do
    if [[ -e $path || -L $path ]]; then
      echo "remove         $path"
      command rm -rf "$path"
    fi
  done
  echo "done: settings kept in ~/.config/framekeyboard"
  exit 0
fi

for cmd in curl sha256sum tar flock; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

tmp=$(mktemp -d)
trap 'command rm -rf "$tmp"' EXIT

sums_url=$REPO/releases/$release/SHA256SUMS
curl -fsSL -o "$tmp/SHA256SUMS" "$sums_url" || die "can't download $sums_url"

# The release checklist says the archive is named in SHA256SUMS and never renamed after hashing.
archive=$(grep -oE 'framekeyboard-[0-9]+\.[0-9]+\.[0-9]+-aarch64\.tar\.gz$' "$tmp/SHA256SUMS" \
  | head -1)
[[ -n $archive ]] || die "no arm64 archive listed in $sums_url"
version=${archive#framekeyboard-}
version=${version%-aarch64.tar.gz}

if [[ -e $INSTALL_ROOT/releases/$version ]]; then
  if [[ $(readlink "$INSTALL_ROOT/current" 2>/dev/null) == "releases/$version" ]]; then
    echo "ok             Full Keyboard $version"
  else
    echo "ok             Full Keyboard $version is installed but isn't current; to make it so:"
    echo "               ln -sfn releases/$version ~/.local/share/framekeyboard/current"
  fi
  exit 0
fi

echo "download       $archive"
curl -fsSL -o "$tmp/$archive" "$REPO/releases/$release/$archive" \
  || die "can't download $REPO/releases/$release/$archive"
echo "verify         $archive against SHA256SUMS"
(cd "$tmp" && grep -F " $archive" SHA256SUMS | sha256sum -c --quiet -) || die "checksum mismatch"

mkdir "$tmp/x"
tar -xzf "$tmp/$archive" -C "$tmp/x"
installers=("$tmp"/x/*/install.sh)
[[ ${#installers[@]} -eq 1 && -f ${installers[0]} ]] || die "$archive doesn't hold one install.sh"

echo "install        Full Keyboard $version"
bash "${installers[0]}"
echo "done: in the headset, open the dashboard and start Full Keyboard from the app launcher"

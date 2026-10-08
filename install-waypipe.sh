#!/usr/bin/env bash
# Install or update waypipe for the host from Arch Linux ARM's package, relocated under ~/.local.
#
# Usage:  ~/steam-frame-utils/install-waypipe.sh
#
# SteamOS has no waypipe, and Valve's package repos for the Frame don't carry it. Arch Linux ARM's
# aarch64 build needs only libc, libgcc, lz4 and zstd, all of which SteamOS has, and nothing
# outside its binary and man page, so `pacman-home relocate waypipe` moves its /usr tree under
# ~/.local and installs it there, in pacman-home's own database: no root, and SteamOS updates
# keep it. `setup.sh --waypipe` runs this when pacman-home doesn't have waypipe yet. See
# README.md#the-waypipe-function.
#
# pacman-home syncs Arch Linux ARM's package databases, about 10 MB, from one mirror (ALARM_MIRROR
# overrides it), downloads the package when the installed version differs, checks it against the
# database's checksum, and warns when the host lacks a library it needs, a newer glibc among them.
# The package's PGP signature isn't checked. A waypipe installed before pacman-home, a bare binary
# in ~/.local/bin, is backed up to waypipe.bak-<timestamp> first, since pacman won't write over a
# file it doesn't own.
#
# Uninstall:
#   pacman-home -R waypipe

set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACMAN_HOME=$SRC/bin/pacman-home
WAYPIPE=$HOME/.local/bin/waypipe
STAMP=$(date +%Y%m%d-%H%M%S)

case ${1:-} in
  '') ;;
  -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
  *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
esac

die() { echo "install-waypipe.sh: $*" >&2; exit 1; }
say() { printf '%-14s %s\n' "$1" "${2//$HOME/\~}"; }

# The package is checked against the host's libraries, not a distrobox's.
if [[ -n ${CONTAINER_ID:-} || -e /run/.containerenv ]]; then
  exec distrobox-host-exec "$0" "$@"
fi

(( EUID )) || die "run it as your user, not with sudo: it installs into your home directory"
[[ $(uname -m) == aarch64 ]] || die "Arch Linux ARM builds for aarch64, and this is $(uname -m)"
for cmd in pacman fakeroot bsdtar; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

if [[ -e $WAYPIPE || -L $WAYPIPE ]] && ! "$PACMAN_HOME" -Qo "$WAYPIPE" >/dev/null 2>&1; then
  command mv -f "$WAYPIPE" "$WAYPIPE.bak-$STAMP"
  say "back up" "$WAYPIPE, not pacman-home's -> $WAYPIPE.bak-$STAMP"
fi

"$PACMAN_HOME" relocate waypipe --noconfirm

ver=$("$PACMAN_HOME" -Q waypipe 2>/dev/null | awk '{print $2}') || true
say "installed" "$WAYPIPE${ver:+ $ver} from Arch Linux ARM, in pacman-home's database"
# Earlier versions noted which of two sources waypipe came from; there is one now.
command rm -f "$HOME/.local/state/steam-frame-utils/waypipe-source"

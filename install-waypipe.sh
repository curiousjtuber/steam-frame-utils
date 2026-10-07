#!/usr/bin/env bash
# Install or update waypipe for the host, in ~/.local/bin, from Arch Linux ARM's package.
#
# Usage:  ~/steam-frame-utils/install-waypipe.sh
#
# SteamOS has no waypipe, and Valve's package repos for the Frame don't carry it. Arch Linux ARM's
# aarch64 build needs only libc, libgcc, lz4 and zstd, all of which SteamOS has, so the binary
# alone goes in ~/.local/bin: no root, and SteamOS updates keep it. `setup.sh --waypipe=arch` runs
# this when waypipe is missing; `setup.sh --waypipe=box` takes a copy from the arch distrobox,
# the same package, instead. See README.md#the-waypipe-function.
#
# The version and checksum come from the repo's package database, about 10 MB, over https from one
# mirror (ALARM_MIRROR overrides it). The package is downloaded when the installed version differs
# or came from the box, checked against that checksum, and its binary run once before it is
# installed: should Arch Linux ARM's glibc move past SteamOS's, the installed one stays. The old
# binary is backed up to waypipe.bak-<timestamp>. The package's PGP signature isn't checked.
#
# Uninstall:
#   rm ~/.local/bin/waypipe ~/.local/state/steam-frame-utils/waypipe-source

set -euo pipefail

MIRROR=${ALARM_MIRROR:-https://fl.us.mirror.archlinuxarm.org}
REPO=$MIRROR/aarch64/extra
WAYPIPE=$HOME/.local/bin/waypipe
WAYPIPE_SOURCE=$HOME/.local/state/steam-frame-utils/waypipe-source
STAMP=$(date +%Y%m%d-%H%M%S)

case ${1:-} in
  '') ;;
  -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
  *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
esac

die() { echo "install-waypipe.sh: $*" >&2; exit 1; }
say() { printf '%-14s %s\n' "$1" "${2//$HOME/\~}"; }

# The new binary is tried against the host's libraries, not a distrobox's.
if [[ -n ${CONTAINER_ID:-} || -e /run/.containerenv ]]; then
  exec distrobox-host-exec "$0" "$@"
fi

(( EUID )) || die "run it as your user, not with sudo: it installs into your home directory"
[[ $(uname -m) == aarch64 ]] || die "Arch Linux ARM builds for aarch64, and this is $(uname -m)"
for cmd in curl tar xz sha256sum; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

tmp=$(mktemp -d)
trap 'command rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/extra.db" "$REPO/extra.db" || die "can't download $REPO/extra.db"
# The database is a tar of <name>-<version>-<release>/desc files, each a list of %KEY% lines.
entry=$(tar -tf "$tmp/extra.db" | grep -E '^waypipe-[^-]+-[^-]+/desc$' | head -n1) \
  || die "no waypipe in $REPO/extra.db"
desc=$(tar -xOf "$tmp/extra.db" "$entry")
field() { awk -v k="%$1%" '$0 == k { getline; print; exit }' <<<"$desc"; }
filename=$(field FILENAME) version=$(field VERSION) sum=$(field SHA256SUM)
[[ -n $filename && -n $version && $sum =~ ^[0-9a-f]{64}$ ]] \
  || die "can't read waypipe's entry in $REPO/extra.db"

installed=$("$WAYPIPE" --version 2>/dev/null | sed -n '1s/^waypipe //p' || true)
kept=$([[ -f $WAYPIPE_SOURCE ]] && tr -d '[:space:]' < "$WAYPIPE_SOURCE" || true)
if [[ $installed == "${version%-*}" && $kept == arch ]]; then
  say "ok" "$WAYPIPE $version from Arch Linux ARM"
  exit 0
fi

say "download" "$REPO/$filename"
curl -fsSL -o "$tmp/$filename" "$REPO/$filename" || die "can't download $REPO/$filename"
echo "$sum  $tmp/$filename" | sha256sum -c --quiet - >/dev/null \
  || die "$filename doesn't match the checksum in $REPO/extra.db"
tar -xf "$tmp/$filename" -C "$tmp" usr/bin/waypipe
new=$tmp/usr/bin/waypipe

# Its libraries are SteamOS's. One that can't start here, say for a newer glibc, isn't installed.
out=$("$new" --version 2>&1) && [[ $out == "waypipe ${version%-*}"* ]] \
  || die "the new waypipe doesn't run here, so the installed one stays:"$'\n'"$out"

if [[ -e $WAYPIPE || -L $WAYPIPE ]]; then
  command mv -f "$WAYPIPE" "$WAYPIPE.bak-$STAMP"
  say "back up" "$WAYPIPE -> $WAYPIPE.bak-$STAMP"
fi
install -D -m 0755 "$new" "$WAYPIPE"
say "install" "$WAYPIPE $version from Arch Linux ARM${installed:+, replacing $installed}"
mkdir -p "${WAYPIPE_SOURCE%/*}"
echo arch > "$WAYPIPE_SOURCE"

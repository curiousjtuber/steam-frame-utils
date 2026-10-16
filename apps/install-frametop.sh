#!/usr/bin/env bash
# Install or update Frametop, the multi-screen Plasma desktop and 3D mouse that run on the Frame
# itself, from a release on GitHub: built by its CI, checked here. https://github.com/Frametop/frametop
#
# Usage:  ~/steam-frame-utils/apps/install-frametop.sh [--version X.Y.Z] [--yes] [--no-eye-tracker]
#                 [--no-bluetooth | --bluetooth] [--any-steamos] [--unpack-only]
#         ~/steam-frame-utils/apps/install-frametop.sh --uninstall
#
# --version X.Y.Z   that release instead of the one this script records the sha256 of; the zip
#                   is then checked only against the release's own SHA256SUMS, which says so
# --yes             don't ask (install.sh's --yes): gaze mode yes, Frametop's own eye tracker
#                   only if sudo runs without a password, no Bluetooth fixes, no SteamVR restart
# --no-eye-tracker  don't offer Frametop's own eye tracker, the one part that is a root service
# --no-bluetooth    don't offer the Bluetooth fixes, the other part that writes to /etc
# --bluetooth       install the Bluetooth fixes without asking
# --any-steamos     install on a SteamOS build the release is known to break on
# --unpack-only     download and check the zip, load its image and copy the release's files
#                   out, but don't run their install.sh (the line to run it is printed)
# --uninstall       run the installed release's uninstall.sh: two runs, with a restart between
#
# It downloads the release's Frametop.zip (about 1.1 GB) and SHA256SUMS, checks the zip against
# the sha256 recorded below, so a release replaced after this script was written doesn't
# install, and against SHA256SUMS, unpacks it and runs its install-release.sh, Frametop's own
# installer. That one checks this SteamOS build against the releases' table (the newest from
# Frametop's main branch over https, the zip's copy when offline), checks the image file in the
# zip against the sha256 in its frametop-release.json, loads it into podman, copies the
# release's files to ~/.local/share/frametop/releases/VERSION (current links there; the release
# before stays, for rollback) and runs their install.sh, which builds and downloads nothing:
# a container from the image, the input relay, pointer and power services, the SteamVR driver,
# the desktop and the settings apps, all in the home directory. Two optional parts ask for sudo:
# the eye tracker's frame grabber, a root service in /etc/frametop, and the Bluetooth fixes in
# /etc/steamframe. Everything else needs no root. Run it on the host, not in a distrobox. The
# download stays in ~/.cache/frametop-install until the install succeeds, so a run that stops
# resumes where it was; a re-run with the same release reinstalls it, which is how it updates.
#
# A source checkout in ~/frametop is left alone, but the launcher's Desktop entry and the
# services switch to the release; running that checkout's install.sh switches them back.
#
# Rollback: ~/.local/share/frametop/releases/<the release before>/install.sh
# Uninstall: --uninstall, or ~/.local/share/frametop/releases/current/uninstall.sh

set -euo pipefail

REPO=https://github.com/Frametop/frametop
VERSION=0.2.2
ZIP_SHA256=2afa2a949010a05f98bd5181bb2bebe34778fff9d57c3a8a4e042da1a366588e
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/frametop-install
RELEASES=$HOME/.local/share/frametop/releases

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }
die() { echo "install-frametop.sh: $*" >&2; exit 1; }

version=$VERSION
uninstall=0
pass=()
while (( $# )); do
  case $1 in
    --version)
      [[ ${2:-} =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "--version needs X.Y.Z (see --help)"
      version=${2#v}
      shift ;;
    --version=*) die "write it as --version X.Y.Z (see --help)" ;;
    --yes|--no-eye-tracker|--no-bluetooth|--bluetooth|--any-steamos|--unpack-only) pass+=("$1") ;;
    --uninstall) uninstall=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

(( EUID )) || die "run it as your user, not with sudo: it installs into your home directory"
[ -e /run/.containerenv ] && die "run this on the host, not in a distrobox"
{ grep -qx 'ID=steamos' /etc/os-release && grep -qE '^VARIANT_ID="?vr"?$' /etc/os-release; } 2>/dev/null \
  || die "Frametop installs on a Steam Frame (SteamOS, VR variant)"

if (( uninstall )); then
  script=$RELEASES/current/uninstall.sh
  [[ -f $script ]] || die "no release in $RELEASES to uninstall (Frametop's own: curl -fsSL https://frametop.github.io/frametop/uninstall.sh | bash)"
  # Its second run deletes the releases, itself included: run a copy, pointed at the release.
  tmp=$(mktemp -d)
  trap 'command rm -rf "$tmp"' EXIT
  command cp "$script" "$tmp/uninstall.sh"
  bash "$tmp/uninstall.sh" --dir "$(readlink -f "$RELEASES/current")"
  exit
fi

for cmd in curl sha256sum unzip podman; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

base=$REPO/releases/download/v$version
zip=$CACHE/Frametop-$version.zip
mkdir -p "$CACHE"
echo "release        Frametop $version ($base)"
curl -fsSL --proto '=https' -o "$CACHE/SHA256SUMS" "$base/SHA256SUMS" \
  || die "can't download $base/SHA256SUMS (is there a release v$version?)"
listed=$(grep -E ' Frametop\.zip$' "$CACHE/SHA256SUMS" | cut -d' ' -f1)
[[ $listed =~ ^[0-9a-f]{64}$ ]] || die "the release's SHA256SUMS doesn't name Frametop.zip"
if [[ $version == "$VERSION" ]]; then
  [[ $listed == "$ZIP_SHA256" ]] \
    || die "the release's SHA256SUMS names another Frametop.zip than this script records: the release changed since this script was written"
  expected=$ZIP_SHA256
else
  echo "warning: this script records no sha256 for $version; the zip is checked only against the release's own SHA256SUMS" >&2
  expected=$listed
fi

if [[ -f $zip ]] && echo "$expected  $zip" | sha256sum -c --status -; then
  echo "download       $zip is here and checks out"
else
  if [[ -f $zip ]]; then
    echo "download       $zip is here but doesn't check out: deleted"
    command rm -f "$zip" "$zip.part"
  fi
  echo "download       Frametop.zip, about 1.1 GB (a run that stops resumes it)"
  curl -fL --proto '=https' --progress-bar -C - -o "$zip.part" "$base/Frametop.zip" \
    || die "the download didn't finish: run this again to resume it"
  command mv -f "$zip.part" "$zip"
  echo "verify         Frametop.zip against $([[ $version == "$VERSION" ]] && echo "the sha256 recorded here" || echo SHA256SUMS)"
  echo "$expected  $zip" | sha256sum -c --quiet - \
    || { command rm -f "$zip"; die "checksum mismatch: the download is deleted, run this again"; }
fi

unpacked=$CACHE/unpacked
command rm -rf "$unpacked"
echo "unpack         $zip"
unzip -q "$zip" -d "$unpacked" || { command rm -rf "$unpacked" "$zip"; die "the zip doesn't unpack: it is deleted, run this again"; }
installer=$unpacked/Frametop/install-release.sh
[[ -x $installer ]] || die "the zip holds no Frametop/install-release.sh"

echo "install        Frametop $version, with its install-release.sh"
status=0
"$installer" ${pass[@]+"${pass[@]}"} || status=$?
command rm -rf "$unpacked"
if (( status == 3 )); then
  command rm -f "$zip"
  die "the image inside the zip is damaged: the download is deleted, run this again"
fi
(( status == 0 )) || die "install-release.sh exited with $status; the download stays in $CACHE for a re-run"
command rm -rf "$CACHE"
if [[ " ${pass[*]-} " == *" --unpack-only "* ]]; then
  echo "done: Frametop $version is in $RELEASES/$version, not installed; the zip is deleted"
else
  echo "done: Frametop $version in $RELEASES/current; restart SteamVR, then Launch a program → Desktop"
fi

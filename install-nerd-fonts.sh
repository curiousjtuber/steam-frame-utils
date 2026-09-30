#!/usr/bin/env bash
# Install or update Nerd Fonts for the current user, in ~/.local/share/fonts.
#
# Usage:  ~/steam-frame-utils/install-nerd-fonts.sh [NAME...]
#
# NAME is a release archive without .tar.xz, as listed on
# https://github.com/ryanoasis/nerd-fonts/releases/latest: JetBrainsMono, FiraCode, Hack, Meslo,
# CascadiaCode, NerdFontsSymbolsOnly, ... Without one, it installs JetBrainsMono and
# NerdFontsSymbolsOnly.
#
# No root and no steamos-readonly: fontconfig reads ~/.local/share/fonts under Wayland and X11
# alike, Flatpak apps see it too, and /home survives SteamOS updates. The host and its distroboxes
# share it.
#
# Each font goes in its own ~/.local/share/fonts/NerdFonts/NAME, with a .version file. A re-run
# replaces only fonts older than the latest release. Archives are checked against the release's
# SHA-256.txt. NerdFontsSymbolsOnly also brings a fontconfig rule, copied to
# ~/.config/fontconfig/conf.d, that makes every font fall back to it for the icons.
#
# Restart running apps to see a new font. In a terminal, pick the "Nerd Font Mono" family, so each
# icon takes one cell.
#
# Uninstall:
#   rm -rf ~/.local/share/fonts/NerdFonts/NAME && fc-cache -f
#   # for NerdFontsSymbolsOnly:
#   rm ~/.config/fontconfig/conf.d/10-nerd-font-symbols.conf

set -euo pipefail

REPO=https://github.com/ryanoasis/nerd-fonts
FONTS=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts
CONFD=${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d

names=()
for arg in "$@"; do
  case $arg in
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    -*) echo "unknown argument: $arg (see --help)" >&2; exit 2 ;;
    *) names+=("${arg%.tar.xz}") ;;
  esac
done
(( ${#names[@]} )) || names=(JetBrainsMono NerdFontsSymbolsOnly)

die() { echo "install-nerd-fonts.sh: $*" >&2; exit 1; }
say() { printf '%-14s %s\n' "$1" "${2//$HOME/\~}"; }

(( EUID )) || die "run it as your user, not with sudo: the fonts go in your home directory"
for cmd in curl tar xz sha256sum fc-cache fc-scan; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

# releases/latest redirects to .../releases/tag/<tag>. Resolving it once keeps the checksums and
# every archive from the same release.
tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") \
  || die "can't reach $REPO"
tag=${tag##*/}
[[ $tag == v* ]] || die "unexpected latest release: $tag"

tmp=$(mktemp -d)
trap 'command rm -rf "$tmp"' EXIT

installed=()
for name in "${names[@]}"; do
  dir=$FONTS/$name
  if [[ -f $dir/.version && $(<"$dir/.version") == "$tag" ]]; then
    say "ok" "$name $tag"
    continue
  fi

  [[ -s $tmp/SHA-256.txt ]] \
    || curl -fsSL -o "$tmp/SHA-256.txt" "$REPO/releases/download/$tag/SHA-256.txt"
  sum=$(awk -v f="$name.tar.xz" '$2 == f { print $1 }' "$tmp/SHA-256.txt")
  [[ -n $sum ]] || die "no $name in the $tag release; see $REPO/releases/latest for the names"

  say "download" "$name $tag"
  curl -fsSL -o "$tmp/$name.tar.xz" "$REPO/releases/download/$tag/$name.tar.xz"
  echo "$sum  $tmp/$name.tar.xz" | sha256sum -c --quiet - >/dev/null \
    || die "$name.tar.xz doesn't match the release's SHA-256.txt"

  mkdir -p "$tmp/$name"
  tar -xJf "$tmp/$name.tar.xz" -C "$tmp/$name"
  echo "$tag" > "$tmp/$name/.version"
  mkdir -p "$FONTS"
  command rm -rf "$dir"
  command mv -f "$tmp/$name" "$dir"
  say "install" "$dir"

  for conf in "$dir"/*.conf; do
    [[ -e $conf ]] || continue
    install -D -m 0644 "$conf" "$CONFD/${conf##*/}"
    say "copy" "$CONFD/${conf##*/}"
  done
  installed+=("$dir")
done

if (( ${#installed[@]} )); then
  fc-cache -f "$FONTS"
  echo "restart running apps to see the new fonts. Families:"
  fc-scan --format '%{family[0]}\n' "${installed[@]}" | sort -u | sed 's/^/  /'
fi

#!/usr/bin/env bash
# Set up a Steam Frame's user environment from this repo. Run it on the Frame's bare host, as the
# steamos user; re-running it only changes what is missing or out of date.
#
# Usage:  ./setup.sh [--check] [--tailscale[=trust]]
#
# --check           report what would change, and change nothing
# --tailscale       also run install-tailscale.sh (with sudo) if tailscaled isn't installed;
#                   --tailscale=trust passes --trust-tailnet
#
# Files are copied, not linked, so the Frame keeps working if this checkout moves or is deleted.
# A file that differs is backed up to <file>.bak-<timestamp> before it is replaced. Text inserted
# into shared files sits between "# >>> steam-frame-utils: <name> >>>" markers, and a later run
# replaces the block in place.

set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

check=0
tailscale=
for arg in "$@"; do
  case $arg in
    --check) check=1 ;;
    --tailscale) tailscale=plain ;;
    --tailscale=trust) tailscale=trust ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

changed=0
reboot_needed=0

say()  { printf '%-14s %s\n' "$1" "${2//$HOME/\~}"; }
act()  { changed=1; if (( check )); then say "would $2" "$1"; else say "$2" "$1"; fi; }

# append FILE -- stdin goes after the file's last line, even one without a trailing newline
append() {
  [[ -s $1 && $(tail -c1 "$1") != '' ]] && printf '\n' >> "$1"
  cat >> "$1"
}

backup() {
  if [[ -e $1 || -L $1 ]]; then
    if (( check )); then
      say "would back up" "$1"
    else
      command mv -f "$1" "$1.bak-$STAMP"
      say "back up" "$1 -> $1.bak-$STAMP"
    fi
  fi
}

# copy_file SRC DST MODE
copy_file() {
  local src=$1 dst=$2 mode=$3
  if [[ -f $dst && ! -L $dst ]] && cmp -s "$src" "$dst"; then
    say "ok" "$dst"
    return 1
  fi
  [[ -e $dst || -L $dst ]] && backup "$dst"
  act "$dst" "copy"
  (( check )) || install -D -m "$mode" "$src" "$dst"
}

# ensure_line FILE LINE -- appends LINE unless the file already has it verbatim
ensure_line() {
  local file=$1 line=$2
  if [[ -f $file ]] && grep -qxF -- "$line" "$file"; then
    say "ok" "$file: $line"
    return
  fi
  act "$file: $line" "add"
  (( check )) || printf '%s\n' "$line" | append "$file"
}

# ensure_block FILE NAME CONTENT_FILE -- the marked block NAME holds exactly CONTENT_FILE
ensure_block() {
  local file=$1 name=$2 content=$3
  local begin="# >>> steam-frame-utils: $name >>>" end="# <<< steam-frame-utils: $name <<<"
  local want; want=$(printf '%s\n' "$begin"; cat "$content"; printf '%s\n' "$end")
  if [[ -f $file ]] && grep -qxF -- "$begin" "$file"; then
    local have; have=$(sed -n "\|^$begin\$|,\|^$end\$|p" "$file")
    if [[ $have == "$want" ]]; then
      say "ok" "$file: block $name"
      return
    fi
    act "$file: block $name" "update"
    (( check )) && return
    awk -v b="$begin" -v e="$end" -v f="$content" '
      $0 == b { print; while ((getline l < f) > 0) print l; skip = 1; next }
      $0 == e { skip = 0 }
      !skip' "$file" > "$file.tmp.$$"
    command mv -f "$file.tmp.$$" "$file"
  else
    act "$file: block $name" "add"
    (( check )) || printf '%s\n' "$want" | append "$file"
  fi
}

# --- Where we are -------------------------------------------------------------------------------

if [[ -n ${CONTAINER_ID:-} || -e /run/.containerenv ]]; then
  echo "setup.sh: run this on the Frame's host, not inside a distrobox" >&2
  exit 1
fi
# The Frame's image is SteamOS with VARIANT_ID=vr, on arm64; a Steam Deck is SteamOS on x86_64.
os=$(. /etc/os-release 2>/dev/null; echo "${ID:-?} ${VARIANT_ID:-?}")
if [[ $os != "steamos vr" || $(uname -m) != aarch64 ]]; then
  echo "setup.sh: this isn't a Steam Frame (os-release: $os, arch: $(uname -m));" \
    "set FORCE=1 to run anyway" >&2
  [[ ${FORCE:-} == 1 ]] || exit 1
fi

# --- ~/.local/bin on PATH -------------------------------------------------------------------------
# distrobox, its exports and bin/podman live there, and podman has to win over /usr/bin/podman.

PATH_LINE='export PATH=~/.local/bin:$PATH'
ensure_line "$HOME/.bashrc" "$PATH_LINE"
ensure_line "$HOME/.profile" "$PATH_LINE"

# --- distrobox ----------------------------------------------------------------------------------

if [[ -x $HOME/.local/bin/distrobox ]]; then
  say "ok" "distrobox $("$HOME/.local/bin/distrobox" version 2>/dev/null | sed 's/.*: *//')"
else
  act "distrobox into ~/.local" "install"
  (( check )) || curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install \
    | sh -s -- --prefix "$HOME/.local"
fi

# --- bin/podman: distrobox from Desktop Mode --------------------------------------------------------

copy_file "$SRC/bin/podman" "$HOME/.local/bin/podman" 0755 || true

# --- Mouse cursor in Desktop Mode ---------------------------------------------------------------

conf=90-kwin-software-cursor.conf
copy_file "$SRC/environment.d/$conf" "$HOME/.config/environment.d/$conf" 0644 && reboot_needed=1

# --- Shell init ---------------------------------------------------------------------------------

# The containers share these rc files, so each block works on the host and in a distrobox alike.
# zsh only exists inside a distrobox, so ~/.zshrc is optional.
rcs=("$HOME/.bashrc")
if [[ -f $HOME/.zshrc ]]; then
  rcs+=("$HOME/.zshrc")
else
  say "skip" "$HOME/.zshrc doesn't exist"
fi

for rc in "${rcs[@]}"; do
  ensure_block "$rc" tailscale "$SRC/shell-init/tailscale.sh"
  ensure_block "$rc" waypipe "$SRC/shell-init/waypipe.sh"
done

# --- Tailscale ----------------------------------------------------------------------------------

if systemctl is-enabled --quiet tailscaled 2>/dev/null && [[ -x /home/.tailscale/bin/tailscale ]]; then
  say "ok" "tailscaled"
elif [[ -z $tailscale ]]; then
  say "missing" "tailscaled (re-run with --tailscale, or see README.md#tailscale)"
else
  act "tailscale via install-tailscale.sh" "install"
  if (( ! check )); then
    args=()
    [[ $tailscale == trust ]] && args+=(--trust-tailnet)
    sudo bash "$SRC/install-tailscale.sh" "${args[@]}"
    echo "log in with: sudo /home/.tailscale/bin/tailscale up --qr --operator=$USER --ssh"
  fi
fi

# --- Done ---------------------------------------------------------------------------------------

if (( ! changed )); then
  echo "everything is up to date"
elif (( check )); then
  echo "run without --check to apply"
else
  (( reboot_needed )) && echo "reboot for the environment.d change to reach Desktop Mode"
  echo "open a new shell for the shell init changes"
fi

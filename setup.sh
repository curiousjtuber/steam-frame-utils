#!/usr/bin/env bash
# Set up a Steam Frame's user environment from this repo, as the steamos user. Re-running it only
# changes what is missing or out of date.
#
# Usage:  ./setup.sh [--check] [--yes] [--brew] [--zsh] [--ubuntu] [--emacs]
#                   [--waypipe[=arch|box]] [--tailscale[=trust]] [--nerd-fonts[=NAME,...]]
#
# With no options it puts ~/.local/bin on PATH, and installs distrobox, the ~/.distroboxrc block
# that finds bin/podman, the Desktop Mode cursor fix, and, in ~/.bashrc and ~/.zshrc, this
# checkout's bin/ on PATH and the Frametop desktop terminal fix.
#
# --check           report what would change, and change nothing
# --yes             create the ubuntu box without asking first
# --brew            Homebrew in /home/linuxbrew/.linuxbrew if it isn't there, wl-clipboard from
#                   it, and brew shellenv in ~/.bashrc and ~/.zshrc; uses sudo once, to create
#                   /home/linuxbrew
# --zsh             zsh from Homebrew; implies --brew
# --ubuntu          create the ubuntu distrobox if it doesn't exist. It asks first: the image is
#                   about 1.2 GB, and the box's first start takes several minutes.
# --emacs           emacs-pgtk from the ubuntu box, replacing emacs-gtk, with emacs and emacsclient
#                   exported to ~/.local/bin; implies --ubuntu
# --waypipe         waypipe in ~/.local/bin for the host, from one of two sources, and the Game
#                   Mode waypipe function in ~/.bashrc and ~/.zshrc. --waypipe=arch runs
#                   install-waypipe.sh, Arch Linux ARM's package, when waypipe is missing; re-run
#                   that script to update it. --waypipe=box takes a copy from the ubuntu box, which
#                   apt keeps up to date; implies --ubuntu. The choice is kept in
#                   ~/.local/state/steam-frame-utils/waypipe-source, so a bare --waypipe reuses
#                   it; the first time, it asks.
# --tailscale       also fix what's missing of tailscaled (binaries, unit, enabled, running) and
#                   of the tailscale alias in ~/.bashrc and ~/.zshrc; uses sudo.
#                   --tailscale=trust also puts tailscale0 in firewalld's trusted zone.
#                   Without it, what's missing is only reported.
# --nerd-fonts      install-nerd-fonts.sh for each NAME not installed yet, JetBrainsMono and
#                   NerdFontsSymbolsOnly by default. Re-run install-nerd-fonts.sh itself to
#                   update them.
#
# The host and its distroboxes share the home directory, so it also runs inside a distrobox,
# except for what needs the host: --tailscale, --brew and --zsh always, and --ubuntu, --emacs and
# --waypipe=box from any box but ubuntu itself.
#
# bin/ goes on PATH from this checkout, for shells and for distrobox, so a git pull updates its
# scripts; after moving the checkout, re-run this. Other files are copied, not linked, so they keep
# working if it moves or is deleted. A file that differs is backed up to <file>.bak-<timestamp>
# before it is replaced. Text inserted into shared files sits between
# "# >>> steam-frame-utils: <name> >>>" markers, and a later run replaces the block in place.

set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The rc files get its path inside double quotes, and with_src passes it through sed.
case $SRC in
  *[\"\$\`\\\|\&]*)
    echo "setup.sh: can't put $SRC on PATH: move the checkout to a path without \" \$ \` \\ | or &" >&2
    exit 1 ;;
esac
STAMP=$(date +%Y%m%d-%H%M%S)
BOX=ubuntu
IMAGE=quay.io/toolbx/ubuntu-toolbox:26.04
# Set when the host re-runs this script inside the ubuntu box for the box's own part.
IN_BOX_RUN=${SFU_IN_BOX:-}

check=0 yes=0 want_brew=0 want_zsh=0 want_ubuntu=0 want_emacs=0 want_waypipe=0
waypipe_src=
tailscale=
nerd_fonts=
for arg in "$@"; do
  case $arg in
    --check) check=1 ;;
    --yes) yes=1 ;;
    --brew) want_brew=1 ;;
    --zsh) want_zsh=1 want_brew=1 ;;
    --ubuntu) want_ubuntu=1 ;;
    --emacs) want_emacs=1 want_ubuntu=1 ;;
    --waypipe) want_waypipe=1 ;;
    --waypipe=arch|--waypipe=box) want_waypipe=1 waypipe_src=${arg#*=} ;;
    --tailscale) tailscale=plain ;;
    --tailscale=trust) tailscale=trust ;;
    --nerd-fonts) nerd_fonts=JetBrainsMono,NerdFontsSymbolsOnly ;;
    --nerd-fonts=?*) nerd_fonts=${arg#*=} ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

changed=0
reboot_needed=0

say()  { printf '%-14s %s\n' "$1" "${2//$HOME/\~}"; }
act()  { changed=1; if (( check )); then say "would $2" "$1"; else say "$2" "$1"; fi; }
die()  { echo "setup.sh: $*" >&2; exit 1; }

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

# ensure_block FILE NAME CONTENT_FILE [top] -- the marked block NAME holds exactly CONTENT_FILE.
# A new block goes at the end of FILE, or with "top" at the start; an existing one stays put.
ensure_block() {
  local file=$1 name=$2 content=$3 where=${4:-end}
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
    (( check )) && return
    if [[ $where == top && -s $file ]]; then
      { printf '%s\n' "$want"; cat "$file"; } > "$file.tmp.$$"
      command mv -f "$file.tmp.$$" "$file"
    else
      printf '%s\n' "$want" | append "$file"
    fi
  fi
}

# with_src FILE -- FILE with @SRC@ as this checkout, written with $HOME when it is under it
with_src() { sed "s|@SRC@|${SRC/#$HOME/\$HOME}|g" "$1"; }

# block_lines FILE in|out -- FILE's lines inside, or outside, its steam-frame-utils blocks
block_lines() {
  awk -v want="$2" '
    /^# >>> steam-frame-utils: .* >>>$/ { inside = 1; next }
    /^# <<< steam-frame-utils: .* <<<$/ { inside = 0; next }
    (want == "in") == inside' "$1"
}

# remove_block FILE NAME
remove_block() {
  local file=$1 name=$2
  local begin="# >>> steam-frame-utils: $name >>>" end="# <<< steam-frame-utils: $name <<<"
  [[ -f $file ]] && grep -qxF -- "$begin" "$file" || return 0
  act "$file: block $name" "remove"
  (( check )) && return
  awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip; $0 == e { skip = 0 }' "$file" \
    > "$file.tmp.$$"
  command mv -f "$file.tmp.$$" "$file"
}

# --- Where we are -------------------------------------------------------------------------------

box=${CONTAINER_ID:-}
if [[ -z $box && -e /run/.containerenv ]]; then
  box=$(sed -n 's/^name="\(.*\)"$/\1/p' /run/.containerenv)
  box=${box:-unknown}
fi

# The Frame's image is SteamOS with VARIANT_ID=vr, on arm64; a Steam Deck is SteamOS on x86_64.
# Inside a distrobox, the host's os-release is under /run/host.
osrel=/etc/os-release
[[ -n $box ]] && osrel=/run/host/etc/os-release
os=$(. "$osrel" 2>/dev/null; echo "${ID:-?} ${VARIANT_ID:-?}")
if [[ $os != "steamos vr" || $(uname -m) != aarch64 ]]; then
  echo "setup.sh: this isn't a Steam Frame (os-release: $os, arch: $(uname -m));" \
    "set FORCE=1 to run anyway" >&2
  [[ ${FORCE:-} == 1 ]] || exit 1
fi

# --- Which waypipe: --waypipe[=arch|box] ----------------------------------------------------------
# The source chosen once is kept, so that a bare --waypipe on a re-run doesn't ask again, and so
# that the box's copy and Arch Linux ARM's don't replace each other.

WAYPIPE=$HOME/.local/bin/waypipe
WAYPIPE_SOURCE=$HOME/.local/state/steam-frame-utils/waypipe-source

waypipe_source_kept() { [[ -f $WAYPIPE_SOURCE ]] && tr -d '[:space:]' < "$WAYPIPE_SOURCE" || true; }

# remember_waypipe arch|box
remember_waypipe() {
  [[ $(waypipe_source_kept) == "$1" ]] && return 0
  act "$WAYPIPE_SOURCE: $1" "note"
  (( check )) && return 0
  mkdir -p "${WAYPIPE_SOURCE%/*}"
  echo "$1" > "$WAYPIPE_SOURCE"
}

ask_waypipe_source() {
  (: </dev/tty) 2>/dev/null \
    || die "--waypipe needs its source the first time: --waypipe=arch or --waypipe=box (see --help)"
  cat >&2 <<EOF
Where should waypipe come from?
  arch  Arch Linux ARM's package, through install-waypipe.sh: a 1.7 MB download, no distrobox
        needed, and usually the newer version. Re-run install-waypipe.sh to update it.
  box   a copy of the ubuntu distrobox's /usr/bin/waypipe, which apt keeps up to date. Needs the
        box, about 1.2 GB if it isn't there yet.
EOF
  local answer
  read -r -p "arch or box? " answer </dev/tty \
    || die "no answer; pass --waypipe=arch or --waypipe=box"
  case $answer in
    arch|box) waypipe_src=$answer ;;
    *) die "answer arch or box, or pass --waypipe=arch or --waypipe=box" ;;
  esac
}

if (( want_waypipe )) && [[ -z $waypipe_src ]]; then
  kept=$(waypipe_source_kept)
  if [[ $kept == arch || $kept == box ]]; then
    waypipe_src=$kept
  elif [[ -n $kept ]]; then
    die "$WAYPIPE_SOURCE says '$kept'; it should say arch or box"
  elif [[ -e $WAYPIPE ]]; then
    # Earlier versions had the box as the only source, and kept no note.
    waypipe_src=box
  else
    ask_waypipe_source
  fi
fi
want_waypipe_box=0
(( want_waypipe )) && [[ $waypipe_src == box ]] && want_waypipe_box=1 want_ubuntu=1

if [[ -n $box ]]; then
  [[ -z $tailscale ]] || die "--tailscale needs the Frame's host; run it there, not in the $box box"
  (( ! want_brew )) \
    || die "--brew and --zsh need the Frame's host, since a distrobox doesn't see /home/linuxbrew;" \
      "run it there, not in the $box box"
  (( ! want_ubuntu )) || [[ $box == "$BOX" ]] \
    || die "--ubuntu, --emacs and --waypipe=box need the host or the $BOX box, not the $box box"
fi

# bin/podman and distrobox's exports have to win even when the caller's PATH lacks them, as it
# can on a first run in Desktop Mode.
export PATH=$SRC/bin:$HOME/.local/bin:$PATH

# --- Inside the ubuntu box ----------------------------------------------------------------------
# The box's own part of --emacs and --waypipe=box: apt packages, and the exports into the shared
# ~/.local/bin. The host runs this through distrobox enter.

apt_updated=0
# apt_ensure PKG [APT_ARG...] -- the extra arguments go to apt-get install
apt_ensure() {
  if dpkg -s "$1" >/dev/null 2>&1; then
    say "ok" "$1 in the $BOX box"
    return
  fi
  act "$1 in the $BOX box" "apt install"
  (( check )) && return
  (( apt_updated )) || { sudo apt-get update -qq; apt_updated=1; }
  sudo apt-get install -y "$@"
}

# box_export NAME -- the box's /usr/bin/NAME as ~/.local/bin/NAME. One that exists and isn't
# this box's export is left alone.
box_export() {
  local bin=$HOME/.local/bin/$1
  if [[ ! -e $bin ]]; then
    act "$bin, exported from the $BOX box" "export"
    (( check )) || distrobox-export --bin "/usr/bin/$1" --export-path "$HOME/.local/bin" >/dev/null
  elif grep -qF -- "-n $BOX " "$bin"; then
    say "ok" "$bin, exported from the $BOX box"
  else
    say "skip" "$bin exists and isn't the $BOX box's export; left alone"
  fi
}

in_box_part() {
  if (( want_emacs )); then
    # emacs-pgtk is the Wayland build. It conflicts with emacs-gtk, the X11 build that the plain
    # emacs package picks, so that one is removed. mailutils is only a recommendation, and brings
    # postfix along.
    apt_ensure emacs-pgtk emacs-gtk- mailutils-
    box_export emacs
    box_export emacsclient
  fi
  if (( want_waypipe_box )); then
    apt_ensure waypipe
    # The host runs a plain copy of the box's binary; its libraries are all on SteamOS too.
    if [[ -e /usr/bin/waypipe ]]; then
      copy_file /usr/bin/waypipe "$WAYPIPE" 0755 || true
      remember_waypipe box
    else
      act "$WAYPIPE, from the $BOX box" "copy"
    fi
  fi
}

if [[ -n $IN_BOX_RUN ]]; then
  in_box_part
  # 100 tells the host's run that something changed.
  (( changed )) && exit 100
  exit 0
fi

# --- ~/.local/bin on PATH -------------------------------------------------------------------------
# distrobox and its exports live there.
# Any line that already puts it on PATH counts, however it spells the home directory.

for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  if [[ -f $rc ]] && grep -qE "^[^#]*PATH=.*(~|\\\$HOME|\\\$\\{HOME\\}|$HOME)/\\.local/bin" "$rc"; then
    say "ok" "$rc: ~/.local/bin on PATH"
  else
    act "$rc: export PATH=~/.local/bin:\$PATH" "add"
    (( check )) || printf '%s\n' 'export PATH=~/.local/bin:$PATH' | append "$rc"
  fi
done

# --- distrobox ----------------------------------------------------------------------------------

DISTROBOX=$HOME/.local/bin/distrobox
if [[ -x $DISTROBOX ]]; then
  say "ok" "distrobox $("$DISTROBOX" version 2>/dev/null | sed 's/.*: *//')"
else
  act "distrobox into ~/.local" "install"
  (( check )) || curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install \
    | sh -s -- --prefix "$HOME/.local"
fi

# --- bin/podman: distrobox from Desktop Mode --------------------------------------------------------
# distrobox has to find it even where the caller's PATH doesn't have bin/, as for an export started
# from a launcher.

content=$(mktemp)
with_src "$SRC/distrobox/distroboxrc" > "$content"
ensure_block "$HOME/.distroboxrc" podman "$content"
command rm -f "$content"

# --- Copies of bin/ from earlier versions ---------------------------------------------------------
# ~/.local/bin comes first in PATH, so an old copy would hide the checkout's script. It is backed
# up rather than deleted, in case it was edited by hand.

for src in "$SRC"/bin/*; do
  name=${src##*/}
  old=$HOME/.local/bin/$name
  [[ -f $old && ! -L $old ]] || continue
  if sed -n 2p "$old" | grep -q '^# steam-frame-utils:'; then
    act "$old -> $old.bak-$STAMP, an earlier version's copy of bin/$name" "back up"
    (( check )) || command mv -f "$old" "$old.bak-$STAMP"
  else
    say "skip" "$old isn't from steam-frame-utils, and hides bin/$name; left alone"
  fi
done

# --- Mouse cursor in Desktop Mode ---------------------------------------------------------------

conf=90-kwin-software-cursor.conf
copy_file "$SRC/environment.d/$conf" "$HOME/.config/environment.d/$conf" 0644 && reboot_needed=1

# --- Nerd Fonts: --nerd-fonts ------------------------------------------------------------------
# Only whether each font is there at all; updating needs the network, so it is left to
# install-nerd-fonts.sh.

if [[ -n $nerd_fonts ]]; then
  FONTS=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts
  fonts_missing=()
  for name in ${nerd_fonts//,/ }; do
    if [[ -f $FONTS/$name/.version ]]; then
      say "ok" "Nerd Fonts $name $(<"$FONTS/$name/.version")"
    else
      act "Nerd Fonts $name into ${FONTS%/*}" "install"
      fonts_missing+=("$name")
    fi
  done
  if (( ${#fonts_missing[@]} && ! check )); then
    bash "$SRC/install-nerd-fonts.sh" "${fonts_missing[@]}"
  fi
fi

# --- waypipe from Arch Linux ARM: --waypipe=arch --------------------------------------------------
# Only whether it is there, and from that source; updating needs the network and the repo's 10 MB
# database, so it is left to install-waypipe.sh.

if (( want_waypipe )) && [[ $waypipe_src == arch ]]; then
  if [[ -x $WAYPIPE && $(waypipe_source_kept) == arch ]]; then
    ver=$("$WAYPIPE" --version 2>/dev/null | sed -n '1s/^waypipe //p' || true)
    say "ok" "waypipe${ver:+ $ver} from Arch Linux ARM"
  else
    act "waypipe from Arch Linux ARM into ~/.local/bin, via install-waypipe.sh" "install"
    (( check )) || bash "$SRC/install-waypipe.sh"
  fi
fi

# --- Homebrew: --brew, --zsh -------------------------------------------------------------------
# The default prefix, since Homebrew's bottles are built for it; elsewhere everything builds from
# source. /home survives SteamOS updates.

BREW_PREFIX=/home/linuxbrew/.linuxbrew
BREW=$BREW_PREFIX/bin/brew

# brew_ensure FORMULA
brew_ensure() {
  if [[ -x $BREW ]] && "$BREW" list --formula "$1" >/dev/null 2>&1; then
    say "ok" "$1 from Homebrew"
    return
  fi
  act "$1 from Homebrew" "brew install"
  (( check )) && return
  HOMEBREW_NO_ENV_HINTS=1 "$BREW" install "$1"
}

if (( want_brew )); then
  if [[ -x $BREW ]]; then
    say "ok" "Homebrew $("$BREW" --version 2>/dev/null | sed -n '1s/^Homebrew //p')"
  else
    act "Homebrew into $BREW_PREFIX" "install"
    if (( ! check )); then
      # The installer needs sudo only where it can't write /home/linuxbrew, and it can't ask for a
      # password when it runs unattended. With the directory ours, it needs none.
      [[ -w ${BREW_PREFIX%/*} ]] || sudo install -d -o "$USER" -g "$(id -gn)" "${BREW_PREFIX%/*}"
      NONINTERACTIVE=1 bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  fi
  brew_ensure wl-clipboard
fi

(( want_zsh )) && brew_ensure zsh

# --- The ubuntu box: --ubuntu, --emacs, --waypipe=box ---------------------------------------------

confirm_box() {
  (( yes )) && return 0
  local free; free=$(df -h --output=avail "$HOME" | tail -1 | tr -d ' ')
  echo "Creating the $BOX box pulls $IMAGE, about 1.2 GB, into" \
    "~/.local/share/containers ($free free). Its first start then takes several minutes." >&2
  if ! (: </dev/tty) 2>/dev/null; then
    echo "setup.sh: no terminal to ask on; re-run with --yes to create the box" >&2
    return 1
  fi
  local answer
  read -r -p "Continue? [y/N] " answer </dev/tty || return 1
  [[ $answer == [yY]* ]]
}

if (( want_ubuntu )); then
  have_box=0
  if [[ $box == "$BOX" ]] || podman container exists "$BOX" 2>/dev/null; then
    say "ok" "$BOX distrobox"
    have_box=1
  elif (( check )); then
    act "$BOX distrobox from $IMAGE (about 1.2 GB)" "create"
  elif confirm_box; then
    act "$BOX distrobox from $IMAGE" "create"
    "$DISTROBOX" create --yes --name "$BOX" --image "$IMAGE"
    have_box=1
  else
    say "skip" "$BOX distrobox: not created"
  fi

  if (( want_emacs || want_waypipe_box )); then
    if [[ $box == "$BOX" ]]; then
      in_box_part
    elif (( have_box )); then
      args=()
      (( check )) && args+=(--check)
      (( want_emacs )) && args+=(--emacs)
      (( want_waypipe_box )) && args+=(--waypipe=box)
      rc=0
      "$DISTROBOX" enter "$BOX" -- env SFU_IN_BOX=1 FORCE="${FORCE:-}" \
        bash "$SRC/setup.sh" "${args[@]}" || rc=$?
      case $rc in
        0) ;;
        100) changed=1 ;;
        *) die "the part inside the $BOX box failed (exit $rc)" ;;
      esac
    else
      say "skip" "--emacs/--waypipe=box inside the $BOX box: it doesn't exist yet"
    fi
  fi
fi

# --- Tailscale ----------------------------------------------------------------------------------

# Each part is checked on its own, and --tailscale fixes only what is missing. Only the installer
# can put back the binaries or the unit (a SteamOS update can drop the unit), so either of those
# re-runs it, and it then enables, starts and trusts in one go.
TS=/home/.tailscale/bin
KEEP=/etc/atomic-update.conf.d/tailscale-firewall.conf

if [[ -n $box ]]; then
  say "skip" "tailscaled: the $box box can't see it; check from the host"
else
  ts_missing=()
  [[ -x $TS/tailscale && -x $TS/tailscaled ]] || ts_missing+=(binaries)
  [[ -f /etc/systemd/system/tailscaled.service ]] || ts_missing+=(unit)
  systemctl is-enabled --quiet tailscaled 2>/dev/null || ts_missing+=(enabled)
  systemctl is-active --quiet tailscaled 2>/dev/null || ts_missing+=(running)
  if [[ $tailscale == trust ]]; then
    [[ $(firewall-cmd --get-zone-of-interface=tailscale0 2>/dev/null) == trusted && -f $KEEP ]] \
      || ts_missing+=(trusted)
  fi
  ts_needs() { [[ " ${ts_missing[*]} " == *" $1 "* ]]; }

  if (( ${#ts_missing[@]} == 0 )); then
    say "ok" "tailscaled"
  elif [[ -z $tailscale ]]; then
    say "missing" "tailscaled: ${ts_missing[*]} (re-run with --tailscale, or see README.md#tailscale)"
  elif ts_needs binaries || ts_needs unit; then
    act "tailscaled: ${ts_missing[*]}, via install-tailscale.sh" "install"
    if (( ! check )); then
      args=()
      [[ $tailscale == trust ]] && args+=(--trust-tailnet)
      sudo bash "$SRC/install-tailscale.sh" "${args[@]}"
    fi
  else
    if ts_needs enabled; then
      act "tailscaled" "enable"
      (( check )) || sudo systemctl enable tailscaled
    fi
    if ts_needs running; then
      act "tailscaled" "start"
      (( check )) || sudo systemctl start tailscaled
    fi
    if ts_needs trusted; then
      # The same steps install-tailscale.sh --trust-tailnet takes, without reinstalling.
      act "tailscale0 in firewalld's trusted zone, kept across updates" "trust"
      if (( ! check )); then
        sudo firewall-cmd --permanent --zone=trusted --add-interface=tailscale0
        sudo firewall-cmd --reload
        sudo install -d -m 755 "${KEEP%/*}"
        echo /etc/firewalld/zones/trusted.xml | sudo tee "$KEEP" >/dev/null
      fi
    fi
  fi

  # Logging in is interactive, so it is only reported.
  if [[ -x $TS/tailscale ]] && systemctl is-active --quiet tailscaled 2>/dev/null; then
    backend=$("$TS/tailscale" status --json 2>/dev/null | jq -r .BackendState 2>/dev/null || true)
    if [[ $backend == Running ]]; then
      say "ok" "tailscale login"
    else
      say "missing" "tailscale login (${backend:-unknown}): sudo $TS/tailscale up --qr --operator=$USER --ssh"
    fi
  fi
fi

# --- Shell init ---------------------------------------------------------------------------------
# shell-init/ goes into two marked blocks of each rc file: "top" at its start, ahead of mise
# activate and of ~/.local/bin on PATH, and "end" at its end. A file goes in when its option is
# given, or when a block already has it, so a run without that option keeps it. One that the rc file
# defines outside the blocks is left out. Blocks of earlier versions, one per file, are removed.

INIT_LINK='# https://github.com/curiousjtuber/steam-frame-utils#shell-init'
# bin's pattern names this checkout's directory, so that some other bin/ on PATH doesn't match.
src_re=$(printf '%s' "${SRC##*/}" | sed 's/[][\\.*^$+?(){}|]/\\&/g')
declare -A INIT_PATTERNS=(
  [frametop]='^[[:space:]]*export FRAMETOP_XDG_CONFIG_HOME='
  [bin]="^[^#]*PATH=.*$src_re/bin"
  [brew]='^[^#]*brew shellenv'
  [waypipe]='^[[:space:]]*(function[[:space:]]+waypipe|waypipe[[:space:]]*\(\))'
  [tailscale]='^[[:space:]]*alias tailscale='
)

# init_block RC NAME WHERE [INIT WANTED]... -- the block NAME holds each shell-init/INIT.sh that is
# WANTED (1) or already in a block of RC
init_block() {
  local rc=$1 name=$2 where=$3 init wanted
  shift 3
  local inits=()
  while (( $# )); do
    init=$1 wanted=$2
    shift 2
    if [[ -f $rc ]] && block_lines "$rc" out | grep -qE -- "${INIT_PATTERNS[$init]}"; then
      say "ok" "$rc: $init, defined outside steam-frame-utils"
    elif (( wanted )) \
        || { [[ -f $rc ]] && block_lines "$rc" in | grep -qE -- "${INIT_PATTERNS[$init]}"; }; then
      inits+=("$init")
    fi
  done
  if (( ! ${#inits[@]} )); then
    remove_block "$rc" "$name"
    return
  fi
  local content; content=$(mktemp)
  {
    printf '%s\n' "$INIT_LINK"
    for init in "${inits[@]}"; do
      with_src "$SRC/shell-init/$init.sh"
    done
  } > "$content"
  ensure_block "$rc" "$name" "$content" "$where"
  command rm -f "$content"
}

# The containers share these rc files, so each file works on the host and in a distrobox alike.
# SteamOS has no zsh, so ~/.zshrc is optional; --zsh creates it so that zsh doesn't start with its
# new-user menu.
if (( want_zsh )) && [[ ! -e $HOME/.zshrc ]]; then
  act "$HOME/.zshrc" "create"
  (( check )) || : > "$HOME/.zshrc"
fi
rcs=("$HOME/.bashrc")
if [[ -f $HOME/.zshrc ]] || (( want_zsh )); then
  rcs+=("$HOME/.zshrc")
fi

want_ts_init=0
[[ -z $box && -n $tailscale ]] && want_ts_init=1
for rc in "${rcs[@]}"; do
  # frametop is a no-op outside a Frametop desktop's terminal, so it always goes in. bin comes
  # after brew, to go ahead of it in PATH; ~/.local/bin, added further down, goes ahead of both.
  init_block "$rc" top top brew "$want_brew" frametop 1 bin 1
  init_block "$rc" end end waypipe "$want_waypipe" tailscale "$want_ts_init"
  if [[ -f $rc ]]; then
    for old in $(sed -n 's/^# >>> steam-frame-utils: \(.*\) >>>$/\1/p' "$rc"); do
      [[ $old == top || $old == end ]] || remove_block "$rc" "$old"
    done
  fi
done

# --- Done ---------------------------------------------------------------------------------------

if (( ! changed )); then
  echo "everything is up to date"
elif (( check )); then
  echo "run without --check to apply"
else
  (( reboot_needed )) && echo "reboot for the environment.d change to reach Desktop Mode"
  echo "open a new shell for the shell init changes"
fi

# steam-frame-utils

Setup for the Steam Frame: arm64 SteamOS, with an immutable root and A/B updates.

Clone it on the Frame as `~/steam-frame-utils`; the paths below assume that location.

| Path | |
|---|---|
| `setup.sh` | checks and installs everything below but `apps/`, whose installers are run by hand (see [Setup](#setup)) |
| `install-tailscale.sh` | Tailscale as a system service that survives updates (see [Tailscale](#tailscale)) |
| `install-nerd-fonts.sh` | Nerd Fonts in the home directory, no root needed (see [Nerd Fonts](#nerd-fonts)) |
| `install-waypipe.sh` | waypipe for the host from Arch Linux ARM's package, no root needed (see [The waypipe function](#the-waypipe-function)) |
| `apps/` | installers for apps: Stream Frame, Moonlight, KRDC, BSManager and Full Keyboard (see [Apps](#apps)) |
| `shell-init/` | bash and zsh init for `bin/` on `PATH`, Homebrew, the `tailscale` alias, `waypipe`, and terminals in the Frametop desktop (see [Shell init](#shell-init)) |
| `bin/podman` | lets distrobox work from Desktop Mode and the Frametop desktop (see [Distrobox in Desktop Mode](#distrobox-in-desktop-mode)) |
| `bin/bsmanager` | BSManager on the Frame, in a window on a Linux PC through waypipe (see [Apps](#apps)) |
| `distrobox/distroboxrc` | makes distrobox find `bin/podman` whatever the caller's `PATH` (same section) |
| `environment.d/` | shows the mouse cursor in Desktop Mode (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |
| `docs/` | memos on the surrounding ground: [Arch-based distrobox images for arm64](docs/arch-distrobox-images.md), and [the proximity sensor](docs/proximity-sensor.md), on the `frame-prox` tool that SteamOS 0.4.4 made redundant and how its undocumented settings were found |

## Setup

```bash
~/steam-frame-utils/setup.sh --check
```

```bash
~/steam-frame-utils/setup.sh [--brew] [--zsh] [--emacs] [--waypipe[=arch|box]] [--tailscale[=trust]] [--nerd-fonts[=NAME,...]]
```

`--check` reports what would change and changes nothing. A re-run touches only what is missing or
out of date, so after pulling this repo, run it again.

With no options:

| What | How |
|---|---|
| `~/.local/bin` first in `PATH` | adds `export PATH=~/.local/bin:$PATH` to `~/.bashrc` and `~/.profile`, unless a line there already puts `~/.local/bin` on `PATH` |
| distrobox | installs into `~/.local` if `~/.local/bin/distrobox` is missing |
| `distrobox/distroboxrc` | inserts into `~/.distroboxrc`, which puts this checkout's `bin/` first for distrobox |
| `bin/` | goes on `PATH` from this checkout, through `shell-init/bin.sh` (see [Shell init](#shell-init)), so a `git pull` updates its scripts. A copy in `~/.local/bin` from an earlier version would come first, so it is backed up to `<file>.bak-<timestamp>` |
| `shell-init/frametop.sh` | sourced from the block at the top of `~/.bashrc`, and of `~/.zshrc` if that exists (see [Shell init](#shell-init)) |
| `environment.d/` | copies to `~/.config/environment.d/`; reboot afterwards |

Options add the rest, and each one also fixes only what's missing:

| Option | What |
|---|---|
| `--brew` | Homebrew in `/home/linuxbrew/.linuxbrew` if it isn't there, wl-clipboard (`wl-copy` and `wl-paste`) from it, and `shell-init/brew.sh` in the block at the top of `~/.bashrc` and `~/.zshrc` (see [Homebrew](#homebrew)). Uses sudo once, to create `/home/linuxbrew`. Refused inside a distrobox |
| `--zsh` | implies `--brew`. zsh from Homebrew, and an empty `~/.zshrc` if there is none, so zsh skips its new-user menu |
| `--arch` | creates the `arch` distrobox from `docker.io/menci/archlinuxarm:latest`, Arch Linux ARM, if it doesn't exist (see [Arch-based distrobox images for arm64](docs/arch-distrobox-images.md) for why that image, and for the pacman sandbox the box is created without). The image is about 0.7 GB and the first start takes a few minutes, so it says so and asks first; `--yes` skips the question |
| `--emacs` | implies `--arch`. emacs-wayland, the pgtk build, in the box, with `emacs` and `emacsclient` exported to `~/.local/bin`. An export left by another box, as the earlier `ubuntu` box's, is replaced; anything else already there is left alone |
| `--waypipe` | waypipe in `~/.local/bin` for the host, and `shell-init/waypipe.sh` in `~/.bashrc` and `~/.zshrc` (see [The waypipe function](#the-waypipe-function)). `--waypipe=arch` runs `install-waypipe.sh`, which downloads Arch Linux ARM's package itself, when waypipe is missing; it doesn't update it, `install-waypipe.sh` does. `--waypipe=box` implies `--arch`: a copy of the box's binary, the same package, which pacman keeps up to date. The choice is noted in `~/.local/state/steam-frame-utils/waypipe-source`, so a bare `--waypipe` reuses it; the first time, with nothing installed yet, it asks |
| `--tailscale` | fixes what's missing of the install, with sudo: `install-tailscale.sh` if the binaries or the unit are gone, otherwise just `systemctl enable`/`start`. Adds `shell-init/tailscale.sh`. `--tailscale=trust` also puts `tailscale0` in firewalld's `trusted` zone. Logging in is only reported. Without the option, what's missing is still reported |
| `--nerd-fonts` | runs `install-nerd-fonts.sh` for each font not installed yet: `JetBrainsMono` and `NerdFontsSymbolsOnly`, or a comma-separated list such as `--nerd-fonts=FiraCode,Hack`. It doesn't update installed ones; `install-nerd-fonts.sh` does that |

The rest of the setup, such as mise and tmux, is personal and not part of this.

The host and its distroboxes share the home directory, so `setup.sh` runs inside a distrobox too.
What needs the host is refused there: `--tailscale`, `--brew` and `--zsh`, and `--arch`,
`--emacs` and `--waypipe=box` in any box but `arch`. From the host, the box's part of `--emacs`
and `--waypipe=box` runs through `distrobox enter arch`.

`bin/` and `shell-init/` are used from the checkout: `bin/` goes on `PATH`, and the rc files source
`shell-init/`, so a `git pull` updates both. Other files are copied, not linked, so they keep
working if this checkout moves or goes. A file that differs is moved to `<file>.bak-<timestamp>`
first. Inserted text sits between
`# >>> steam-frame-utils: <name> >>>` and `# <<< … <<<` markers, and a re-run replaces it in place;
edit the source here, not the copy. A shell-init file isn't inserted into an rc file that already
defines the same alias or function some other way.

## Tailscale

`install-tailscale.sh` installs or updates Tailscale as a native system service, using kernel
TUN rather than userspace or proxy mode. `setup.sh --tailscale` runs it and adds the `tailscale`
alias (see [Shell init](#shell-init)). To run it by hand, copy the script to the Frame and run it
there:

```bash
scp install-tailscale.sh steamos@frame.local:
```

```bash
sudo bash ~/install-tailscale.sh [--trust-tailnet]
```

```bash
sudo /home/.tailscale/bin/tailscale up --qr --operator=steamos --ssh
```

`--qr` prints a login QR code to scan with a phone. `--operator=steamos` lets that user run
`tailscale` without sudo. Re-running the script updates to the latest stable build and keeps the
login.

### Why it installs under `/home/.tailscale`

The home partition is the only storage that persists across updates:

| Mount | Partition | Survives an update? |
|---|---|---|
| `/` | `rootfs-A`/`rootfs-B`, btrfs | No: it's read-only (`btrfs property get / ro` gives `ro=true`) and replaced from the image. `findmnt` still says `rw`. |
| `/var` | `var-A`/`var-B`, 256 MB ext4 | No: each slot has its own copy. It's also too small for the roughly 70 MB of binaries. |
| `/etc` | overlay, with its upper layer in `/var/lib/overlays/etc/upper` | Only the paths in the update keep list (below) |
| `/home` | `home`, ext4 | Yes. SteamOS keeps its own persistent data there too (`/home/.steamos/offload`) |

The directory is `/home/.tailscale`, owned by root, and not somewhere under `~`. `tailscaled`
runs as root, and any process running as your user can rename things inside `~` (which you own),
so it could swap the binary out. `/home` itself is owned by root.

The deck-tailscale script from Tailscale's team, and forks of it, install to `/opt`, which is
on the read-only root. On the Frame they fail with `Read-only file system`
(tailscale-dev/deck-tailscale#71).

### What survives an update

`/usr/lib/rauc/atomic-update-keep.conf` already keeps `/etc/systemd/system/*.service`,
`*.wants/**`, `*.service.d/**` and `/etc/atomic-update.conf.d/*.conf`. That covers the unit and
its enable symlink, so they need no drop-in of their own. `/etc/firewalld/` is **not** on the
list, which is why `--trust-tailnet` adds one.

`/etc/profile.d` isn't on the keep list either, so the `tailscale` command comes from the shell
init instead (see [Shell init](#shell-init)).

### Firewall

- **firewalld is running,** and its default `public` zone allows only `ssh` and
  `dhcpv6-client`. Without `--trust-tailnet`, only SSH is reachable over the tailnet.
  `--trust-tailnet` puts `tailscale0` in the `trusted` zone and leaves access control to the
  Tailscale ACLs.
- **`/usr/bin/iptables` is the legacy backend,** but the kernel has no `ip_tables` module. Left
  to auto-detect, tailscaled fails to install its `ts-*` rules; the health check reports
  `modprobe: FATAL: Module ip_tables not found`. The unit sets
  `TS_DEBUG_FIREWALL_MODE=nftables`, and `CONFIG_NF_TABLES=y` supports it (firewalld already uses
  nftables).

### Checking it

Run these on the Frame; none needs sudo:

```bash
systemctl is-enabled tailscaled && tailscale status
```

```bash
tailscale status --json | jq -c '{BackendState, Health}'
```

```bash
tailscale ping <peer>
```

- **`tailscale status --json`** should report `Running` and an empty `Health` list.
- **`tailscale ping`** should answer from a LAN address, not through a DERP relay.
- **After the first SteamOS update, re-run the first command.** If the unit is gone, re-running
  the script restores it, and the login in `/home/.tailscale/state` is kept.

Disable key expiry for the Frame in the admin console. Otherwise it drops off the tailnet when
the key expires, after about 180 days.

### Uninstall

The steps are in the script's header comment.

## Homebrew

`setup.sh --brew` installs Homebrew with its official installer, in the default prefix
`/home/linuxbrew/.linuxbrew`. Homebrew builds its arm64 Linux bottles for that prefix only; anywhere
else, every formula builds from source. `/home` is its own partition, so the install survives
SteamOS updates. The installer can't ask for a sudo password when it runs unattended, so
`setup.sh` creates `/home/linuxbrew` for the `steamos` user first, and the installer then needs no
sudo at all.

Homebrew supports arm64 Linux in full only on Ubuntu, so on SteamOS it is unsupported, though it
works: the Frame's glibc 2.39 is the minimum the bottles need. zsh comes from here rather than a
distrobox, which starts it in about half the time, and so does wl-clipboard, which SteamOS lacks.
emacs stays in the `arch` box, and waypipe comes from Arch Linux ARM, through the box or directly:
Homebrew's emacs is terminal-only, and it has no waypipe.

`shell-init/brew.sh` runs `brew shellenv` unless Homebrew's `bin` is on `PATH` already. It goes in
the block at the top of the rc files, so `~/.local/bin`, put on `PATH` further down, stays ahead of
Homebrew. A distrobox doesn't see `/home/linuxbrew`, so there it does nothing.

## Nerd Fonts

```bash
~/steam-frame-utils/install-nerd-fonts.sh [NAME...]
```

The root filesystem is read-only, but fonts don't need it. fontconfig also reads
`~/.local/share/fonts`, under Wayland and X11 alike, and Flatpak apps see that folder too. It's on
`/home`, so SteamOS updates keep it, and the distroboxes share it.

- **NAME** is a release archive without `.tar.xz`, from the
  [latest release](https://github.com/ryanoasis/nerd-fonts/releases/latest): `JetBrainsMono`,
  `FiraCode`, `Hack`, `Meslo`, and so on. With no NAME, it installs `JetBrainsMono` and
  `NerdFontsSymbolsOnly`.
- **Each font** goes in `~/.local/share/fonts/NerdFonts/NAME`, along with the release tag in
  `.version`. A re-run replaces only fonts older than the latest release, and checks each archive
  against the release's `SHA-256.txt`.
- **`NerdFontsSymbolsOnly`** adds only the icons, so apps left on another font show them too. Its
  fontconfig rule goes in `~/.config/fontconfig/conf.d`, and makes every font fall back to it for
  the icon code points.
- **Afterwards,** restart apps that are already running; the script lists the new families. In
  Konsole, pick the `… Nerd Font Mono` family, so each icon is one column wide.

To uninstall a font, delete its folder and run `fc-cache -f`. The script's header comment has the
steps.

## Apps

`apps/` holds one installer per app. `setup.sh` doesn't run them; each is run by hand, and a
re-run updates. The header comment of each has the details and the uninstall steps.

| Script | App | Where it goes |
|---|---|---|
| `install-stream-frame.sh [--yes]` | [Stream Frame](https://streamframe.app), for watching, recording and screenshotting the headset from another device | Flatpak `com.boxtree.StreamFrame`, system-wide, from Boxtree's repo; uses sudo |
| `install-moonlight.sh [--yes]` | [Moonlight](https://moonlight-stream.org), for streaming games from a Sunshine or GeForce Experience host | Flatpak `com.moonlight_stream.Moonlight`, system-wide, from Flathub; uses sudo |
| `install-krdc.sh [--yes]` | [KRDC](https://apps.kde.org/krdc), KDE's RDP and VNC client, for a Plasma desktop shared with KRdp | Flatpak `org.kde.krdc`, system-wide, from Flathub; uses sudo |
| `install-bsmanager.sh` | [BSManager](https://github.com/DaVarga/bs-manager), DaVarga's arm64 fork, for Beat Saber versions, mods and maps | `~/Applications/BSManager.AppImage`, with a menu entry and the BeatSaver OneClick links |
| `install-full-keyboard.sh [--version X.Y.Z \| --uninstall]` | [Full Keyboard](https://github.com/TaiKeid/steam-frame-full-keyboard), TaiKeid's full-size virtual keyboard for the dashboard and local apps | `~/.local/share/framekeyboard`, with the launcher `~/.local/bin/framekeyboard` and a menu entry |

- **Stream Frame** is what Discover installs from the website. Run it on the host, not in a
  distrobox. The first install also pulls the KDE runtime from Flathub, a few hundred MB, and
  asks first unless given `--yes`. `/var/lib/flatpak` is a bind mount into `/home/.steamos/offload`,
  so SteamOS updates keep it. It needs ffmpeg on the headset, and SteamOS already has it in
  `/usr/bin`.
- **Moonlight** comes from Flathub because Ubuntu 26.04 has no `moonlight-qt` for arm64. Like
  Stream Frame, run it on the host. The first install pulls KDE runtime 6.11, about 400 MB, and
  asks first unless given `--yes`. The sandbox can reach gamescope, so it can also be added as a
  non-Steam game for Game Mode.
- **KRDC** is for desktop work, Moonlight for games. KRdp, Plasma's Remote Desktop, streams every
  monitor as one picture and moves the pointer through KWin, so it lines up on a multi-monitor
  host, where Sunshine's absolute mouse spans the whole desktop but the stream shows one monitor.
  Run it on the host. It uses the KDE runtime 6.10 that Stream Frame already installs. On the
  PC, run `krdpserver` with `--plasma` (a systemd drop-in for `app-org.kde.krdpserver.service`):
  without it, KRdp goes through the desktop portal, whose permission prompt shows on the PC's
  screen, and KRDC gets a blank blue screen until someone answers it there.
- **BSManager** runs the fork's own `install.sh` from its latest release, passing on
  `--uninstall` and `--appimage FILE`. After that, BSManager updates itself.
- **Full Keyboard** is a separate app, not a replacement for the system keyboard: start it from
  the dashboard's app launcher, with the VR session running. It types into the dashboard and
  local apps, not into streamed VR games. The script checks the release archive against its
  `SHA256SUMS` and runs the `install.sh` inside it, which keeps the previous release for rollback
  and refuses one already installed, so a re-run with nothing newer just says so. Close the
  keyboard before updating. `--uninstall` keeps the settings in `~/.config/framekeyboard`.
- **`bin/bsmanager [--no-gpu] [HOST]`** shows the Frame's BSManager in a window on a Linux PC's
  Wayland desktop, through waypipe. In the headset, start BSManager from Steam instead. It runs in
  either of two places:
  - On the Frame, where `setup.sh` puts it on `PATH`, in a session opened from the PC with
    `waypipe --remote-bin /home/steamos/.local/bin/waypipe ssh steamos@frame.local`. From a
    distrobox it runs on the host, and it refuses without the session's `WAYLAND_DISPLAY`.
  - On the PC, copied there, where it opens that session itself. HOST defaults to `$FRAME_HOST`,
    or else `steamos@frame.local`.

  The Frame needs `setup.sh --waypipe`. BSManager allows one instance, so the script stops if it's
  already running on the Frame: a second launch would hand off to the first and exit, and no
  window would show on the PC. `--no-gpu` is for a blank or crashing window; in a session opened
  by hand, also pass `-n` to waypipe.

## Shell init

`shell-init/` holds one file per feature. `setup.sh` puts two marked blocks into `~/.bashrc`, and
into `~/.zshrc` if that exists, each a short loop that sources the chosen files from this checkout:

```sh
# >>> steam-frame-utils: top >>>
# https://github.com/curiousjtuber/steam-frame-utils#shell-init
for _sfu in brew frametop bin; do
    _sfu="$HOME/steam-frame-utils/shell-init/$_sfu.sh"
    [[ -r $_sfu ]] && source "$_sfu"
done
unset _sfu
# <<< steam-frame-utils: top <<<
```

The files are read live, so a `git pull` changes the next shell without a `setup.sh` re-run. The
path is filled in from where `setup.sh` runs, so the checkout can be anywhere; after moving it, run
`setup.sh` again, and until then the `-r` test just skips the files, rather than failing every
shell start. `setup.sh` refuses a path with `"`, `$`, `` ` ``, `\`, `|` or `&` in it.

| Block | Files |
|---|---|
| `top`, at the start of the file | `brew.sh` with `--brew` (see [Homebrew](#homebrew)), and `frametop.sh` and `bin.sh` always |
| `end`, at the end of the file | `waypipe.sh` with `--waypipe`, and `tailscale.sh` with `--tailscale` |

`bin.sh` puts this checkout's `bin/` on `PATH`, ahead of Homebrew and behind `~/.local/bin`, which
the rc file puts first further down. It finds the checkout from its own path (`BASH_SOURCE` in
bash, `%x` in zsh), so nothing but the blocks names it. distrobox puts `bin/` first too, through
[`~/.distroboxrc`](#distroboxrc).

A file stays in once it's there, so a run without its option keeps it. An rc file with blocks of
earlier versions, one per file or with the files' text inline, gets them replaced by these two.

The bare host and its distroboxes share one home directory, so the same blocks run in all of them.
The containers read the same `~/.bashrc`, so any host-only line added there outside these blocks
runs inside every distrobox too. Put such checks in a `shell-init/` file instead.

### The tailscale alias

`tailscale.sh` checks where it is running, using `$CONTAINER_ID` or `/run/.containerenv`:

| Where | `tailscale` alias |
|---|---|
| Bare host (bash) | `/home/.tailscale/bin/tailscale` |
| A distrobox (bash or zsh) | `distrobox-host-exec /home/.tailscale/bin/tailscale` |

A distrobox sees neither `/home/.tailscale` nor the daemon's socket in the host's `/run`, so the
CLI has to run on the host.

### The waypipe function

SteamOS has no waypipe, and Valve's package repos for the Frame don't carry it, so `--waypipe` puts
one in `~/.local/bin` from one of two sources:

| Source | What |
|---|---|
| `--waypipe=arch` | [Arch Linux ARM](https://archlinuxarm.org)'s aarch64 package, downloaded by `install-waypipe.sh` itself: a 0.6 MB download and no distrobox needed. `setup.sh` runs it only when waypipe is missing; re-run `install-waypipe.sh` to update |
| `--waypipe=box` | a copy of the `arch` box's `/usr/bin/waypipe`, the same package, which pacman keeps up to date (`distrobox upgrade arch`); a re-run of `setup.sh --waypipe` refreshes the copy. Needs the box |

It is one binary either way, and the box route only spares the download when the box is there
anyway. It needs only libc, libgcc, lz4 and zstd, which SteamOS has, so it runs on the host
without entering the box. `install-waypipe.sh` reads the version and checksum from the repo's
package database over https, checks the download against it, and runs the new binary once before
installing it, so that a build for a newer glibc than the Frame's leaves the installed one alone;
the old binary is backed up to `waypipe.bak-<timestamp>`. The package signature isn't checked.

The choice is noted in `~/.local/state/steam-frame-utils/waypipe-source`, so a bare `--waypipe` on
a re-run keeps it, and neither source replaces the other's binary unasked. To switch, pass the
other `=arch` or `=box` once. A waypipe installed by an earlier version of `setup.sh`, with no note
yet, counts as the box's. With nothing installed and no note, a bare `--waypipe` asks, or stops
when there's no terminal to ask on.

`shell-init/waypipe.sh` wraps `waypipe` in a function. Game Mode is an X11 session: gamescope names
its Wayland socket only in `GAMESCOPE_WAYLAND_DISPLAY` (`gamescope-0`), so a `waypipe` client
started from a terminal there fails with `WAYLAND_DISPLAY is not set`. When `WAYLAND_DISPLAY` is
empty, the function fills it in from `GAMESCOPE_WAYLAND_DISPLAY` for that one command. With that,
`waypipe ssh <host> <app>` from a Game Mode Konsole shows a remote app on the Frame. The shell
itself doesn't export it, because Qt and GTK apps started from that terminal would then leave
Xwayland for native Wayland.

### Frametop terminals

[Frametop](https://github.com/DeeJanuz/frametop)'s desktop gives Plasma config and state dirs of
its own (`XDG_CONFIG_HOME=~/.config/frametop`, `XDG_STATE_HOME=~/.local/state/frametop`), so its
panels and layout never touch the stock desktop's. A terminal in that desktop inherits them. That
suits KDE tools run from it, which then change the Frametop desktop's settings, but command-line
tools miss their config: mise takes `~/.config/mise/config.toml` for an untrusted project file and
asks for `mise trust`.

In such a shell, `frametop.sh` points mise at its usual dirs with `MISE_CONFIG_DIR` and
`MISE_STATE_DIR`, and leaves the XDG ones alone. They're exported ahead of `mise activate`, hence
the top of the rc file, since mise's prompt hook reads its config again before every prompt; after
it, mise still works but warns once in every new shell. For other tools, `frametop-xdg off`
switches the rest of the shell session to the usual XDG dirs, `frametop-xdg on` brings the
desktop's back, and `frametop-xdg` shows which are in use. Outside a Frametop desktop the file
does nothing. Inside a distrobox it isn't needed: `distrobox enter` resets the XDG dirs to the
usual ones itself.

## Distrobox in Desktop Mode

Desktop Mode on the Frame is Plasma nested inside gamescope, with its own session environment
(Frametop's desktop has the same, with `/run/user/1000/frametop`):

- `XDG_RUNTIME_DIR=/run/user/1000/nested_plasma` rather than `/run/user/1000`
- `DBUS_SESSION_BUS_ADDRESS` is a private bus under `/tmp` with no `systemd --user` behind it

Rootless podman breaks on both. crun asks `org.freedesktop.systemd1` on the session bus for the
container's cgroup, so `distrobox enter` fails with
`crun: sd-bus call: Process org.freedesktop.systemd1 exited with status 1`. And podman keeps its
runtime state under `$XDG_RUNTIME_DIR`, so a container started from SSH or Game Mode looks
unset-up from Desktop Mode: `unable to find user steamos: no matching entries in passwd file`.

`bin/podman` switches podman alone to the real runtime dir and user bus when it runs under a
runtime dir nested in `/run/user/<uid>`, such as `nested_plasma` or Frametop's `frametop`, and
passes through untouched everywhere else. Without it, from Frametop's desktop `distrobox enter`
fails with `crun: error opening file /run/user/1000/frametop/crun/<id>/status`. distrobox still
forwards the Desktop Mode environment into the container, so GUI apps there reach the nested
Plasma's `wayland-0`, X display and session bus. It is found from this checkout, whose `bin/`
comes before `/usr/bin` in `PATH`. Inside a distrobox, which has the same `PATH` but no podman of
its own, it hands over to the host's podman through `distrobox-host-exec`, so `podman ps` works
there too.

### `~/.distroboxrc`

The checkout's `bin/` is on `PATH` once an rc file has run, but not for a distrobox export
started without one, such as `~/.local/bin/emacs` from a launcher. The export runs
`distrobox-enter` by its full path, which then finds `/usr/bin/podman` and fails with the crun
error above. distrobox sources `~/.distroboxrc` before it looks for podman, so `setup.sh` puts a
block there (`distrobox/distroboxrc`) that moves `bin/` to the front of `PATH` for distrobox alone.
An earlier version copied `bin/podman` to `~/.local/bin` instead, and `setup.sh` backs up that
copy out of the way.

## Mouse cursor in Desktop Mode

In Desktop Mode the mouse moves but its cursor isn't drawn. KWin puts the cursor on a hardware
plane, which the headset's view doesn't show. `KWIN_FORCE_SW_CURSOR=1` makes KWin draw it into the
frame itself. The fix comes from Cas and Chary XR's
[Steam Frame: 10 Things To Do FIRST](https://www.youtube.com/watch?v=jtW2mQd5qYI), credited
there to ThrillSeeker.

systemd reads `~/.config/environment.d` at login. `setup.sh` copies the file there; reboot
afterwards. `env | grep KWIN` in a Desktop Mode Konsole confirms it. To undo it, delete
`~/.config/environment.d/90-kwin-software-cursor.conf` and reboot.

# steam-frame-utils

Setup for the Steam Frame: arm64 SteamOS, with an immutable root and A/B updates.

Clone it on the Frame as `~/steam-frame-utils`; the paths below assume that location.

| Path | |
|---|---|
| `setup.sh` | checks and installs everything below but `apps/`, whose installers are run by hand (see [Setup](#setup)) |
| `install-tailscale.sh` | Tailscale as a system service that survives updates (see [Tailscale](#tailscale)) |
| `install-nerd-fonts.sh` | Nerd Fonts in the home directory, no root needed (see [Nerd Fonts](#nerd-fonts)) |
| `install-waypipe.sh` | waypipe for the host: Arch Linux ARM's package, relocated under `~/.local` by `pacman-home`, no root needed (see [The waypipe function](#the-waypipe-function)) |
| `apps/` | installers for apps: Stream Frame, Moonlight, KRDC, Deskflow, BSManager, Full Keyboard and KRdp's server (see [Apps](#apps)) |
| `shell-init/` | bash and zsh init for `bin/` on `PATH`, Homebrew, mise, the `tailscale` alias, `waypipe`, and terminals in the Frametop desktop (see [Shell init](#shell-init)) |
| `bin/podman` | lets distrobox work from Desktop Mode and the Frametop desktop (see [Distrobox in Desktop Mode](#distrobox-in-desktop-mode)) |
| `bin/bsmanager` | BSManager on the Frame, in a window on a Linux PC through waypipe (see [Apps](#apps)) |
| `bin/wifi-known [--all]` | the Wi-Fi networks NetworkManager has saved that are in range, strongest first; Desktop Mode has no Plasma network applet, so this and `nmtui` stand in for it |
| `distrobox/distroboxrc` | makes distrobox find `bin/podman` whatever the caller's `PATH` (same section) |
| `environment.d/` | shows the mouse cursor in Desktop Mode (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |
| `pkgbuilds/` | PKGBUILDs for the Frame host itself, built with makepkg on the Frame for a `~/.local` prefix: `pkgbuilds/emacs/` is Emacs with PGTK, `pkgbuilds/pacman/` pacman 7 with a current libalpm, and `pkgbuilds/homeify` rewrites a stock Arch PKGBUILD into one (see [Packages for the host](#packages-for-the-host)) |
| `bin/pacman-home` | pacman for packages under `~/.local`, with its database there and no root: the ones built from `pkgbuilds/`, and stock binary packages it relocates (same section) |
| `bin/makepkg-home` | builds one of `pkgbuilds/`, installs it with `pacman-home`, and offers to delete the build's leftovers (same section) |
| `docs/` | memos on the surrounding ground: [Arch-based distrobox images for arm64](docs/arch-distrobox-images.md); [the proximity sensor](docs/proximity-sensor.md), on the `frame-prox` tool that SteamOS 0.4.4 made redundant and how its undocumented settings were found; [packages under `~/.local`](docs/home-packages.md), what each one took to get there; and [paru](docs/paru.md), tried on the home database and dropped |

## Setup

```bash
~/steam-frame-utils/setup.sh --check
```

```bash
~/steam-frame-utils/setup.sh [--brew] [--zsh] [--arch] [--emacs[=host|box]] [--waypipe[=host|box]] [--mise] [--packages[=NAME,...]] [--tailscale[=trust]] [--nerd-fonts[=NAME,...]]
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
| `--emacs` | emacs from one of two sources (see [emacs and waypipe: host or box](#emacs-and-waypipe-host-or-box)). `=host`: `pkgbuilds/emacs/` built here and installed under `~/.local` by `pacman-home`, the same as `--packages=emacs-wayland`. `=box`: implies `--arch`; emacs-wayland, the pgtk build, in the box, with `emacs` and `emacsclient` exported to `~/.local/bin` (an export left by another box is replaced; anything else there is left alone). Bare, it keeps the route in place, host when there is none. Switching asks before replacing what is there; `--yes` answers |
| `--waypipe` | waypipe for the host from one of two sources (same section), and `shell-init/waypipe.sh` in `~/.bashrc` and `~/.zshrc` (see [The waypipe function](#the-waypipe-function)). `=host`, or `=arch`, its old name: Arch Linux ARM's package relocated under `~/.local` by `install-waypipe.sh` through `pacman-home`; it doesn't update waypipe, `install-waypipe.sh` does. `=box`: implies `--arch`; a copy of the box's `/usr/bin/waypipe`, the same package, which pacman in the box keeps current (`distrobox upgrade arch`) and a re-run refreshes. Bare and switching as for `--emacs` |
| `--mise` | [mise](https://mise.jdx.dev) in `~/.local/bin` if it isn't there, `shell-init/mise.sh` in the `end` block of `~/.bashrc` and `~/.zshrc` unless the file activates mise already, and rust through it, `mise use -g rust`, for a Rust package in `pkgbuilds/` (see [mise](#mise)). It doesn't update the tools; `mise upgrade` does |
| `--packages` | the packages in `pkgbuilds/`, built with makepkg and installed with `pacman-home`: each one `pacman-home` doesn't have at its PKGBUILD's version, in dependency order (see [Packages for the host](#packages-for-the-host)); `--packages=NAME,...` for some of them. A Rust package needs `--mise` for cargo |
| `--tailscale` | fixes what's missing of the install, with sudo: `install-tailscale.sh` if the binaries or the unit are gone, otherwise just `systemctl enable`/`start`. Adds `shell-init/tailscale.sh`. `--tailscale=trust` also puts `tailscale0` in firewalld's `trusted` zone. Logging in is only reported. Without the option, what's missing is still reported |
| `--nerd-fonts` | runs `install-nerd-fonts.sh` for each font not installed yet: `JetBrainsMono` and `NerdFontsSymbolsOnly`, or a comma-separated list such as `--nerd-fonts=FiraCode,Hack`. It doesn't update installed ones; `install-nerd-fonts.sh` does that |

The rest of the setup, such as mise and tmux, is personal and not part of this.

The host and its distroboxes share the home directory, so `setup.sh` runs inside a distrobox too.
What needs the host is refused there: `--tailscale`, `--brew`, `--zsh`, `--packages` and
`--emacs=host`, and `--arch`, `--emacs=box` and `--waypipe=box` in any box but `arch`. From the
host, the box's part of `--emacs=box` and `--waypipe=box` runs through `distrobox enter arch`.

### emacs and waypipe: host or box

Both come in two forms, and both forms put the same names in `~/.local/bin`, so one is in place
at a time. The **host** route, the default, is `pacman-home`'s: emacs built from
`pkgbuilds/emacs/` on the Frame itself, waypipe relocated from Arch Linux ARM's package (see
[Packages for the host](#packages-for-the-host)). It needs no container to start, sees the
Frame's own `/usr`, D-Bus and processes, and is updated by a rebuild (`--packages`) or by
`install-waypipe.sh`; what it cannot do is run inside a distrobox, where the host's libraries
aren't ([docs/home-packages.md](docs/home-packages.md)). The **box** route is the `arch`
distrobox's: emacs-wayland installed there with `emacs` and `emacsclient` exported, waypipe
copied out. Its emacs starts through `distrobox enter` and sees the box's `/usr`, but works from
the host and from every box alike, and pacman in the box keeps both current.

`setup.sh` reads which route is in place from the files themselves: `pacman-home` owns the host
route's, the box's emacs is a distrobox export, its waypipe a plain copy nothing owns. A bare
`--emacs` or `--waypipe` keeps what it finds and takes host when there is nothing; `=host` or
`=box` against the other route asks before replacing it (`pacman-home -R`, or removing the exports
or backing the copy up), `--yes` answers, and with no terminal the installed route stays.
`--packages` skips emacs-wayland while the box's export is in place; `--emacs=host` is the switch.

`bin/` and `shell-init/` are used from the checkout: `bin/` goes on `PATH`, and the rc files source
`shell-init/`, so a `git pull` updates both. Other files are copied, not linked, so they keep
working if this checkout moves or goes. A file that differs is moved to `<file>.bak-<timestamp>`
first. Inserted text sits between
`# >>> steam-frame-utils: <name> >>>` and `# <<< … <<<` markers, and a re-run replaces it in place;
edit the source here, not the copy. A shell-init file isn't inserted into an rc file that already
defines the same alias or function some other way.


## A fresh Frame

The whole of this on a new Frame, from a clone at `~/steam-frame-utils`:

```bash
~/steam-frame-utils/setup.sh --brew --zsh --waypipe --mise --packages --tailscale=trust --nerd-fonts
```

That is one run: `~/.local/bin` on `PATH`, distrobox, the cursor fix and the rc blocks; Homebrew
with zsh and wl-clipboard; waypipe relocated from Arch Linux ARM; mise with rust; the packages in
`pkgbuilds/`, pacman 7 and emacs, built here and installed under `~/.local` (`--emacs=box
--waypipe=box` in place of `--packages`'s emacs and `--waypipe` take the distrobox route instead,
see [emacs and waypipe: host or box](#emacs-and-waypipe-host-or-box)); Tailscale as a system service, which asks for sudo and then for a login in a
browser; and the fonts. The builds take about six minutes in all. The apps under `apps/` are
separate installers, run by hand; `--arch` creates the arch distrobox, which only the box route
needs.
Not in this repo: Steam's own settings, the emacs configuration, mise tools beyond rust, and
anything written into `~/.bashrc` by hand.

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
emacs is built for the host from `pkgbuilds/emacs/` or exported from the arch box, and waypipe is
Arch Linux ARM's package, relocated or copied from that box: Homebrew's emacs is terminal-only,
and it has no waypipe.

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
| `install-deskflow.sh [--yes]` | [Deskflow](https://deskflow.org), keyboard and mouse sharing, so a PC's mouse and keyboard reach the Frametop desktop | Flatpak `org.deskflow.deskflow`, system-wide, from Flathub; uses sudo |
| `install-bsmanager.sh` | [BSManager](https://github.com/DaVarga/bs-manager), DaVarga's arm64 fork, for Beat Saber versions, mods and maps | `~/Applications/BSManager.AppImage`, with a menu entry and the BeatSaver OneClick links |
| `install-full-keyboard.sh [--version X.Y.Z \| --uninstall]` | [Full Keyboard](https://github.com/TaiKeid/steam-frame-full-keyboard), TaiKeid's full-size virtual keyboard for the dashboard and local apps | `~/.local/share/framekeyboard`, with the launcher `~/.local/bin/framekeyboard` and a menu entry |
| `install-krdp.sh [--uninstall]` | [KRdp](https://invent.kde.org/plasma/krdp)'s server, krdpserver, for serving a Plasma desktop on the Frame over RDP to KRDC, Remmina or Windows Remote Desktop | Flatpak `io.github.curiousjtuber.Krdp`, built here on KDE's runtime, in the user installation; no root. Run with `bin/krdpd` |

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
- **Deskflow** makes the Frame a client of the PC's mouse and keyboard, with no streaming: the
  pointer crosses an edge of the PC's screen into the Frametop desktop. Run it on the host. It
  uses the KDE runtime 6.11 that Moonlight already installs. On Wayland the client injects input
  through the RemoteDesktop portal, the route KRdp takes into the nested KWin, so it works where
  krdpd does. The first start asks once in the headset to allow remote control, and Deskflow
  keeps the portal's restore token, so later starts don't ask. The PC side, the server, needs
  the InputCapture portal; Plasma 6.7 offers it.
- **BSManager** runs the fork's own `install.sh` from its latest release, passing on
  `--uninstall` and `--appimage FILE`. After that, BSManager updates itself.
- **Full Keyboard** is a separate app, not a replacement for the system keyboard: start it from
  the dashboard's app launcher, with the VR session running. It types into the dashboard and
  local apps, not into streamed VR games. The script checks the release archive against its
  `SHA256SUMS` and runs the `install.sh` inside it, which keeps the previous release for rollback
  and refuses one already installed, so a re-run with nothing newer just says so. Close the
  keyboard before updating. `--uninstall` keeps the settings in `~/.config/framekeyboard`.
- **KRdp's server** is the other direction: the Frame as the RDP host, for seeing and using a
  Plasma desktop that runs on it (Frametop's, or SteamOS's stock Desktop) from a PC. SteamOS has
  no krdp and Flathub only has the client, so `install-krdp.sh` builds it as a flatpak on KDE's
  runtime, with its own FreeRDP and kpipewire, pinned and patched as the manifest in `apps/krdp/`
  explains (FreeRDP 3.32 breaks krdp's login; kpipewire crashes on the 256 px cursor gamescope
  sets; krdp 6.7.5 rejects FreeRDP 3.32 clients after NLA). The first run installs the KDE 6.11
  SDK and flatpak-builder (about 1 GB to download) and builds for half an hour; later runs
  rebuild only what changed. KWin lets the sandboxed server capture through the app's desktop
  file, so neither desktop needs KWin's permission checks turned off. Nothing starts it by
  itself.
- **`bin/krdpd start [--desktop frametop|stock|DIR] [--port N] [--user NAME] [--address ADDR]`**,
  `stop`, `status`, `log`, `password [NEW | --generate]` runs that server by hand. It serves
  Frametop's desktop when that runs (the stock Desktop only with `--force`: on SteamOS 0.4.5 its
  KWin, 6.2.5 on the X11 backend inside gamescope, crashes in its screencast plugin as soon as a
  client connects, which leaves a bare KWin until you log out of it; Frametop's KWin, on the
  Wayland backend, streams fine), on port 3391 by default: 3389
  is SteamOS's own xrdp, which logs into a separate X11 session, and 3390 is Frametop Remote
  Access's krdp when that is on, so `krdpd` runs beside either. The login is the Frame's user with
  the password in `~/.config/krdpd/password`, made at the first start; the self-signed certificate
  there is what clients accept once. The Frame's firewall already allows every port above 1024 on
  the LAN (see [Firewall](#firewall)), and RDP brings its own TLS and login (NLA); `--address`
  with the tailnet address keeps it off the LAN. Over RDP, Frametop's screens you aren't looking
  at draw slowly, since only Frametop Remote Access asks ft-screens for full rate.
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
| `end`, at the end of the file | `waypipe.sh` with `--waypipe`, `tailscale.sh` with `--tailscale`, and `mise.sh` with `--mise` (see [mise](#mise)) |

`bin.sh` puts this checkout's `bin/` on `PATH`, ahead of Homebrew and behind `~/.local/bin`, which
the rc file puts first further down. It finds the checkout from its own path (`BASH_SOURCE` in
bash, `%x` in zsh), so nothing but the blocks names it. distrobox puts `bin/` first too, through
[`~/.distroboxrc`](#distroboxrc).

A file stays in once it's there, so a run without its option keeps it. An rc file with blocks of
earlier versions, one per file or with the files' text inline, gets them replaced by these two.

The bare host and its distroboxes share one home directory, so the same blocks run in all of them.
The containers read the same `~/.bashrc`, so any host-only line added there outside these blocks
runs inside every distrobox too. Put such checks in a `shell-init/` file instead.

### mise

`shell-init/mise.sh` runs `mise activate` for the running shell, bash or zsh, so the tools mise
manages are on `PATH` in every shell: rust, for a Rust package in `pkgbuilds/`, and whatever
else `mise use -g` added. It skips itself when `~/.local/bin/mise` is missing, or when mise is
active already (`MISE_SHELL` is set), and `setup.sh` leaves an rc file alone that activates mise
on a line of its own. `setup.sh --mise` installs mise with its own installer, one binary in
`~/.local/bin`, and `mise use -g rust` when cargo doesn't resolve; the version is mise's business
(`latest`), and `mise upgrade` keeps it current. The tools live under `~/.local/share/mise`, so
SteamOS updates keep them.

### The tailscale alias

`tailscale.sh` checks where it is running, using `$CONTAINER_ID` or `/run/.containerenv`:

| Where | `tailscale` alias |
|---|---|
| Bare host (bash) | `/home/.tailscale/bin/tailscale` |
| A distrobox (bash or zsh) | `distrobox-host-exec /home/.tailscale/bin/tailscale` |

A distrobox sees neither `/home/.tailscale` nor the daemon's socket in the host's `/run`, so the
CLI has to run on the host.

### The waypipe function

SteamOS has no waypipe, and Valve's package repos for the Frame don't carry it, so `--waypipe`
installs [Arch Linux ARM](https://archlinuxarm.org)'s aarch64 package under `~/.local` through
`install-waypipe.sh`, when `pacman-home` doesn't have it yet; re-run `install-waypipe.sh` to
update. The package needs only libc, libgcc, lz4 and zstd, which SteamOS has, and no file outside
its binary and man page, so it runs on the host as it is (see [Packages for the
host](#packages-for-the-host)). `install-waypipe.sh` runs `pacman-home relocate waypipe`: pacman syncs
Arch Linux ARM's package databases from one mirror, downloads the package when the installed
version differs, checks it against the database's checksum, and the package's `/usr` tree is
moved under `~/.local` and installed into `pacman-home`'s database, so `pacman-home -Q waypipe`
knows it and `pacman-home -R waypipe` removes it. A library the host lacks, a newer glibc among
them, is reported before the install. A waypipe from before `pacman-home`, a bare binary in
`~/.local/bin`, is backed up to `waypipe.bak-<timestamp>` first. The package signature isn't
checked. `--waypipe=box` takes the other source: a copy of the `arch` box's `/usr/bin/waypipe`, the
same package, which pacman in the box keeps current and a re-run of `setup.sh --waypipe` refreshes.
`pacman-home -Qo ~/.local/bin/waypipe` says which is in place, and switching asks (see [emacs and
waypipe: host or box](#emacs-and-waypipe-host-or-box)).

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
started without one, such as one started from a launcher. The export runs
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

## Packages for the host

The Frame's image carries makepkg, gcc, meson, cmake and the headers of its libraries, so a
package can be built on the host itself, against the exact libraries it will run with, with no
distrobox and no cross toolchain. `pkgbuilds/` holds PKGBUILDs configured with
`--prefix=$HOME/.local`, so the result finds its data under `~/.local` instead of the read-only
`/usr`. `pkgbuilds/emacs/` is Emacs with PGTK, a host build that sees the Frame's own `/usr`,
D-Bus and processes, which the distrobox one does not; `setup.sh --emacs` (or `--packages`)
builds and installs it, and `--emacs=box` is the distrobox alternative. The header of each
PKGBUILD says what it leaves out and why.

```bash
cd ~/steam-frame-utils/pkgbuilds/emacs && makepkg -f
```

```bash
pacman-home -U emacs-wayland-*.pkg.tar.zst
```

`makepkg-home emacs` is those two commands, from any directory, followed by an offer to delete
what the build left: `src/`, `pkg/`, the package and the downloaded sources, about half a gigabyte
for emacs, listed with their size before the question (`--clean` deletes unasked, `--keep` asks
nothing; homeify's `PKGBUILD.upstream` is kept either way). Keep them while a PKGBUILD is being
adjusted, since `makepkg -R` repackages from them in seconds. `setup.sh --packages` builds every
directory under `pkgbuilds/` that `pacman-home` doesn't have at the PKGBUILD's version, in
dependency order; a re-run builds nothing, and after a SteamOS update it rebuilds what you bump.

Any package whose build takes a prefix can be set up the same way. `pkgbuilds/homeify NAME`
fetches Arch's PKGBUILD for NAME, or the AUR's when Arch has none, rewrites it for the prefix (the
configure, cmake, meson and make prefix flags, `/usr` under `$pkgdir`, `aarch64` in `arch`, the
rpath and pkg-config path for `~/.local/lib`, and for a Rust package the rpath in `RUSTFLAGS`
too), unlists the `makedepends` that mise provides, such as cargo, since makepkg checks them
against the host's packages, prints the diff, and says which `makedepends` the host lacks.
Review it, then `makepkg -f` and `pacman-home -U`; paru's PKGBUILD was homeify's output with no
hand edit, while it was here ([docs/paru.md](docs/paru.md)). The rewrite is the mechanical part: a build system that hardcodes `/usr` shows up
afterwards as a file outside `~/.local`, which `pacman-home check PKG` lists and `pacman-home -U`
refuses, and is fixed in the PKGBUILD by hand, as `pkgbuilds/pacman/` and `pkgbuilds/emacs/`
were, for features the host lacks and a layout that keeps out of the host's way.

A program that needs no file outside its own tree, such as waypipe, needn't be built at all.
`pacman-home relocate NAME` fetches Arch Linux ARM's binary package through pacman's own
repository machinery, against one mirror (`ALARM_MIRROR` overrides it) with signatures off,
moves its `/usr` tree under `~/.local`, points its absolute symlinks there, drops its install
scriptlet, and installs the result; `relocate FILE` does the same to a package you have. It
refuses a package with files under `/etc` or `/var`, or under the parts of `/usr` that only work
from there (systemd and udev directories, polkit, system D-Bus services), and one whose libraries
the host cannot supply, a glibc or Qt newer than the host's included, since the loader names the
symbol version it lacks; `--allow-missing-libs` installs anyway. What it cannot see is a program that looks for its data under `/usr` at
run time; that one needs a build.

### Which way in

For a new program, in this order:

1. **`pacman-home relocate NAME`, and run the program.** It is the whole job when the program
   needs nothing outside its own tree. Relocate refuses a package with files outside `/usr` or in
   the parts of `/usr` that only work from there, drops an install scriptlet, and refuses one whose
   libraries the host lacks; what it cannot see is a program that looks for its data under
   `/usr` at run time, which installs cleanly and then fails or falls back to defaults. So the
   test is both: relocate accepts it, and the program works. waypipe passed; anything with data
   files, plugins, schemas or Python modules is likely to fail the second part.
2. **`pkgbuilds/homeify NAME`, then `makepkg -f` and `pacman-home -U`.** Often the whole job
   too: jq and paru (while it was here) built from homeify's output as it came.
3. **Edit the PKGBUILD where two signals say so.** homeify's closing list of `makedepends` the
   host lacks is where emacs's libgccjit and tree-sitter showed up, and became features turned
   off. `pacman-home -U` refusing a file outside `~/.local` after the build is where pacman's
   bash completions showed up, and became a move in `package()`. Beyond those, a layout may
   need deciding, as pacman's did to keep off `PATH`, and a quirk may show only when the
   installed program runs, as emacs's launcher did. Record each decision in the PKGBUILD's
   header; it is what the next SteamOS update will make you re-read.

[docs/home-packages.md](docs/home-packages.md) records which way each package so far went in,
and what it took.

`bin/pacman-home` is pacman with a configuration written to `~/.local/etc/pacman.conf` that
keeps the database, cache and log under `~/.local`; `relocate` uses a second one beside it that
adds Arch Linux ARM's repositories, which the plain one lacks so that `-U` never pulls a `/usr`
package from them to satisfy a dependency. pacman refuses to install or remove unless it runs as
root, whatever paths it is given, so `pacman-home` runs those operations under fakeroot, the same
arrangement makepkg uses to package: pacman is told it is root, writes the files as you, and the
ownership it sets is faked, so the files are yours. Its database knows only what it installed, so
a package's dependencies are checked against the host's database and passed as
`--assume-installed`; a dependency the host lacks is an error. `pacman-home -Q`, `-Ql`, `-Qo` and
`-R` work as usual within that database.

`pacman-home outdated` compares every installed package, by version, with Arch Linux ARM's
repositories, with the AUR for one they lack, and with its PKGBUILD in `pkgbuilds/`, so a
bump upstream shows up without a build. The release number after the dash is this repo's own and
isn't compared; a packaging that tracks git, as Arch's pacman does, is marked as a snapshot.

The pacman it runs is the host's until `pkgbuilds/pacman/` is installed. That is pacman 7 built
for the prefix, with its programs under `~/.local/lib/pacman/bin` so that `pacman` on `PATH` keeps
meaning the host's, and with `~/.local/etc/pacman.conf` and `~/.local/var/lib/pacman` as its
compiled-in defaults, so run by its path it reads the home database with no `--config`. Its
libalpm is current, libalpm.so.16 where the host's pacman 6.1 carries .so.14, for anything built
against libalpm. It also skips the ldconfig run that the host's pacman attempts after every
transaction and that fails on the read-only root. `pacman-home` switches to it as soon as it is
installed and still looks host packages up with the host's.

After a SteamOS update, `ldd ~/.local/bin/emacs | grep "not found"` says whether a host library
moved from under a build; the fix is a rebuild and `pacman-home -U` again.

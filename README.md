# steam-frame-utils

Setup for the Steam Frame: arm64 SteamOS, with an immutable root and A/B updates.

Clone it on the Frame as `~/steam-frame-utils`; the paths below assume that location.

| Path | |
|---|---|
| `setup.sh` | checks and installs everything below but `apps/`, whose installers are run by hand (see [Setup](#setup)) |
| `install-tailscale.sh` | Tailscale as a system service that survives updates (see [Tailscale](#tailscale)) |
| `install-nerd-fonts.sh` | Nerd Fonts in the home directory, no root needed (see [Nerd Fonts](#nerd-fonts)) |
| `install-waypipe.sh` | waypipe for the host: Arch Linux ARM's package, relocated under `~/.local` by `pacman-home`, no root needed (see [The waypipe function](#the-waypipe-function)) |
| `apps/` | installers for apps: Frametop, Stream Frame, Moonlight, KRDC, Deskflow, BSManager, Full Keyboard and KRdp's server (see [Apps](#apps)) |
| `shell-init/` | bash and zsh init for `bin/` on `PATH`, Homebrew, mise, the `tailscale` alias, `waypipe`, and terminals in the Frametop desktop (see [Shell init](#shell-init)) |
| `bin/podman` | lets distrobox work from Desktop Mode and the Frametop desktop (see [Distrobox in Desktop Mode](#distrobox-in-desktop-mode)) |
| `bin/bsmanager` | BSManager on the Frame, in a window on a Linux PC through waypipe (see [Apps](#apps)) |
| `bin/cursor-size [SIZE] [--theme NAME] [--desktop frametop\|stock]` | shows or sets the mouse cursor's size in Desktop Mode or the Frametop desktop, and applies it to the running desktop (see [Cursor size](#cursor-size)) |
| `bin/sw-cursor [on\|off\|default]` | Desktop Mode's software cursor for the next sessions, or what is set now and what the running desktop got; `setup.sh` keeps a choice made here (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |
| `autostart/` | runs `cursor-size --apply` as each desktop starts, so the size set survives a restart; `setup.sh` installs it wherever it installs the software cursor, with which the desktops take gamescope's 256 px, and removes it otherwise (same section) |
| `bin/wifi-known [--all]` | the Wi-Fi networks NetworkManager has saved that are in range, strongest first; Desktop Mode has no Plasma network applet, so this and `nmtui` stand in for it |
| `bin/frame-versions` | the versions of SteamOS, SteamVR and the Steam client, as Valve's patch notes number them, with each one's build and update channel; SteamVR comes with the OS image and the client updates itself, so the client is read from `~/.local/share/Steam`, not from its package |
| `bin/vr-controllers [off [left\|right]]` | lists the VR controllers SteamVR knows, with battery (for the Frame's AA controllers also an estimated cell voltage and NiMH charge), or turns them off from a shell as the dashboard's power menu does; this goes through a private SteamVR interface, so the script says how its slot was found and refuses if SteamVR renames the interface |
| `bin/steam-controller [off [NAME]]` | lists the Steam Controllers paired over Bluetooth that are on, with battery, or turns them off, with Valve's own HID power-off command sent to the hidraw node since the kernel's hid-steam doesn't take this controller yet |
| `bin/beat-saber-recent` | the songs Beat Saber started in its last two launches, in order, from the Unity logs in its Proton prefix; Unity keeps only two, so that is the reach, and `PlayerData.dat` has play counts but no dates |
| `distrobox/distroboxrc` | makes distrobox find `bin/podman` whatever the caller's `PATH` (same section) |
| `environment.d/` | shows the mouse cursor in Desktop Mode on SteamOS below 0.5.6; `setup.sh` installs it there and removes it from 0.5.6 on, where the stock desktop draws it itself and Frametop's session sets the variable for its own (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |
| `pkgbuilds/frame/` | PKGBUILDs for the Frame host itself, built with makepkg on the Frame for a `~/.local` prefix: `pkgbuilds/frame/emacs/` is Emacs with PGTK, `pkgbuilds/frame/pacman/` pacman 7 with a current libalpm, and `pkgbuilds/frame/homeify` rewrites a stock Arch PKGBUILD into one (see [Packages for the host](#packages-for-the-host)) |
| `pkgbuilds/pc/` | PKGBUILDs for an Arch PC instead, ordinary `/usr` packages installed with `makepkg -si` there: `pkgbuilds/pc/krdpserver-embed-cursor/`, a krdpserver that can paint the PC's own pointer into the stream (see [Apps](#apps)), and `pkgbuilds/pc/frame-control-bin/`, [Frame Control](https://github.com/saphid/frame-control) as an Arch package built from its release `.deb` (the PKGBUILD's header says what it changes) |
| `bin/pacman-home` | pacman for packages under `~/.local`, with its database there and no root: the ones built from `pkgbuilds/frame/`, and stock binary packages it relocates (same section) |
| `bin/makepkg-home` | builds one of `pkgbuilds/frame/`, installs it with `pacman-home`, and offers to delete the build's leftovers (same section) |
| `docs/` | memos on the surrounding ground: [Arch-based distrobox images for arm64](docs/arch-distrobox-images.md); [the proximity sensor](docs/proximity-sensor.md), on the `frame-prox` tool that SteamOS 0.4.4 made redundant and how its undocumented settings were found; [the desktop cursor](docs/desktop-cursor.md), what SteamOS 0.5.6 changed for the two cursor fixes and how to re-check on the next one; [packages under `~/.local`](docs/home-packages.md), what each one took to get there; [paru](docs/paru.md), tried on the home database and dropped; [the screen reader](docs/orca-screen-reader.md), the command that silences Orca's "dummy output module" message and why Steam restarts it at every boot; and [trust](docs/TRUST.md), what `setup.sh` fetches and who is trusted at the root (the apps have [apps/TRUST.md](apps/TRUST.md)) |

## Setup

```bash
~/steam-frame-utils/setup.sh
```

With no options, on a terminal, it is an interactive installer: it goes through the options
below in its usual order, and each part that is installed shows as `ok`, while each part that is
missing is asked about there and installed right away. emacs and waypipe are asked as host, box
or neither. Every change is asked about before it is made: a copy, a backup or an install on its
own line (`copy ~/.config/...? [Y/n]`), and a change to `~/.bashrc`, `~/.zshrc`, `~/.profile` or
`~/.distroboxrc` with its diff, the file copied to `<file>.bak-<timestamp>` before the run first
changes it. A part just taken up isn't asked again for each of its steps. Enter takes the
default: for a missing part, yes on a first run (the [fresh-Frame](#a-fresh-frame) set) and no
on a re-run, so pressing Enter through a re-run adds nothing; for a change to what is there, yes.
Switching a route in place takes the option. Inside a distrobox it asks only what the box
allows. Without a terminal, or with any option, it asks nothing.

```bash
~/steam-frame-utils/setup.sh --check
```

```bash
~/steam-frame-utils/setup.sh [--brew] [--zsh] [--arch] [--emacs[=host|box]] [--waypipe[=host|box]] [--mise] [--packages[=NAME,...]] [--tailscale[=trust]] [--nerd-fonts[=NAME,...]]
```

`--check` reports what would change and changes nothing. A re-run touches only what is missing or
out of date, so after pulling this repo, run it again.

Always, whatever the options:

| What | How |
|---|---|
| `~/.local/bin` first in `PATH` | adds `export PATH=~/.local/bin:$PATH` to `~/.bashrc` and `~/.profile`, unless a line there already puts `~/.local/bin` on `PATH` |
| distrobox | installs into `~/.local` if `~/.local/bin/distrobox` is missing |
| `distrobox/distroboxrc` | inserts into `~/.distroboxrc`, which puts this checkout's `bin/` first for distrobox |
| `bin/` | goes on `PATH` from this checkout, through `shell-init/bin.sh` (see [Shell init](#shell-init)), so a `git pull` updates its scripts. A copy in `~/.local/bin` from an earlier version would come first, so it is backed up to `<file>.bak-<timestamp>` |
| `shell-init/frametop.sh` | sourced from the block at the top of `~/.bashrc`, and of `~/.zshrc` if that exists (see [Shell init](#shell-init)) |
| `environment.d/` | through `bin/sw-cursor`: copies to `~/.config/environment.d/`, unless `sw-cursor off` was chosen; reboot afterwards (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)). Interactive, it is offered when nothing is there |
| `autostart/` | with the software cursor: copies to `~/.config/autostart/`, and to `~/.config/frametop/autostart/` once Frametop is installed, with this checkout's path in `Exec`; each desktop picks it up at its next start |

Options add the rest, and each one also fixes only what's missing:

| Option | What |
|---|---|
| `--brew` | Homebrew in `/home/linuxbrew/.linuxbrew` if it isn't there, wl-clipboard (`wl-copy` and `wl-paste`) from it, and `shell-init/brew.sh` in the block at the top of `~/.bashrc` and `~/.zshrc` (see [Homebrew](#homebrew)). Uses sudo once, to create `/home/linuxbrew`. Refused inside a distrobox |
| `--zsh` | implies `--brew`. zsh from Homebrew, and an empty `~/.zshrc` if there is none, so zsh skips its new-user menu |
| `--arch` | creates the `arch` distrobox from `docker.io/menci/archlinuxarm:latest`, Arch Linux ARM, if it doesn't exist (see [Arch-based distrobox images for arm64](docs/arch-distrobox-images.md) for why that image, and for the pacman sandbox the box is created without). The image is about 0.7 GB and the first start takes a few minutes, so it says so and asks first; `--yes` skips the question |
| `--emacs` | emacs from one of two sources (see [emacs and waypipe: host or box](#emacs-and-waypipe-host-or-box)). `=host`: `pkgbuilds/frame/emacs/` built here and installed under `~/.local` by `pacman-home`, the same as `--packages=emacs-wayland`. `=box`: implies `--arch`; emacs-wayland, the pgtk build, in the box, with `emacs` and `emacsclient` exported to `~/.local/bin` (an export left by another box is replaced; anything else there is left alone). Bare, it keeps the route in place, host when there is none. Switching asks before replacing what is there; `--yes` answers |
| `--waypipe` | waypipe for the host from one of two sources (same section), and `shell-init/waypipe.sh` in `~/.bashrc` and `~/.zshrc` (see [The waypipe function](#the-waypipe-function)). `=host`, or `=arch`, its old name: Arch Linux ARM's package relocated under `~/.local` by `install-waypipe.sh` through `pacman-home`; it doesn't update waypipe, `install-waypipe.sh` does. `=box`: implies `--arch`; a copy of the box's `/usr/bin/waypipe`, the same package, which pacman in the box keeps current (`distrobox upgrade arch`) and a re-run refreshes. Bare and switching as for `--emacs` |
| `--mise` | [mise](https://mise.jdx.dev) in `~/.local/bin` if it isn't there, `shell-init/mise.sh` in the `end` block of `~/.bashrc` and `~/.zshrc` unless the file activates mise already, and rust through it, `mise use -g rust`, for a Rust package in `pkgbuilds/frame/` (see [mise](#mise)). It doesn't update the tools; `mise upgrade` does |
| `--packages` | the packages in `pkgbuilds/frame/`, built with makepkg and installed with `pacman-home`: each one `pacman-home` doesn't have at its PKGBUILD's version, in dependency order (see [Packages for the host](#packages-for-the-host)); `--packages=NAME,...` for some of them. A Rust package needs `--mise` for cargo |
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
`pkgbuilds/frame/emacs/` on the Frame itself, waypipe relocated from Arch Linux ARM's package (see
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
`pkgbuilds/frame/`, pacman 7 and emacs, built here and installed under `~/.local` (`--emacs=box
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
emacs is built for the host from `pkgbuilds/frame/emacs/` or exported from the arch box, and
waypipe is Arch Linux ARM's package, relocated or copied from that box: Homebrew's emacs is
terminal-only, and it has no waypipe.

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
[apps/TRUST.md](apps/TRUST.md) says what each one verifies, who is trusted at the root, and
what the app gets on the headset.

| Script | App | Where it goes |
|---|---|---|
| `install-stream-frame.sh [--yes]` | [Stream Frame](https://streamframe.app), for watching, recording and screenshotting the headset from another device | Flatpak `com.boxtree.StreamFrame`, system-wide, from Boxtree's repo; uses sudo |
| `install-moonlight.sh [--yes]` | [Moonlight](https://moonlight-stream.org), for streaming games from a Sunshine or GeForce Experience host | Flatpak `com.moonlight_stream.Moonlight`, system-wide, from Flathub; uses sudo |
| `install-krdc.sh [--yes]` | [KRDC](https://apps.kde.org/krdc), KDE's RDP and VNC client, for a Plasma desktop shared with KRdp | Flatpak `org.kde.krdc`, system-wide, from Flathub; uses sudo |
| `install-deskflow.sh [--yes]` | [Deskflow](https://deskflow.org), keyboard and mouse sharing, so a PC's mouse and keyboard reach the Frametop desktop | Flatpak `org.deskflow.deskflow`, system-wide, from Flathub; uses sudo |
| `install-bsmanager.sh` | [BSManager](https://github.com/DaVarga/bs-manager), DaVarga's arm64 fork, for Beat Saber versions, mods and maps | `~/Applications/BSManager.AppImage`, with a menu entry and the BeatSaver OneClick links |
| `install-full-keyboard.sh [--version X.Y.Z \| --uninstall]` | [Full Keyboard](https://github.com/TaiKeid/steam-frame-full-keyboard), TaiKeid's full-size virtual keyboard for the dashboard and local apps | `~/.local/share/framekeyboard`, with the launcher `~/.local/bin/framekeyboard` and a menu entry |
| `install-frametop.sh [--version X.Y.Z] [--yes] [--no-eye-tracker] [--no-bluetooth \| --bluetooth] [--any-steamos] [--unpack-only] \| --uninstall` | [Frametop](https://github.com/Frametop/frametop), the multi-screen Plasma desktop and 3D mouse that run on the Frame itself | `~/.local/share/frametop/releases/<version>`, with a podman image and container from the release's `Frametop.zip`, and services in the home directory; two optional parts use sudo |
| `install-krdp.sh [--bundle [FILE] \| --uninstall]` | [KRdp](https://invent.kde.org/plasma/krdp)'s server, krdpserver, for serving a Plasma desktop on the Frame over RDP to KRDC, Remmina or Windows Remote Desktop | Flatpak `io.github.curiousjtuber.Krdp`, built here on KDE's runtime, in the user installation; no root. Run with `bin/krdpd`, or KRdp Server in the menu |

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
  screen, and KRDC gets a blank blue screen until someone answers it there. KRdp sends KRDC the
  pointer's shape, drawn at the Frame's own pointer, so a mouse moved at the PC shows only as
  focus changes. `pkgbuilds/pc/krdpserver-embed-cursor/` is krdpserver from the Plasma release
  pacman has, with one patch, as an Arch package beside `krdp` (`makepkg -sri` on the PC): with
  `EmbedCursor=true` in `[General]` of `~/.config/krdpserverrc`, KWin paints the PC's pointer into
  the stream and KRDC draws none, so the headset sees where the PC's mouse is (turn off KRDC's
  View → Show Local Cursor, or it draws its own on top). Off, it is upstream's server. Pointing
  the drop-in's `ExecStart` at `/usr/bin/krdpserver-embed-cursor` switches to it; the PKGBUILD's
  header has the commands and the rebuild after a Plasma update.
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
- **Frametop** comes as one release file, `Frametop.zip`, that its CI builds from the
  tagged commit on an arm64 runner: a podman image with everything compiled, and its
  installer. The script records the zip's sha256 for the version it names, checks the
  download against it and against the release's `SHA256SUMS`, and runs the zip's
  `install-release.sh`, which checks the image file against the sha256 in the zip's
  `frametop-release.json`, loads it, copies the release's files out and runs their
  `install.sh`: nothing compiles, and nothing else downloads but the table of tested
  SteamOS builds, which the zip also carries for offline. A release replaced on GitHub
  fails the recorded sum; `--version` takes another release and then has only
  `SHA256SUMS` to check against, which it says. The SteamVR driver, the services and
  the desktop go in the home directory. Frametop's own eye tracker, a root service in
  `/etc/frametop`, and the Bluetooth fixes, in `/etc/steamframe`, are the two parts
  that ask for sudo, and each is offered, not forced. For 0.2.2, the zip's scripts and
  the source tree inside its image were compared with the tagged commit: identical.
  Frametop's commits and tags aren't signed, so GitHub's TLS and the maintainer's
  account are the root of trust, as for Full Keyboard and BSManager. A source checkout
  in `~/frametop` is left alone, but the launcher's Desktop entry and the services
  switch to the release; that checkout's `install.sh` switches them back.
- **KRdp's server** is the other direction: the Frame as the RDP host, for seeing and using a
  Plasma desktop that runs on it (Frametop's, or SteamOS's stock Desktop) from a PC. SteamOS has
  no krdp and Flathub only has the client, so `install-krdp.sh` builds it as a flatpak on KDE's
  runtime, with its own FreeRDP and kpipewire, pinned and patched as the manifest in `apps/krdp/`
  explains (krdp 6.7.5 gets 6.8's NLA login, which works with FreeRDP 3.32 clients; kpipewire
  crashes on the 256 px cursor gamescope sets). The first run installs the KDE 6.11 SDK and
  flatpak-builder (about 1 GB to download) and builds for half an hour; later runs
  rebuild only what changed. KWin lets the sandboxed server capture through the app's desktop
  file, so neither desktop needs KWin's permission checks turned off. Nothing starts it by
  itself. `--bundle` also writes the build as one `.flatpak` file, which another aarch64 device
  installs with `flatpak --user install FILE` and no build. GitHub builds the same bundle on an
  arm64 runner (`.github/workflows/krdp-flatpak.yml`) when the manifest changes, and attaches it
  to the release when a `krdp-*` tag is pushed.
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
- **KRdp Server**, the menu entry `install-krdp.sh` adds, is `bin/krdpd-gui`: a window that
  starts and stops the same server and shows where to connect, the password, and the log. It runs
  `krdpd` for everything, so the two never disagree, and the server keeps running after the window
  closes. It's GTK 4 and libadwaita through Python, all in SteamOS's image, so it needs nothing
  installed; run it on the host, from either desktop.
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
manages are on `PATH` in every shell: rust, for a Rust package in `pkgbuilds/frame/`, and whatever
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
version differs, takes it only with a valid signature from Arch Linux ARM's keys (see below), and
the package's `/usr` tree is moved under `~/.local` and installed into `pacman-home`'s database,
so `pacman-home -Q waypipe` knows it and `pacman-home -R waypipe` removes it. A library the host
lacks, a newer glibc among them, is reported before the install. A waypipe from before
`pacman-home`, a bare binary in `~/.local/bin`, is backed up to `waypipe.bak-<timestamp>` first.
`--waypipe=box` takes the other source: a copy of the `arch` box's `/usr/bin/waypipe`, the
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
frame itself. SteamOS 0.5.6 draws the controller's mouse-mode cursor on its own, but not a real
mouse's, Deskflow's for one, so the fix stays the default. The fix comes from Cas and Chary XR's
[Steam Frame: 10 Things To Do FIRST](https://www.youtube.com/watch?v=jtW2mQd5qYI), credited
there to ThrillSeeker.

systemd reads `~/.config/environment.d` at login, and KWin reads the variable once, at its start,
so a change takes a reboot; nothing switches it in a running desktop. `env | grep KWIN` in a
Desktop Mode Konsole confirms it.

`bin/sw-cursor` manages the file, `~/.config/environment.d/90-kwin-software-cursor.conf`:

```bash
sw-cursor            # what is set, SteamOS's default, and what the running desktop got
sw-cursor on         # the software cursor for the next sessions
sw-cursor off        # without it
sw-cursor default    # the default again, on
```

`setup.sh` runs `sw-cursor auto`: the default where nothing was chosen. Interactive, with
nothing in place, it offers the software cursor instead. `on` and `off` are a choice it keeps,
written into the file with a marker line (`KWIN_FORCE_SW_CURSOR=0` for `off`, so a later run
neither reinstalls nor removes it); `default` forgets the choice. A file there that isn't
steam-frame-utils' is left alone by `auto` and `default`, and backed up by `on` and `off`.
Frametop's session script sets the variable for its own KWin, so `sw-cursor` doesn't change the
Frametop desktop's cursor. [docs/desktop-cursor.md](docs/desktop-cursor.md) has what was found on
0.5.6.

### Cursor size

Both desktops start inside Game Mode's gamescope, and inherit its `XCURSOR_SIZE=256` and
`XCURSOR_THEME=steam` (gamescope exports them, and `/usr/lib/steamos/gamescope-onready` imports
them into the systemd user environment). KWin takes those two over the size and theme Plasma keeps
in `kcminputrc` (`[Mouse] cursorSize` and `cursorTheme`, 24 and `breeze_cursors` by default), so
the cursor comes up huge and System Settings' choice is lost at the next start.

`cursor-size` sets it for the running desktop:

```bash
cursor-size 32
```

It writes `kcminputrc` and tells KWin to reload it, the way System Settings' Cursors page does, so
the cursor changes at once. With no size it prints the current one; `--theme NAME` sets the theme
as well. From a terminal inside a desktop it changes that desktop. From SSH or Game Mode it changes
the one that runs (Frametop's first), or the one `--desktop frametop|stock` names; with neither
running it saves the setting for both. Apps that draw their own cursor, X11 ones and some older
toolkits, size it from the `XCURSOR_SIZE` the desktop started with.

At each start KWin takes gamescope's variables again, so `sw-cursor` (and `setup.sh` through it)
installs `autostart/steam-frame-utils-cursor.desktop` in each desktop's autostart dir; it runs
`cursor-size --apply`, which gives KWin the saved setting without changing it. The cursor is 256 px
for the second or two until Plasma reaches autostart. SteamOS 0.5.6 keeps the size itself, but
only without the software cursor; with it the desktops take gamescope's 256 px again, so the entry
goes wherever the `environment.d` file does, and is removed with `sw-cursor off`.

The obvious place, a script in `plasma-workspace/env/` exporting the variables before KWin starts,
doesn't work on the Frame, and that's worth knowing for anything else one might put there. Plasma
sources every env script, the system ones in `/etc/xdg` first, in one shell that then prints the
environment back. SteamOS's `/etc/xdg/plasma-workspace/env/set-return-icon.sh` does `set -eu` and
reads `/sys/class/dmi/id/board_name`, a DMI node the arm64 Frame doesn't have, so the shell dies
there and startplasma gets nothing back: no env script takes effect, SteamOS's own language and
ibus ones included. The systemd user environment is no way in either: the desktops run on a
private D-Bus (`dbus-run-session`), where startplasma's import of it fails.

## Packages for the host

The Frame's image carries makepkg, gcc, meson, cmake and the headers of its libraries, so a
package can be built on the host itself, against the exact libraries it will run with, with no
distrobox and no cross toolchain. `pkgbuilds/frame/` holds PKGBUILDs configured with
`--prefix=$HOME/.local`, so the result finds its data under `~/.local` instead of the read-only
`/usr`. `pkgbuilds/frame/emacs/` is Emacs with PGTK, a host build that sees the Frame's own `/usr`,
D-Bus and processes, which the distrobox one does not; `setup.sh --emacs` (or `--packages`)
builds and installs it, and `--emacs=box` is the distrobox alternative. The header of each
PKGBUILD says what it leaves out and why.

```bash
cd ~/steam-frame-utils/pkgbuilds/frame/emacs && makepkg -f
```

```bash
pacman-home -U emacs-wayland-*.pkg.tar.zst
```

`makepkg-home emacs` is those two commands, from any directory, followed by an offer to delete
what the build left: `src/`, `pkg/`, the package and the downloaded sources, about half a gigabyte
for emacs, listed with their size before the question (`--clean` deletes unasked, `--keep` asks
nothing; homeify's `PKGBUILD.upstream` is kept either way). Keep them while a PKGBUILD is being
adjusted, since `makepkg -R` repackages from them in seconds. `setup.sh --packages` builds every
directory under `pkgbuilds/frame/` that `pacman-home` doesn't have at the PKGBUILD's version, in
dependency order; a re-run builds nothing, and after a SteamOS update it rebuilds what you bump.
`pkgbuilds/pc/` is the other kind, ordinary `/usr` packages for an Arch PC, which nothing here
builds or offers: `krdpserver-embed-cursor` and `frame-control-bin` (see [Apps](#apps) and the
table above).

Any package whose build takes a prefix can be set up the same way. `pkgbuilds/frame/homeify NAME`
fetches Arch's PKGBUILD for NAME, or the AUR's when Arch has none, rewrites it for the prefix (the
configure, cmake, meson and make prefix flags, `/usr` under `$pkgdir`, `aarch64` in `arch`, the
rpath and pkg-config path for `~/.local/lib`, and for a Rust package the rpath in `RUSTFLAGS` too),
unlists the `makedepends` that mise provides, such as cargo, since makepkg checks them against the
host's packages, prints the diff, and says which `makedepends` the host lacks. Review it, then
`makepkg -f` and `pacman-home -U`; paru's PKGBUILD was homeify's output with no hand edit, while it
was here ([docs/paru.md](docs/paru.md)). The rewrite is the mechanical part: a build system that
hardcodes `/usr` shows up afterwards as a file outside `~/.local`, which `pacman-home check PKG`
lists and `pacman-home -U` refuses, and is fixed in the PKGBUILD by hand, as
`pkgbuilds/frame/pacman/` and `pkgbuilds/frame/emacs/` were, for features the host lacks and a
layout that keeps out of the host's way.

A program that needs no file outside its own tree, such as waypipe, needn't be built at all.
`pacman-home relocate NAME` fetches Arch Linux ARM's binary package through pacman's own
repository machinery, against one mirror (`ALARM_MIRROR` overrides it), takes it only with a
valid signature from Arch Linux ARM's keys,
moves its `/usr` tree under `~/.local`, points its absolute symlinks there, drops its install
scriptlet, and installs the result; `relocate FILE` does the same to a package you have. It
refuses a package with files under `/etc` or `/var`, or under the parts of `/usr` that only work
from there (systemd and udev directories, polkit, system D-Bus services), and one whose libraries
the host cannot supply, a glibc or Qt newer than the host's included, since the loader names the
symbol version it lacks; `--allow-missing-libs` installs anyway. What it cannot see is a program that looks for its data under `/usr` at
run time; that one needs a build.

### Which way in

For a new program, in this order:

The keys come from Arch Linux ARM's `archlinuxarm-keyring` package, which `pacman-home keyring`
(run by `relocate NAME` the first time, and by `setup.sh --waypipe=host` for a waypipe from
before) fetches once with signatures off, since there is nothing to check it with yet, and holds
to the key fingerprint recorded in `pacman-home` instead, checked against archlinuxarm.org: a
keyring that trusts other keys is refused. `pacman-key` then populates `pacman-home`'s own
keyring under `~/.local/etc/pacman.d/gnupg`, under fakeroot like pacman. `pacman-home keyring
--check` says whether the keys are there. Arch Linux ARM doesn't sign its databases, so those
are taken on the mirror's word, as every pacman does.

1. **`pacman-home relocate NAME`, and run the program.** It is the whole job when the program
   needs nothing outside its own tree. Relocate refuses a package with files outside `/usr` or in
   the parts of `/usr` that only work from there, drops an install scriptlet, and refuses one whose
   libraries the host lacks; what it cannot see is a program that looks for its data under
   `/usr` at run time, which installs cleanly and then fails or falls back to defaults. So the
   test is both: relocate accepts it, and the program works. waypipe passed; anything with data
   files, plugins, schemas or Python modules is likely to fail the second part.
2. **`pkgbuilds/frame/homeify NAME`, then `makepkg -f` and `pacman-home -U`.** Often the whole job
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
repositories, with the AUR for one they lack, and with its PKGBUILD in `pkgbuilds/frame/`, so
a bump upstream shows up without a build. The release number after the dash is this repo's own and
isn't compared; a packaging that tracks git, as Arch's pacman does, is marked as a snapshot.

The pacman it runs is the host's until `pkgbuilds/frame/pacman/` is installed. That is pacman 7
built for the prefix, with its programs under `~/.local/lib/pacman/bin` so that `pacman` on `PATH`
keeps meaning the host's, and with `~/.local/etc/pacman.conf` and `~/.local/var/lib/pacman` as its
compiled-in defaults, so run by its path it reads the home database with no `--config`. Its libalpm
is current, libalpm.so.16 where the host's pacman 6.1 carries .so.14, for anything built against
libalpm. It also skips the ldconfig run that the host's pacman attempts after every transaction and
that fails on the read-only root. `pacman-home` switches to it as soon as it is installed and still
looks host packages up with the host's.

After a SteamOS update, `ldd ~/.local/bin/emacs | grep "not found"` says whether a host library
moved from under a build; the fix is a rebuild and `pacman-home -U` again.

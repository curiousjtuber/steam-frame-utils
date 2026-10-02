# steam-frame-utils

Setup for the Steam Frame: arm64 SteamOS, with an immutable root and A/B updates.

Clone it on the Frame as `~/steam-frame-utils`; the paths below assume that location.

| Path | |
|---|---|
| `setup.sh` | checks and installs everything below (see [Setup](#setup)) |
| `install-tailscale.sh` | Tailscale as a system service that survives updates (see [Tailscale](#tailscale)) |
| `install-nerd-fonts.sh` | Nerd Fonts in the home directory, no root needed (see [Nerd Fonts](#nerd-fonts)) |
| `apps/` | installers for apps: Stream Frame and BSManager (see [Apps](#apps)) |
| `shell-init/` | bash and zsh init for the `tailscale` alias, `waypipe`, and terminals in the Frametop desktop (see [Shell init](#shell-init)) |
| `bin/podman` | lets distrobox work from Desktop Mode and the Frametop desktop (see [Distrobox in Desktop Mode](#distrobox-in-desktop-mode)) |
| `bin/frame-prox` | the proximity sensor's readings and threshold, and the setting that moves it (see [Proximity sensor](#proximity-sensor)) |
| `distrobox/distroboxrc` | makes distrobox find `bin/podman` whatever the caller's `PATH` (same section) |
| `environment.d/` | shows the mouse cursor in Desktop Mode (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |

## Setup

```bash
~/steam-frame-utils/setup.sh --check
```

```bash
~/steam-frame-utils/setup.sh [--zsh] [--emacs] [--waypipe] [--tailscale[=trust]] [--nerd-fonts[=NAME,...]]
```

`--check` reports what would change and changes nothing. A re-run touches only what is missing or
out of date, so after pulling this repo, run it again.

With no options:

| What | How |
|---|---|
| `~/.local/bin` first in `PATH` | adds `export PATH=~/.local/bin:$PATH` to `~/.bashrc` and `~/.profile`, unless a line there already puts `~/.local/bin` on `PATH` |
| distrobox | installs into `~/.local` if `~/.local/bin/distrobox` is missing |
| `bin/podman` | copies to `~/.local/bin/podman` |
| `distrobox/distroboxrc` | inserts into `~/.distroboxrc` |
| `bin/frame-prox` | copies to `~/.local/bin` |
| `shell-init/frametop.sh` | inserts at the top of `~/.bashrc`, and of `~/.zshrc` if that exists (see [Shell init](#shell-init)) |
| `environment.d/` | copies to `~/.config/environment.d/`; reboot afterwards |

Options add the rest, and each one also fixes only what's missing:

| Option | What |
|---|---|
| `--ubuntu` | creates the `ubuntu` distrobox from `quay.io/toolbx/ubuntu-toolbox:26.04` if it doesn't exist. The image is about 1.2 GB and the first start takes several minutes, so it says so and asks first; `--yes` skips the question |
| `--zsh` | implies `--ubuntu`. zsh in the box, exported as `~/.local/bin/zsh`, and an empty `~/.zshrc` if there is none, so zsh skips its new-user menu. An existing `~/.local/bin/zsh` exported from another box is left alone |
| `--emacs` | implies `--ubuntu`. emacs-pgtk, the Wayland build, in the box, with `emacs` and `emacsclient` exported to `~/.local/bin`. emacs-gtk, the X11 build that a plain `apt install emacs` picks, conflicts with it and is removed. apt's recommended mailutils is left out, since it brings postfix along. An existing export from another box is left alone, as with zsh |
| `--waypipe` | implies `--ubuntu`. waypipe in the box, a copy of its binary in `~/.local/bin` for the host, and `shell-init/waypipe.sh` in `~/.bashrc` and `~/.zshrc` (see [Shell init](#shell-init)) |
| `--tailscale` | fixes what's missing of the install, with sudo: `install-tailscale.sh` if the binaries or the unit are gone, otherwise just `systemctl enable`/`start`. Adds `shell-init/tailscale.sh`. `--tailscale=trust` also puts `tailscale0` in firewalld's `trusted` zone. Logging in is only reported. Without the option, what's missing is still reported |
| `--nerd-fonts` | runs `install-nerd-fonts.sh` for each font not installed yet: `JetBrainsMono` and `NerdFontsSymbolsOnly`, or a comma-separated list such as `--nerd-fonts=FiraCode,Hack`. It doesn't update installed ones; `install-nerd-fonts.sh` does that |

The rest of the box's setup, such as mise and tmux, is personal and not part of this.

The host and its distroboxes share the home directory, so `setup.sh` runs inside a distrobox too.
What needs the host is refused there: `--tailscale`, and `--ubuntu`, `--zsh`, `--emacs` and
`--waypipe` in any box but `ubuntu`. From the host, the box's part of `--zsh`, `--emacs` and
`--waypipe` runs through `distrobox enter ubuntu`.

Files are copied, not linked, so the Frame doesn't depend on this checkout staying where it is. A
file that differs is moved to `<file>.bak-<timestamp>` first. Inserted text sits between
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
| `install-bsmanager.sh` | [BSManager](https://github.com/DaVarga/bs-manager), DaVarga's arm64 fork, for Beat Saber versions, mods and maps | `~/Applications/BSManager.AppImage`, with a menu entry and the BeatSaver OneClick links |

- **Stream Frame** is what Discover installs from the website. Run it on the host, not in a
  distrobox. The first install also pulls the KDE runtime from Flathub, a few hundred MB, and
  asks first unless given `--yes`. `/var/lib/flatpak` is a bind mount into `/home/.steamos/offload`,
  so SteamOS updates keep it. It needs ffmpeg on the headset, and SteamOS already has it in
  `/usr/bin`.
- **BSManager** runs the fork's own `install.sh` from its latest release, passing on
  `--uninstall` and `--appimage FILE`. After that, BSManager updates itself.

## Proximity sensor

A proximity sensor, a Vishay VCNL4040 (the kernel's `vcnl4000` IIO driver), tells SteamVR whether
the Frame is worn; `steamvr-proxmicmute.service`, for one, mutes the microphone when it isn't. If
SteamVR keeps losing you while you wear it, its threshold is too high for your face and fit, and
**`driver_cv.proxSensorThresholdMultipleConst`** is the setting that lowers it.

```bash
frame-prox
```

```bash
frame-prox --watch
```

```bash
frame-prox --set 1.0
```

The first prints a reading, the factory calibration, the settings, and the threshold SteamVR uses;
`--watch` prints a reading every 0.3 seconds against that threshold. A higher reading is closer.
`--set` changes the multiplier, and with it the threshold.

- **The threshold comes from SteamVR's `cv` driver,** not the kernel. At startup it reads two
  factory values from the headset's EEPROM, `prox_far` and `prox_noise`, and works out a
  threshold and a noise adjustment from them and the `driver_cv` settings
  `proxSensorThresholdMultipleConst` and `proxSensorNoiseExponentConst`. Their defaults, 1.4 and
  0.85, are in `/opt/steamvr/drivers/frame_hmd/resources/frame_hmd_additional.vrsettings`. It logs
  both results to `vrserver.txt`, which is where `frame-prox` gets them.
- **The formula isn't documented,** but one Frame's numbers fit (`prox_far` − `prox_noise`) ×
  multiplier for the threshold, and `prox_noise` ^ exponent for the noise adjustment. With
  `prox_far` 17 and `prox_noise` 5, the default gave a threshold of 16.8 and an adjustment of 3.93.
  Worn, that Frame read 19.2 to 19.6, and SteamVR lost it now and then. How the driver applies
  the noise adjustment isn't logged, so `--watch` shows the reading's margin over the threshold
  both without it (`-threshold`) and with it subtracted too (`-noise-threshold`).
- **A lower multiplier detects you from further away.** 1.0 gave that Frame a threshold of 12,
  with readings of about 4.5 off the face, and fixed it. Put the headset on and check that
  `--watch` stays above the new threshold, and take it off and check that it drops well below.
- **`--set` goes through `vrcmd --set-settings-float`,** and needs SteamVR running. The driver
  takes the change at once, and vrserver saves it to your `steamvr.vrsettings` (in
  `~/.config/openvr/config`), where it outlasts SteamVR updates. Editing that file by hand while
  SteamVR runs doesn't stick, since vrserver writes back the settings it holds on its next change.
  Stopping `steamvr.service` to edit it isn't safe either: the gamescope session stops with it and
  starts it again straight away.
- **To go back to the default,** `frame-prox --set 1.4`. The key stays in your file, though, so it
  won't follow a later change of the default in a SteamVR update. To remove it, delete it from
  `steamvr.vrsettings` while SteamVR is stopped (`sudo steamvr stop`, then `sudo steamvr start`,
  which stop and start the whole session).
- **`driver_cv.disableProxSensor`** turns detection off altogether:
  `steamvr cmd --set-settings-bool driver_cv.disableProxSensor true`.
- **The kernel's `in_proximity_nearlevel` and threshold events** under
  `/sys/bus/iio/devices/iio:device*` aren't what SteamVR uses; changing them does nothing for this.

`frame-prox` runs on the host. Run from a distrobox, it goes through `distrobox-host-exec`.

### How the key was found

None of this is documented. OpenVR's `openvr.h` names the core settings keys but not any driver's
own, such as `driver_cv`'s, and SteamVR's settings UI doesn't show them. Valve's SteamOS 0.4.1
notes say only that the "proximity sensor detection model" improved. If an update renames the key
or moves the logic, and `frame-prox` stops finding a threshold, the same steps should find the
replacement:

- **The settings:** `grep -ril --include='*.vrsettings' prox /opt/steamvr` finds them in one
  file, `drivers/frame_hmd/resources/frame_hmd_additional.vrsettings`, as bare JSON values.
- **What reads them:** `strings` on `/opt/steamvr/drivers/cv/bin/linuxarm64/driver_cv.so` shows
  the key names, the `eeprom_console get prox_far` and `get prox_noise` calls, and the message it
  logs to `vrserver.txt` with the threshold.
- **The proof:** changing the multiplier with `vrcmd` and watching that message.

`/usr/lib/deckard-eeprom/eeprom_console` also holds `prox_near` and `prox_mid` (564 and 91 on that
Frame), apparently factory readings at closer distances; `driver_cv.so` doesn't use them. Use
only its `get` command: `reset`, `lock`, `unlock` and `upgrade` write the factory EEPROM.

## Shell init

`shell-init/` holds one file per feature, each inserted at the end of `~/.bashrc`, and of
`~/.zshrc` if that exists, as its own marked block. `waypipe.sh` goes in with `--waypipe`, and
`tailscale.sh` with `--tailscale`. `frametop.sh` always goes in, at the top instead.

The bare host and its distroboxes share one home directory, so the same blocks run in all of them;
zsh itself is a distrobox export. The containers read the same `~/.bashrc`, so any host-only line
added there outside these blocks runs inside every distrobox too. Put such checks in a
`shell-init/` file instead.

### The tailscale alias

`tailscale.sh` checks where it is running, using `$CONTAINER_ID` or `/run/.containerenv`:

| Where | `tailscale` alias |
|---|---|
| Bare host (bash) | `/home/.tailscale/bin/tailscale` |
| A distrobox (bash or zsh) | `distrobox-host-exec /home/.tailscale/bin/tailscale` |

A distrobox sees neither `/home/.tailscale` nor the daemon's socket in the host's `/run`, so the
CLI has to run on the host.

### The waypipe function

`waypipe` is a function around the real binary: the `ubuntu` box's `/usr/bin/waypipe`, which
`--waypipe` also copies to `~/.local/bin` so the host can run it without entering the box. Game
Mode is an X11 session: gamescope names its Wayland socket only in `GAMESCOPE_WAYLAND_DISPLAY`
(`gamescope-0`), so a `waypipe` client started from a terminal there fails with `WAYLAND_DISPLAY is
not set`. When `WAYLAND_DISPLAY` is empty, the function fills it in from
`GAMESCOPE_WAYLAND_DISPLAY` for that one command. With that, `waypipe ssh <host> <app>` from a Game
Mode Konsole shows a remote app on the Frame. The shell itself doesn't export it, because Qt and
GTK apps started from that terminal would then leave Xwayland for native Wayland.

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
Plasma's `wayland-0`, X display and session bus. `setup.sh` copies it to `~/.local/bin`, which
comes before `/usr/bin` in `PATH`.

### `~/.distroboxrc`

`~/.local/bin` comes first once an rc file has run, but not for a distrobox export started as a
terminal's shell,
such as `~/.local/bin/zsh`: the Frametop desktop's `PATH` doesn't have `~/.local/bin`, so the
export's `distrobox-enter` finds `/usr/bin/podman` and fails with the crun error above. distrobox
sources `~/.distroboxrc` before it looks for podman, so `setup.sh` puts a block there
(`distrobox/distroboxrc`) that moves `~/.local/bin` to the front of `PATH` for distrobox alone.

## Mouse cursor in Desktop Mode

In Desktop Mode the mouse moves but its cursor isn't drawn. KWin puts the cursor on a hardware
plane, which the headset's view doesn't show. `KWIN_FORCE_SW_CURSOR=1` makes KWin draw it into the
frame itself. The fix comes from Cas and Chary XR's
[Steam Frame: 10 Things To Do FIRST](https://www.youtube.com/watch?v=jtW2mQd5qYI), credited
there to ThrillSeeker.

systemd reads `~/.config/environment.d` at login. `setup.sh` copies the file there; reboot
afterwards. `env | grep KWIN` in a Desktop Mode Konsole confirms it. To undo it, delete
`~/.config/environment.d/90-kwin-software-cursor.conf` and reboot.

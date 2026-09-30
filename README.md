# steam-frame-utils

Setup for the Steam Frame: arm64 SteamOS, with an immutable root and A/B updates.

Clone it on the Frame as `~/steam-frame-utils`; the paths below assume that location.

| Path | |
|---|---|
| `setup.sh` | checks and installs everything below (see [Setup](#setup)) |
| `install-tailscale.sh` | Tailscale as a system service that survives updates (see [Tailscale](#tailscale)) |
| `shell-init.sh` | shell init that tells the bare host from its distroboxes (see [Shell init](#shell-init)) |
| `bin/podman` | lets distrobox work from Desktop Mode (see [Distrobox in Desktop Mode](#distrobox-in-desktop-mode)) |
| `environment.d/` | shows the mouse cursor in Desktop Mode (see [Mouse cursor in Desktop Mode](#mouse-cursor-in-desktop-mode)) |

## Setup

On the Frame's host, not in a distrobox:

```bash
~/steam-frame-utils/setup.sh --check
```

```bash
~/steam-frame-utils/setup.sh
```

`--check` reports what would change and changes nothing. A re-run touches only what is missing or
out of date, so after pulling this repo, run it again.

| What | How |
|---|---|
| `~/.local/bin` first in `PATH` | adds `export PATH=~/.local/bin:$PATH` to `~/.bashrc` and `~/.profile` if it isn't there |
| distrobox | installs into `~/.local` if `~/.local/bin/distrobox` is missing |
| `bin/podman` | copies to `~/.local/bin/podman` |
| `environment.d/` | copies to `~/.config/environment.d/`; reboot afterwards |
| `shell-init.sh` | inserts into `~/.bashrc`, and into `~/.zshrc` if it exists |
| Tailscale | reports it only; `--tailscale` runs `install-tailscale.sh` with sudo if `tailscaled` isn't set up, and `--tailscale=trust` adds `--trust-tailnet` |

Files are copied, not linked, so the Frame doesn't depend on this checkout staying where it is. A
file that differs is moved to `<file>.bak-<timestamp>` first. Inserted text sits between
`# >>> steam-frame-utils: <name> >>>` and `# <<< … <<<` markers, and a re-run replaces it in place;
edit the source here, not the copy.

## Tailscale

`install-tailscale.sh` installs or updates Tailscale as a native system service, using kernel
TUN rather than userspace or proxy mode. `setup.sh --tailscale` runs it. To run it by hand,
copy the script to the Frame and run it there:

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

## Shell init

`shell-init.sh` is the Frame's host-specific init. `setup.sh` inserts it at the end of
`~/.bashrc`, and of `~/.zshrc` if that exists.

The bare host and its distroboxes share one home directory, so the same file runs in all of them;
zsh itself is a distrobox export. The file therefore checks where it is running, using
`$CONTAINER_ID` or `/run/.containerenv`:

| Where | `tailscale` alias |
|---|---|
| Bare host (bash) | `/home/.tailscale/bin/tailscale` |
| A distrobox (bash or zsh) | `distrobox-host-exec /home/.tailscale/bin/tailscale` |

A distrobox sees neither `/home/.tailscale` nor the daemon's socket in the host's `/run`, so the
CLI has to run on the host.

`waypipe` is a function around the real binary (in a box, or the `dbx-export` wrapper on the
host). Game Mode is an X11 session: gamescope names its Wayland socket only in
`GAMESCOPE_WAYLAND_DISPLAY` (`gamescope-0`), so a `waypipe` client started from a terminal there
fails with `WAYLAND_DISPLAY is not set`. When `WAYLAND_DISPLAY` is empty, the function fills it in
from `GAMESCOPE_WAYLAND_DISPLAY` for that one command. With that, `waypipe ssh <host> <app>` from a
Game Mode Konsole shows a remote app on the Frame. The shell itself doesn't export it, because Qt
and GTK apps started from that terminal would then leave Xwayland for native Wayland.

The containers read the same `~/.bashrc`, so any host-only line added there outside this block
runs inside every distrobox too. Put such checks in `shell-init.sh` instead.

## Distrobox in Desktop Mode

Desktop Mode on the Frame is Plasma nested inside gamescope, with its own session environment:

- `XDG_RUNTIME_DIR=/run/user/1000/nested_plasma` rather than `/run/user/1000`
- `DBUS_SESSION_BUS_ADDRESS` is a private bus under `/tmp` with no `systemd --user` behind it

Rootless podman breaks on both. crun asks `org.freedesktop.systemd1` on the session bus for the
container's cgroup, so `distrobox enter` fails with
`crun: sd-bus call: Process org.freedesktop.systemd1 exited with status 1`. And podman keeps its
runtime state under `$XDG_RUNTIME_DIR`, so a container started from SSH or Game Mode looks
unset-up from Desktop Mode: `unable to find user steamos: no matching entries in passwd file`.

`bin/podman` switches podman alone to the real runtime dir and user bus when it runs under
`nested_plasma`, and passes through untouched everywhere else. distrobox still forwards the Desktop
Mode environment into the container, so GUI apps there reach the nested Plasma's
`wayland-0`, X display and session bus. `setup.sh` copies it to `~/.local/bin`, which comes
before `/usr/bin` in `PATH`.

## Mouse cursor in Desktop Mode

In Desktop Mode the mouse moves but its cursor isn't drawn. KWin puts the cursor on a hardware
plane, which the headset's view doesn't show. `KWIN_FORCE_SW_CURSOR=1` makes KWin draw it into the
frame itself. The fix comes from Cas and Chary XR's
[Steam Frame: 10 Things To Do FIRST](https://www.youtube.com/watch?v=jtW2mQd5qYI), credited
there to ThrillSeeker.

systemd reads `~/.config/environment.d` at login. `setup.sh` copies the file there; reboot
afterwards. `env | grep KWIN` in a Desktop Mode Konsole confirms it. To undo it, delete
`~/.config/environment.d/90-kwin-software-cursor.conf` and reboot.

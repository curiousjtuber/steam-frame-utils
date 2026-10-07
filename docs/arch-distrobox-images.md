# Arch-based distrobox images for arm64

SteamOS is Arch-based, so a distrobox on the same base would share the Frame's package versions and
library ABI: a binary built or installed in it is the host's own kind of build, and pacman and the
AUR work as on any Arch. The `ubuntu` box exists because, when the Frame was set up, no Arch-based
arm64 image looked solid enough to build on. This is a memo of what is out there, checked against
the registries on 2026-10-03, build dates re-read on 2026-10-06.

## Images

| Image | arm64 | Notes |
|---|---|---|
| `registry.gitlab.steamos.cloud/holo/holo-core-aarch64-preview/base-devel:latest` | yes, and amd64 | Valve's own build of Arch for aarch64: "holo" is SteamOS's Arch base, and this is the preview of its arm64 port, so it is the same package base as the Frame (glibc 2.39). Its repos are a trimmed subset of Arch's. It has worked as a box, created with `--platform linux/arm64` (below). A preview tag, with no promise of upkeep |
| `docker.io/lopsided/archlinux` (`latest`, `devel`) | yes | The official `archlinux-docker` tooling rebuilt as a multi-arch image, with Arch Linux ARM packages for arm64; `devel` is `base-devel`. One maintainer, and both tags were last built 2025-12-13, so the first `pacman -Syu` is a ten-month jump |
| `docker.io/menci/archlinuxarm` (`base`, `base-devel`) | yes | Arch Linux ARM images; the manifest also lists amd64 and riscv64. One maintainer, but rebuilt daily: `latest`/`base` and `base-devel` carry dated tags (`base-20261006`) and were built within a day of checking |
| `docker.io/manjarolinux/base` | yes | Manjaro, not Arch: its own repos, which lag Arch's, and an ARM edition of uncertain upkeep |
| `docker.io/library/archlinux` | no | x86_64 only: official Arch supports no other architecture |
| `quay.io/toolbx/arch-toolbox` | no | x86_64 only, for the same reason |

The arm64 column is what `skopeo inspect --raw` listed in each manifest. Valve's glibc version is
from having used the image, not re-checked.

## Using one

```bash
distrobox create --name arch --image docker.io/lopsided/archlinux:latest
```

The first `distrobox enter` runs `distrobox-init`, which installs distrobox's own dependencies with
pacman; the toolbx images (`quay.io/toolbx/*`) come with those already, which is why the `ubuntu`
box starts faster the first time.

**On the Frame the first enter of an Arch Linux ARM box fails** with `restricting filesystem
access failed because Landlock is not supported by the kernel`. pacman 7 runs its downloads in a
Landlock sandbox and the Frame kernel is built without it (`CONFIG_SECURITY_LANDLOCK is not set` in
`/proc/config.gz`). pacman 7.0 falls back silently, which is why the holo box (pacman 7.0.0, Valve's
build) came up without trouble; ALARM's pacman 7.1.0 treats it as fatal, so `distrobox-init`'s
`pacman -Syy` dies and the container exits before it can be entered. Turn the sandbox off in the
stopped container's `pacman.conf`, then enter again:

```bash
podman unshare sh -c 'm=$(podman mount arch) && sed -i "s/^#DisableSandbox/DisableSandbox/" "$m/etc/pacman.conf"; podman umount arch'
distrobox enter arch
```

The prefix match covers both spellings: `lopsided` ships `#DisableSandbox`, `menci` the newer split
`#DisableSandboxFilesystem` / `#DisableSandboxSyscalls`, of which only the filesystem one is the
Landlock half. Checked 2026-10-06 on kernel 6.18.0 with both images at pacman 7.1.0. Valve's image was created with the platform named, since its
manifest has amd64 too:

```bash
distrobox create --platform linux/arm64 --name holo \
  --image registry.gitlab.steamos.cloud/holo/holo-core-aarch64-preview/base-devel:latest
```

Things to keep in mind:

- **Arch Linux ARM is its own project,** with its own keyring, mirrors and build servers, a little
  behind Arch. Its packages run on the Frame unchanged where their libraries are SteamOS's: waypipe,
  for one, needs only libc, libgcc, lz4 and zstd, and its ALARM build runs on the Frame.
- **Valve's repos are small.** `/etc/pacman.conf` on the Frame points at them, and their `extra`
  database is about 560 KB against Arch's 8 MB or so. Packages missing there (waypipe, for one)
  are missing in Valve's image too; it is the base to build against the Frame's exact libraries,
  not a bigger package source.
- **AUR builds** work natively on arm64 inside such a box when the PKGBUILD allows `aarch64` or
  `any`. Anything built against the box's glibc has to run on the host's: the Frame is on 2.39.
- **Two of the three usable images are one-person projects.** For something that has to keep
  working across SteamOS updates, that is the risk to weigh against the closer match to the host.

## A phantom row in `distrobox list`

Not an Arch matter, but met while comparing these boxes. With the `ubuntu` box present,
`distrobox list` shows a garbage row whose ID is ` org.opencon`, and `distrobox upgrade --all`,
which reads that list, then stops at `Error: no such container ... Create it now? [Y/n]`.
`distrobox-list` asks podman for one line per container ending in `{{.Labels}}{{.Mounts}}` and
splits on newlines; the ubuntu-toolbox image's `org.opencontainers.image.description` label is
several lines long, so the row breaks apart and the last piece, which mentions
`/usr/bin/distrobox-host-exec`, passes the "is this a distrobox" check. Upstream issue 2084, open
PR 2227, not in 1.8.2.5, the release `setup.sh` installs.

The fix is PR 2227's one-liner, applied to the Frame's copy on 2026-10-06 with the original kept as
`distrobox-list.orig-1.8.2.5`:

```bash
sed -i 's/{{.Status}}|{{.Labels}}{{.Mounts}}/{{.Status}}|{{.Labels.manager}}{{.Mounts}}/' ~/.local/bin/distrobox-list
```

It prints only the `manager` label, which distrobox sets to `distrobox` on every box it creates, so
a multi-line label can no longer reach the parser. A distrobox reinstall overwrites it; drop the
patch once a release past 1.8.2.5 carries the fix.

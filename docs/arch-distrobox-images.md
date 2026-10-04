# Arch-based distrobox images for the Frame

Notes from looking into an Arch-based distrobox as a source of packages for the Frame, prompted by
waypipe: SteamOS is Arch-based, so a box with Arch's libraries would match the host more closely
than the `ubuntu` box does, and a binary copied out of it would be the same build an Arch system
runs. The outcome: no such box is worth having for that. `setup.sh --waypipe=arch` downloads
Arch Linux ARM's package directly instead (see [the README](../README.md#the-waypipe-function)).

## What was found

| Image | arm64 | Notes |
|---|---|---|
| `registry.gitlab.steamos.cloud/holo/holo-core-aarch64-preview/base-devel:latest` | yes (and amd64) | Valve's own Arch-based image, the same package base as the Frame (glibc 2.39). It worked as a box before, created with `--platform linux/arm64` (see `notes/hist-holo.log`). Valve's repos are a trimmed subset of Arch's, with no waypipe, so it would help only to build Arch's PKGBUILD, which needs a Rust toolchain |
| `docker.io/lopsided/archlinux` (`latest`, `devel`) | yes | Multi-arch build of the official `archlinux-docker` tooling, with Arch Linux ARM for arm64. One maintainer |
| `docker.io/menci/archlinuxarm` (`base`, `base-devel`) | yes | Arch Linux ARM images; the manifest also lists amd64 and riscv64. One maintainer |
| `docker.io/manjarolinux/base` | yes | A different distro, with packages that lag Arch's and an ARM port of uncertain upkeep. Not worth it here |
| `docker.io/library/archlinux` | no | x86_64 only; official Arch supports no other architecture |
| `quay.io/toolbx/arch-toolbox` | no | x86_64 only, for the same reason |

In either Arch Linux ARM image, `pacman -S waypipe` installs the very package that
`install-waypipe.sh` downloads, so a box adds a 1 GB image and a container to keep up to date, and
nothing else. Valve's image can't install it at all.

The architectures above were read from the registries' manifests on 2026-10-03, with
`skopeo inspect --raw`. The glibc version of Valve's image is from having used it, not re-checked.

## Where that leaves things

- **waypipe:** `--waypipe=arch` fetches Arch Linux ARM's package; `--waypipe=box` copies Ubuntu's
  from the `ubuntu` box. Both binaries need only libc, libgcc, lz4 and zstd, which SteamOS has.
- **Other Arch packages on the Frame:** the same direct download works for anything with as few
  dependencies as waypipe, and Valve's trimmed repos on the Frame itself (`/etc/pacman.conf`
  points at them, but there is no local sync database) are not a source for such packages.
- **An Arch box for building:** Valve's `base-devel` image is the one that matches the Frame's
  libraries, if a PKGBUILD ever needs building against them.

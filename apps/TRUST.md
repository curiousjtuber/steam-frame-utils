# How far to trust the apps

What each installer in `apps/` verifies, who is trusted at the root, and what
the app gets on the headset. Checked on 2026-10-15 against the installers in
this folder and the upstream sources they fetch from. The ranking is by what
would catch a tampered download, strongest first.

| App | Root of trust | What's checked | Sandbox |
|---|---|---|---|
| KRdp's server | KDE and FreeRDP's release tarballs, your own review of the manifest and patches | every source pinned by sha256 in the manifest; patches in this repo; built on KDE's SDK from Flathub | flatpak |
| Moonlight, KRDC, Deskflow | Flathub's GPG key, fetched once over HTTPS | every commit's signature, by flatpak | flatpak |
| Stream Frame | Boxtree's GPG key, fetched once over HTTPS from streamframe.app | every commit's signature, by flatpak | flatpak |
| Frametop | GitHub's TLS and the Frametop organization's account | the release zip against a sha256 recorded in the installer, then the image inside it against the zip's own metadata | podman container plus host services; two optional root parts |
| Full Keyboard | GitHub's TLS and TaiKeid's account | the archive against the release's own `SHA256SUMS` | none: `install.sh` from the archive runs in the home directory |
| BSManager | GitHub's TLS and DaVarga's account, continuously | nothing | none: an AppImage that updates itself |

Everything is in the open. The installers are in this repo to read, the
flatpaks have public manifests, and the GitHub apps have public source. What
differs is whether anything stands between a changed upstream artifact and
your headset.

## KRdp's server

`install-krdp.sh` builds from `apps/krdp/io.github.curiousjtuber.Krdp.yml`.
Every source is a release tarball from download.kde.org or GitHub with its
sha256 in the manifest, and the two patches live in this repo. The build runs
on KDE's SDK pulled from Flathub by flatpak-builder. A changed tarball fails
the build instead of installing. The CI bundle built on GitHub's arm64 runner
carries an attestation as well. The sandbox holds the network, the GPU,
flatpak's Wayland socket, PipeWire and `~/.config/krdpd` read-only.

## Moonlight, KRDC and Deskflow

The remote is added from Flathub's `.flatpakrepo` file over HTTPS. That file
carries Flathub's GPG key, and flatpak checks every commit it pulls against
it. Flathub builds from public manifests with a review step. The trust is
Flathub's signing key, the first HTTPS fetch of it, and the upstream project.
`flatpak info --show-permissions APP` shows what each sandbox reaches.

## Stream Frame

The same mechanism, but the remote is Boxtree's own at streamframe.app, so
the key and every build come from one vendor with no third party's review.
The trust is the first HTTPS fetch of their repo file and then Boxtree
outright. Flatpak's sandbox still applies.

## Frametop

`install-frametop.sh` takes Frametop's release route, not its `curl | bash`
one. Release 0.2.2 was checked end to end on 2026-10-15; this is what was
found.

**The release artifact is coherent.** The zip's sha256 matches GitHub's
server-computed asset digest, the release's `SHA256SUMS` and the FrameDrop
manifest. The `frametop-image.tar` inside matches the sha256 in
`frametop-release.json`, and the OCI config digest matches the recorded image
ID. The zip's four scripts (`install-release.sh`, `frametop-install.sh`,
`progress.py`, `askpass`) are byte-identical to the tagged commit `24a86dc`,
and so is the whole source tree in the image's `/src/frametop`, with only the
`build/` outputs added. The installer's recorded sha256 is that zip.

**The build is pinned and meant to be reproducible.** The release workflow
runs only on `v*` tags, with every GitHub Action pinned to a commit SHA. The
Containerfile pins the Fedora toolbox base image by digest, Python packages
by `uv.lock`, OpenVR to a tagged release with checked hashes, and distrobox to
a commit. The Fedora packages dnf installs are the one input that isn't
pinned. The zip is built with fixed timestamps so the same inputs give the
same file. Nobody outside the project has reproduced it yet.

**Nothing is signed.** The commits and the v0.2.2 tag are unsigned. The
release is drafted by the Actions bot and published by a person. There is no
build-provenance attestation. The root of trust is GitHub's TLS plus control
of the Frametop organization, which is one person's project: DeeJanuz wrote
about nine tenths of the commits, the organization was created on 2026-10-08,
and the repository moved into it the day after. The recorded sha256 in the
installer turns that into "the artifact that was checked" rather than
"whatever the account publishes next"; `--version` gives that up and says so.

**The build runs on a third party's machines.** Depot's arm64 runners, not
GitHub-hosted ones. Depot can see the build and could in principle alter it.
Reproducibility is the counter, once someone reproduces it.

**It gets a lot of the headset.** A SteamVR driver loaded into vrserver,
user services for the input relay, pointer and power, a container made from
the image through distrobox with the usual host access, and the desktop
session. Two optional parts need root and are offered, not forced: the eye
tracker's frame grabber, installed as a root service under `/etc/frametop`,
and the Bluetooth fixes under `/etc/steamframe`. Both are kept through
SteamOS updates by `/etc/atomic-update.conf.d` entries. Hand tracking, when
turned on, gives its camera broker `cap_sys_ptrace`, `cap_perfmon` and
`cap_dac_read_search`. `--no-eye-tracker` and `--no-bluetooth` refuse the
root parts.

**What leaves the headset.** Nothing phones home. The outbound calls in the
tree are the release downloads, the fetch of `pack/steamos.json` from the
repository's main branch at install time (data only, parsed and used to say
tested, untested or broken; the zip's copy serves offline, and
`FRAMETOP_STEAMOS_TABLE=none` turns the fetch off), and the Hand Recorder's
upload of hand recordings to a Hugging Face dataset, which asks for consent
and a login first and is not part of the stable release.

**Frametop's own route is weaker.** The one-liner pipes `get.sh` from GitHub
Pages into bash, clones a branch head, and builds on the headset in a Fedora
container that pulls unpinned packages; the project's own `pack/README.md`
calls that recipe the weak point. The release route is the maintainer's
answer to it, and this installer adds the pin.

## Full Keyboard

`install-full-keyboard.sh` checks the archive against the release's
`SHA256SUMS`, but that file comes from the same release, so it only catches a
corrupt or truncated download. Whoever can replace the archive can replace
the sums. The archive's `install.sh` then runs unsandboxed in the home
directory. The trust is GitHub's TLS and TaiKeid's account.

## BSManager

`install-bsmanager.sh` fetches whatever `releases/latest` points at and runs
it, unpinned and unchecked: curl-pipe-bash with an extra step. That script
fetches an AppImage, which runs unsandboxed and then updates itself from the
fork's releases. The trust is GitHub's TLS and DaVarga's account, for every
later update too, with no way to tell a replaced release from a new one.

## What would raise the floor

- A recorded sha256 in `install-bsmanager.sh` for a pinned release, and one
  in `install-full-keyboard.sh` beside the release's own sums, so a replaced
  release fails there as it does for Frametop.
- Upstream, for Frametop: signed tags, GitHub's build-provenance attestation
  on the release, and an independent reproduction of the zip.

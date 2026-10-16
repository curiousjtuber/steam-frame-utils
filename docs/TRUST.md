# How far to trust what setup.sh installs

What `setup.sh` and the top-level installers fetch, who is trusted at the
root, and what would catch a changed download. Checked on 2026-10-15 against
the scripts in this repo. The apps in `apps/` have their own page,
[apps/TRUST.md](../apps/TRUST.md), with the same ranking. ALARM below is Arch
Linux ARM, the ARM port of Arch with its own repositories and signing keys,
and the nearest source of aarch64 binaries for SteamOS.

| What | Root of trust | What's checked | Where it runs |
|---|---|---|---|
| `pkgbuilds/` (`--packages`, `--emacs=host`) | gnu.org and gitlab.archlinux.org release tarballs, your review of the PKGBUILD | BLAKE2 sums in the PKGBUILD, by makepkg | built on the host, under `~/.local`, no root |
| waypipe for the host (`--waypipe=host`) | ALARM's Build System key, pinned by fingerprint in `pacman-home` | the package's PGP signature, by pacman; the keyring package itself once, against the pinned fingerprint | a binary under `~/.local/bin` |
| Tailscale (`install-tailscale.sh`) | pkgs.tailscale.com, Tailscale | the tarball against the `.sha256` beside it | root: a system daemon |
| Nerd Fonts (`install-nerd-fonts.sh`) | GitHub's TLS, the nerd-fonts project | the archive against the release's `SHA-256.txt` | fonts under `~/.local/share/fonts`, data not code |
| arch distrobox (`--arch`, `--emacs=box`, `--waypipe=box`) | Docker Hub's TLS, one maintainer's image | nothing at the pull; ALARM's signatures for every package installed inside | a container with the usual distrobox host access |
| Homebrew packages (`--brew`, `--zsh`) | Homebrew's git repo and bottles | each bottle against the sha256 in its formula | `/home/linuxbrew`, no root |
| distrobox, mise, Homebrew's installer | GitHub's TLS, mise.run, each project's account | nothing: `curl \| sh`, unpinned | `~/.local`, `/home/linuxbrew` |

Nothing runs as root except Tailscale and the one-time creation of
`/home/linuxbrew`. The common root of trust is TLS to GitHub, Docker Hub,
gnu.org, pkgs.tailscale.com and one ALARM mirror, plus each project's own
account.

## The pkgbuilds

Emacs and pacman come from gnu.org and gitlab.archlinux.org as release
tarballs with BLAKE2 sums in the PKGBUILD, so a changed tarball fails
makepkg. They build on the host against its own libraries and install under
`~/.local` with `pacman-home -U`, no root. `homeify` fetches Arch's or the
AUR's PKGBUILD and prints the rewrite for review before anything builds, so
a person is in the loop. This is the same tier as KRdp's server in `apps/`.

## Tailscale and Nerd Fonts

Both download a release and check it against a sha256 published beside it.
That catches a corrupt download, not a replaced release, since the sum comes
from the same place. Tailscale's tarball comes from pkgs.tailscale.com and
installs as a root system daemon, so the trust is Tailscale's TLS and
Tailscale itself. Nerd Fonts are data rather than code and stay in the home
directory, so the stakes are low.

## The arch distrobox

The image is `docker.io/menci/archlinuxarm:latest`: one maintainer's
unofficial build of ALARM, pulled by a floating tag with no digest pin, for
the reasons in [arch-distrobox-images.md](arch-distrobox-images.md). Once
the box is up, pacman inside it checks ALARM's signatures as usual, so what
it installs afterwards, emacs-wayland and waypipe included, is as trustworthy
as ALARM. The weak moment is the first pull. A digest in `setup.sh` instead
of `latest` would pin it, at the cost of bumping it by hand.

## Homebrew

Bottles are checked against the sha256 in each formula, and formulae come
from Homebrew's git repository, so a package is as trustworthy as Homebrew.
The installer itself is `curl | bash` of `HEAD` of Homebrew's install
repository, unpinned, run once.

## waypipe for the host

`install-waypipe.sh` goes through `pacman-home relocate`, which takes ALARM's
package only with a valid signature (`SigLevel = Required`). The keys come
from ALARM's `archlinuxarm-keyring` package, fetched once with signatures
off, since there is nothing to check it with yet; what stands in for that is
the fingerprint of ALARM's Build System key, recorded in `pacman-home` and
checked against archlinuxarm.org on 2026-10-15, which a keyring that trusts
other keys fails. From then on a mirror can only serve what that key signed:
on the Frame, a package with one byte changed was refused on its signature.
ALARM's databases aren't signed, so which versions exist is still the
mirror's word, as with every pacman. Until 2026-10-15 this route ran with
`SigLevel = Never` and the database's checksum alone.

## distrobox and mise

Both are `curl | sh` with nothing pinned. distrobox's install script is
fetched from the `main` branch of its GitHub repository, so what runs changes
with every upstream commit; Frametop, by contrast, pins distrobox to a
commit. mise comes from mise.run, and `mise use -g rust` then pulls the Rust
toolchain through mise, trusting mise's own download checks. Both install
only into the home directory, which limits the blast radius, but it is the
same pattern BSManager is marked weakest for in `apps/`.

## What would raise the floor

- A pinned release and recorded sha256 for distrobox's installer, as
  Frametop does, and the same for mise.
- A digest for the arch image.

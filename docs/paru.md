# paru on the home database: tried and dropped

paru, the AUR helper, was built for `~/.local` on 2026-10-07 and removed the same day. It did
what was asked of it; the question turned out to be whether anything was left for it to do once
`pacman-home` had grown, and the answer was no. This memo keeps what the detour established.

## What it was for

Two wishes drove it. A `-Q` that answered from the home database by default, which pacman itself
can't do: pacman reads one configuration, `/etc/pacman.conf` or `--config`, and has no per-user
override. And installing home packages by name, `paru -S emacs-wayland`, with the AUR searchable
from the same tool.

## What worked

- **paru's configuration does what pacman's cannot.** `~/.config/paru/paru.conf` is per-user, and
  its `PacmanConf` line points paru's libalpm at any pacman.conf, so `paru -Q`, `-Qi` and `-Qo`
  read the home database with no option. Its `[bin] Sudo` line takes any command, and `fakeroot`
  there made `paru -U` install through fakeroot exactly as pacman-home does, files owned by the
  user. `Pacman = pacman-home` put the prefix check and the dependency translation in paru's
  install path too. Verified on the PC and the Frame.
- **A current libalpm was needed, and was worth having anyway.** paru 2.1 links libalpm.so.16;
  the host's pacman 6.1 has .so.14, and the last paru release linking .so.14 was eighteen months
  old. That is what brought `pkgbuilds/pacman`: pacman 7 built for the prefix, whose compiled-in
  defaults are pacman-home's paths, which skips the ldconfig run that fails on the read-only
  root, and which reads no system hooks. pacman-home runs it now, and it stays.
- **The two homeify rules for Rust** came from paru's PKGBUILD: the rpath in `RUSTFLAGS`, since
  rustc ignores `LDFLAGS`, and a makedepends that mise's shims provide unlisted, since makepkg
  checks dependencies against the host's packages. They stay for the next Rust package.
- **fakeroot refuses to nest.** paru running `fakeroot pacman-home`, and pacman-home then running
  `fakeroot pacman`, failed with "nested operation not yet supported" (fakeroot 1.34). The guard,
  skipping the inner fakeroot when `FAKEROOTKEY` is set, went with paru; it is one line if
  another caller ever needs it.

## What made it redundant

- **Installing by name needs a repository.** pacman and paru install from sync databases, so
  `-S` wanted a repo-add database of the home packages under `~/.local`. It was built, verified
  (`paru -S waypipe`, `paru -Syu`), and dropped: with four self-built packages the file to
  install is already in front of you, `-U` of it is the same one command, and the repository was
  a second copy of every build with no pruner of its own.
- **Building AUR packages produces `/usr` packages.** paru resolves a PKGBUILD's dependencies
  against the libalpm handle, which sees only the home database, so it stops before makepkg on
  anything that depends on host packages, emacs for one. And a build that got through would be
  for `/usr`, which pacman-home refuses. homeify has to run first either way, and homeify now
  fetches from the AUR itself.
- **Update checks moved into pacman-home.** `pacman-home outdated` compares with Arch Linux
  ARM's databases and asks the AUR's RPC for what they lack, which was `paru -Qua`'s job.
- **Querying was never paru's alone.** `pacman-home -Q` reads the same database.

What remained was `paru -Ss` and `-Si`, AUR search from the shell, against a Rust build on every
bump, the only package here that needed cargo, a config file outside the prefix, and a special
case in pacman-home. Not a trade worth keeping.

## If it comes back

Everything needed is recorded: `pkgbuilds/homeify paru` regenerates the PKGBUILD from the AUR
with no hand edit; `setup.sh --mise` provides cargo; the three config lines are `PacmanConf =
~/.local/etc/pacman.conf` (absolute), `Sudo = fakeroot` and `Pacman = <path to pacman-home>`
under `[bin]`; and pacman-home needs its fakeroot skipped when `FAKEROOTKEY` is already set.

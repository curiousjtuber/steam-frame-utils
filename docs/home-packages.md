# Packages under `~/.local`: what each one took

A record of every package put under `~/.local` on the Frame through `pacman-home`, by how much
work it needed: relocated as a binary, built from `homeify`'s output as it came, or built after
edits. The decision order itself is in the README ([Which way
in](../README.md#which-way-in)); this is the evidence behind it, kept so that the next package
can be placed by resemblance. Dates are 2026-10-07 unless said otherwise, on SteamOS 0.4.5.

| Package | Way in | Why that way | What it took |
|---|---|---|---|
| waypipe 0.11.2 | relocated, from Arch Linux ARM's package | one binary and a man page; needs only libc, lz4 and zstd, all on the host; no data files | nothing: `pacman-home relocate waypipe` |
| jq 1.8.2 | homeify as it came (a test build on the PC, not installed on the Frame) | autotools with `--prefix`, a license file under `$pkgdir/usr` | nothing: the prefix rewrite covered both |
| paru 2.1.0 (dropped the same day; [paru.md](paru.md)) | homeify as it came, from the AUR | cargo build, installs into `$pkgdir/usr` | nothing since homeify learned two Rust rules (the rpath in `RUSTFLAGS`, cargo unlisted as a makedepends because it comes from mise); before that, those two edits by hand |
| pacman 7.1.0 | homeify's kind of rewrite, then edits; written by hand from the release tarball | meson with `--prefix`, but a layout to decide and host files to avoid | documentation off (no asciidoc or doxygen on the host); programs under `lib/pacman/bin` so `pacman` on PATH stays the host's; ldconfig pointed at a path that doesn't exist; `pacman.conf` and `makepkg.conf` dropped; bash completions moved under the prefix, since meson takes their directory from the system's `bash-completion.pc` |
| emacs 31.1 | edits throughout; written by hand from Arch's `emacs-wayland` variant | a split PKGBUILD upstream, and features the host can't support | one variant kept (PGTK); native compilation off (no libgccjit on the host); tree-sitter off (not on the host); launcher `Exec` lines rewritten to absolute paths, since emacs's install does that only for emacsclient and the session's PATH is `/usr/local/bin:/usr/bin`; Arch's name and `provides=(emacs)` kept so `pacman-home -Q emacs` answers |

Checked and not taken, same day:

| Package | Why relocation fails | Why a build isn't worth it |
|---|---|---|
| krdc 26.08.1 | built against Qt 6.11 where the host has 6.8.0 (`version Qt_6.11 not found` on the binary and every plugin); needs qtkeychain and libvncclient, neither on the host; its VNC and RDP backends are Qt plugins under `lib/qt6/plugins/krdc`, which a relocated tree isn't searched for | a KDE application against the host's KDE Frameworks, which a 26.08 release is likely to find too old; the flatpak carries its own Qt and frameworks |
| moonlight-qt 6.2.0 | the same Qt 6.11 against 6.8.0, and ffmpeg 8's libraries (`libavcodec.so.63`, `libavutil.so.61`, `libswscale.so.10`) and libplacebo where the host has ffmpeg 7 and none of the last | buildable against the host's Qt and ffmpeg 7 in principle, but the flatpak already works and brings its own codecs |

The pattern: a Qt application from Arch Linux ARM is built against whatever Qt Arch ships that
week, and Qt's symbol versioning (`Qt_6.11`) makes a newer build refuse an older host library
outright. SteamOS pins its Qt to the Plasma it ships. For anything Qt, the host's version decides,
and a flatpak is the answer unless the program is small enough to build against the host's Qt.
`pacman-home relocate` refuses both on its library check, and did when tried on the Frame, with
the Qt line named on moonlight's binary and on krdc's binary and every plugin. The plugin
problem it would not have seen.

That refusal is the fix the two packages prompted. Until then the library check was a warning,
and it ran ldd with stderr discarded, which is where the loader names a symbol version the host's
library lacks. So relocate would have warned about ffmpeg's libraries, said nothing about Qt,
found every dependency satisfied by name, and installed a moonlight that cannot start; krdc would
have stopped later, at pacman's dependency check for qtkeychain, for the wrong reason. The check
now allows the package's own library directories, which will exist under `~/.local/lib`, captures
what the loader says, and refuses; `--allow-missing-libs` is the override.

## What separated the three groups

**Relocation works when the program is self-contained.** The check relocate runs is about where
files land: nothing outside `/usr`, nothing in the parts of `/usr` that only work from there, no
install scriptlet, no library the host lacks. What it cannot check is where the program looks at
run time. waypipe looks nowhere; a program with data files, plugins, GSettings schemas or Python
modules compiled to look under `/usr/share` or `/usr/lib` installs cleanly and then misbehaves.
Run the program after relocating; that is the second half of the test.

**homeify as it came works when the build system takes a prefix and nothing else assumes
`/usr`.** jq and paru are that. The rewrite covers configure, cmake, meson (and `arch-meson`) and
make prefixes, sysconfdir and localstatedir, `*dir=` flags naming `/usr`, `/usr`, `/etc`, `/var`
and `/opt` under `$pkgdir` and in `backup=`, the `arch` array, and the rpath and pkg-config path
for `~/.local/lib`. Rust needed two more rules, now in homeify: rustc ignores `LDFLAGS`, and
makepkg's dependency check sees host packages only, not mise's shims. Each new language or build
system may want one such rule; a rule beats a hand edit when it will recur.

**Edits were needed for two kinds of reasons, and two signals pointed at them.**

- *The host lacks a feature's library.* homeify ends by listing the `makedepends` and `depends`
  the host doesn't have. For emacs that was libgccjit and tree-sitter, and the answer was to
  configure those features off rather than build the libraries into `~/.local`: libgccjit is a
  gcc build, and tree-sitter would also have meant carrying Arch's compatibility patches. The
  same list for pacman named asciidoc and doxygen, which only build documentation.
- *A file lands outside the prefix.* `pacman-home -U` refuses the package and names the files.
  For pacman that was the bash completions, which meson places by the system's
  `bash-completion.pc`; the fix is a move in `package()`. This is the check that makes a
  homeify rewrite safe to trust, since a build system that hardcodes `/usr` shows up here.
- *Beyond the two signals*, pacman needed a layout decision (not on PATH as `pacman`) and emacs
  a run-time one (the launchers), found only by installing and using the result. Those are the
  decisions the PKGBUILD header records.

## Things learned along the way

- **A refusal is worth more than a warning when the failure is at run time.** The library check
  started as a warning, on the thought that a package shipping its own libraries would otherwise
  be refused for them. The right fix was to let the package's library directories count as
  supplied and then refuse, since the only thing a warning bought was a program installed that
  cannot start. The same goes for anything checked before a run: if the check can be exact,
  make it stop.
- **Host builds don't run in the distroboxes.** The home directory is shared, so `~/.local/bin`
  is on a box's PATH too, but the binaries were linked against the host's `/usr/lib` and carry
  an rpath only for `~/.local/lib`. In the arch box emacs fails to load (gtk3 and 18 more
  libraries gone from the box) and paru fails on gpgme, whose soname differs between the host's
  release and Arch's; waypipe runs because every box has libc, lz4 and zstd under the same
  names. The binaries are fine; they are host programs on a foreign PATH. The remedy, if wanted,
  is the pattern pacman-home itself uses: inside a container, re-exec on the host through
  `distrobox-host-exec`.
- **A relocated package can still be stale in a way pacman doesn't see.** relocate rebuilds the
  mtree, so `pacman-home -Qkk` is clean, but the program's own version check (waypipe's remote
  end, say) is what notices an update; `install-waypipe.sh` compares with the mirror.
- **Ownership.** Built packages record `root:root` (makepkg's fakeroot); relocated ones record
  the user, since bsdtar ran as the user. Under fakeroot both install owned by the user, and
  `pacman-home -Qkk` reports the first kind as UID and GID mismatches on every file. Expected.
- **`makepkg -R` repackages without rebuilding**, which made the three emacs repackages of the
  first day take seconds. Keep `src/` and `pkg/` while a PKGBUILD is being adjusted; they are
  about a gigabyte for the three packages, and `makepkg -c` or an `rm` clears them afterwards.

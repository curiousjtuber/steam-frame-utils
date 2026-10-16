# The desktop mouse cursor on SteamOS 0.5.6

What SteamOS 0.5.6 changed for the two cursor fixes `setup.sh` installs, the
software cursor (`environment.d/90-kwin-software-cursor.conf`) and the size
entry (`autostart/steam-frame-utils-cursor.desktop`), where Frametop's cursor
went instead, and how to re-check on the next SteamOS. The README's
[Mouse cursor in Desktop Mode](../README.md#mouse-cursor-in-desktop-mode)
section has the fixes themselves.

## What was found

Checked on 2026-10-16, SteamOS 0.5.6 beta (build 20261015.6141207), Frametop
`dev` at d61a4f6. Each case was tried in the headset after a reboot.

| | Stock Desktop Mode | Frametop desktop |
|---|---|---|
| Without `KWIN_FORCE_SW_CURSOR` | cursor drawn, size kept | no cursor |
| With it | cursor drawn, but 256 px until `cursor-size --apply` | cursor drawn |

So 0.5.6 fixed the stock desktop on its own: before it, KWin put the cursor on
a hardware plane the headset's view doesn't show, and the size came from
gamescope's `XCURSOR_SIZE=256` at every start. Frametop still shows no cursor
without the variable, although it starts the same
`/usr/bin/kwin_wayland_wrapper`; what differs is how (several outputs, its own
sizes, `--inputmethod`), and which of those matters isn't known. With the
variable, which `environment.d` gives both desktops, the stock desktop is back
to taking gamescope's size, so the size entry goes wherever the software cursor
does.

Nothing in the OS sets the variable, so the change is in KWin (kwin 6.2.5-3.1)
or gamescope (3.16.30), not in the launcher: `/usr/bin/steamos-nested-desktop`
(steamdeck-kde-presets 3.8.3-13) only sets a 1280x800 size, `SW_CURSOR` appears
nowhere under `/usr/bin`, `/usr/lib/steamos`, `/usr/lib/systemd`, `/usr/share`
or `/etc` but in GLFW's docs, and neither the 0.4.5 nor the 0.5.6 patch notes
mention the cursor.

## Where Frametop's cursor went

Since `environment.d` reaches both desktops, Frametop sets the variable itself:
its session script (`session/frametop-session.sh`, from `dev` 3843d1c) exports
`KWIN_FORCE_SW_CURSOR=1` before it starts Plasma, next to the cursor theme, so
only that session's KWin gets it. Its size is Frametop's own as well: the same
block exports `XCURSOR_SIZE` from Frametop's `kcminputrc` when one is set there.
So on 0.5.6 neither fix is needed from `setup.sh`, and the stock desktop keeps
its native cursor at the size System Settings has.

## What setup.sh does with it

`setup.sh` reads `VERSION_ID` from `/etc/os-release` (`/run/host/etc/os-release`
in a distrobox) and compares it with `CURSOR_FIXED_IN`, 0.5.6, through
`sort -V`.

| SteamOS | software cursor | size entry |
|---|---|---|
| below 0.5.6 | installed | installed |
| 0.5.6 and up | removed if it is ours | removed if it is ours |
| no `VERSION_ID` (`FORCE=1` off the Frame) | installed | installed |

A removed file is recognised first: the `environment.d` one by content, the
entry by its `Name=` line, so one rendered with an older checkout path goes
too. Anything else of the same name is left alone with a `skip`. The
`environment.d` change needs a reboot either way.

## Re-checking on a new SteamOS

`bin/frame-versions` gives the version. Then:

1. Open the stock desktop with no `~/.config/environment.d/90-kwin-software-cursor.conf`
   (`setup.sh` removes it on 0.5.6 and up; reboot after any change there): is
   the cursor drawn, and at the size System Settings has? If not, that SteamOS
   needs the fix again: raise `CURSOR_FIXED_IN` to a version above it.
2. Open the Frametop desktop with the `export KWIN_FORCE_SW_CURSOR=1` line in
   its session script commented out: if the cursor is drawn, the line can go.

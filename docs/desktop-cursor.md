# The desktop mouse cursor on SteamOS 0.5.6

What SteamOS 0.5.6 changed for the two cursor fixes `bin/sw-cursor` installs,
the software cursor (`environment.d/90-kwin-software-cursor.conf`) and the size
entry (`autostart/steam-frame-utils-cursor.desktop`), where Frametop's cursor
went instead, and why the software cursor stays the default. The README's
[Mouse cursor in Desktop Mode](../README.md#mouse-cursor-in-desktop-mode)
section has the fixes themselves.

## What was found

Checked on 2026-10-16, SteamOS 0.5.6 beta (build 20261015.6141207), Frametop
`dev` at d61a4f6. Each case was tried in the headset after a reboot.

| | Stock Desktop Mode | Frametop desktop |
|---|---|---|
| Without `KWIN_FORCE_SW_CURSOR` | cursor drawn, size kept | no cursor |
| With it | cursor drawn, but 256 px until `cursor-size --apply` | cursor drawn |

That looked like 0.5.6 fixing the stock desktop on its own, but it is half
right: the cursor it draws is the controller's mouse mode's, and a real mouse,
Deskflow's for one, still has none without the variable, since KWin puts that
one on a hardware plane the headset's view doesn't show (see
[Why the software cursor stays](#why-the-software-cursor-stays)). The size came
from gamescope's `XCURSOR_SIZE=256` at every start. Frametop still shows no
cursor without the variable, although it starts the same
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

## Why the software cursor stays

Checked again on 2026-10-21, SteamOS 0.5.6: what 0.5.6 draws without the
variable is the controller's mouse-mode cursor, gamescope's own. A pointer from
a real mouse goes to KWin, which still puts it on a hardware plane, so Deskflow
(a virtual mouse from another machine) and a USB or Bluetooth mouse show no
cursor. For 0.5.6 and later alike, `bin/sw-cursor` therefore keeps the
software cursor as its default, and with it the size entry, since with the
variable set the desktops take gamescope's 256 px again. A version check
(`CURSOR_FIXED_IN`, from `VERSION_ID`) was in for five days and is gone.

## What setup.sh does with it

`bin/sw-cursor` holds the policy; `setup.sh` runs `sw-cursor auto`, or offers
the software cursor when nothing is in place and the run is interactive.

| state of `~/.config/environment.d/90-kwin-software-cursor.conf` | `auto` |
|---|---|
| none | installs it, and the size entries |
| the default copy | kept |
| chosen with `sw-cursor on` or `off` | kept, the size entries with the choice |
| anything else | left alone with a `skip`; the entries too |

A choice is a file whose first line is `# steam-frame-utils: sw-cursor on`
or `off`, then `KWIN_FORCE_SW_CURSOR=1` or `=0`; `sw-cursor default` drops it.
A size entry of ours is known by its `Name=` line, so one rendered with an
older checkout path is replaced too. The `environment.d` change needs a reboot
either way: KWin reads the variable once, at its start (a function-local
static in kwin 6.2's `compositor_wayland.cpp`), so nothing switches it in a
running desktop.

## Re-checking on a new SteamOS

`bin/frame-versions` gives the version. Then:

1. Open the stock desktop without the software cursor (`sw-cursor off`, then
   a reboot) and move a real mouse, Deskflow's or a paired one, not the
   controller: is its cursor drawn, and at the size System Settings has? If it
   is, the default could become off again. `sw-cursor` with no argument says
   what the running desktop got.
2. Open the Frametop desktop with the `export KWIN_FORCE_SW_CURSOR=1` line in
   its session script commented out: if the cursor is drawn, the line can go.

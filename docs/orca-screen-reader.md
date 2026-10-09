# The screen reader that only says it's broken

If the Frame starts announcing, at every boot, that "this is the dummy output module" and "none
of its output modules is [working] except me", the screen reader is on, and the chord that turns
it on also turns it off: hold **Steam** and press **View (⧉)** on the Steam Controller. It
finishes the paragraph it is on before going quiet, so give it a few seconds before pressing
again.

If that doesn't take, or the chord should stop working altogether, this is the stop:

```bash
ssh steamos@frame.local 'systemctl --user mask orca.service && systemctl --user stop orca.service'
```

It takes effect at once and holds across reboots and SteamOS updates. To undo it:

```bash
ssh steamos@frame.local systemctl --user unmask orca.service
```

The rest of this memo is why that is the fix, found on SteamOS 0.4.5 (build 20261007) on
2026-10-08.

## What is speaking

Orca, the GNOME screen reader, shipped in the SteamOS image (`orca 48.6`). It speaks through
speech-dispatcher, which tries each of its output modules in turn and falls back on the `dummy`
module when none works. `dummy` has no voice: it plays a recorded message telling you to read
its log. That message is the voice heard; the paths it reads out are real, and the one that
exists on the Frame is `/run/user/1000/speech-dispatcher/log/`.

## Why no module works

The log there says why each one fails:

| Module | Log | Reason |
|---|---|---|
| `espeak-ng`, `espeak-ng-mbrola` | `libespeak-ng.so.1: cannot open shared object file` | the image has speech-dispatcher's eSpeak modules but not the `espeak-ng` package they load; `pacman -Q espeak-ng` finds nothing, and the library is nowhere under `/usr` |
| `festival` | `festival_client: connect to server failed` | Festival isn't installed either; the module expects a server on a socket |
| `dummy` | `Opening sound device failed ... Cannot open plugin server` | its own audio playback fails too, but it still speaks, so its message goes out some other way |

Speech-dispatcher then reports "started with 1 output module" — `dummy`. So the Frame's screen
reader cannot speak and never could; the missing library is Valve's packaging, not a user
setting, which is why an OS update changed nothing.

## Why it comes back after a reboot

The first instinct, `gsettings set org.gnome.desktop.a11y.applications screen-reader-enabled
false`, takes until the next boot. The journal shows who reverts it:

```
steamos-manager: Starting screenreader-setup
steamui_steamos: Set screen reader enabled: 1
systemd[user]:   Started Orca Screen Reader.
```

Steam carries its own copy of the setting, `"ScreenReaderEnabled" "1"` in
`~/.local/share/Steam/config/config.vdf`, and at startup writes it into GSettings, which starts
`orca.service`. The Frame's Steam UI has no Accessibility screen to turn it off from, and editing
`config.vdf` by hand is futile while Steam is running, since Steam rewrites the file from memory
when it exits.

## What turned it on

A controller chord. The Steam-button layout for the Steam Controller,
`~/.local/share/Steam/controller_base/chord_triton.vdf`, binds **Steam + View (⧉)** to
`sr_enable` (the vdf calls that input `button_menu`, and the other one `button_escape`). Steam's log (`logs/steamui_steamos.txt`) has the moment: `controller action - 48
(k_EControllerAction_ScreenReader_Enable)` at 21:58:02, `Set screen reader enabled: 1` a second
later, Orca's first run (the birth time of `~/.local/share/orca/`) the same second. With the
screen reader on, Steam swaps in `controller_base/screenreader.vdf`, where the same chord is
`sr_disable` and Steam + Menu (≡) is `sr_toggle_mode`; the log shows that one pressed next.
The occasion was a game that had crashed and was being prodded with whatever chords came to
hand, which is also why the web has so little on this: it takes an unlucky chord, not a menu.

That is the chord at the top of this memo. The mask is for when it isn't enough, or when nobody
wants the chord to work.

## Why the mask

`orca.service` is a static user unit (`/usr/lib/systemd/user/orca.service`): nothing enables it,
Steam just asks systemd to start it. Masking it, which links
`~/.config/systemd/user/orca.service` to `/dev/null`, makes that request a no-op, so Steam can
set its flag at every boot and nothing starts. The link is in the home directory, which the
immutable root and A/B updates leave alone. Verified: a reboot after masking came up silent.

## If a speaking screen reader is ever wanted

The missing piece is `espeak-ng`. Arch Linux ARM's package, relocated under `~/.local` by
`pacman-home` ([home-packages.md](home-packages.md)), would supply `libespeak-ng.so.1` and
`/usr/share/espeak-ng-data`; the modules would then need `LD_LIBRARY_PATH` and
`ESPEAK_DATA_PATH` set for the user session, through `~/.config/environment.d/`, and the mask
lifted. Not tried.

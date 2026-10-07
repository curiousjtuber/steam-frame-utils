# The proximity sensor, and the `frame-prox` tool that came and went

`bin/frame-prox` lived in this repo from 2026-10-02 to 2026-10-07, across SteamOS betas 0.4.3 to
0.4.5. It showed the Frame's proximity reading against the threshold SteamVR applies to it, and
set the one setting that moves that threshold. 0.4.4 put that setting in the VR Settings UI,
which made the tool redundant; this memo keeps what it found, since the way it was found is what
will be needed next time an undocumented knob matters.

## The sensor

A Vishay VCNL4040 behind the faceplate, driven by the kernel's `vcnl4000` IIO driver, tells
SteamVR whether the headset is worn. It reads as `in_proximity_raw` under
`/sys/bus/iio/devices/iio:device*`; higher is closer. SteamVR's `cv` driver
(`/opt/steamvr/drivers/cv/bin/linuxarm64/driver_cv.so`) polls that file itself, compares it with a
threshold, and reports the result as the HMD's `/proximity` input. Services hang off that state,
`steamvr-proxmicmute.service` for one, which mutes the microphone when the headset is off.

The kernel's own `in_proximity_nearlevel` and IIO threshold events are not involved; changing
them does nothing for SteamVR.

## Why the tool was written (0.4.3)

With SteamOS 0.4.3 the threshold sat just under one Frame's worn readings, and SteamVR kept
deciding the headset was off while it was on. The threshold came from two factory values in the
headset's EEPROM, `prox_far` and `prox_noise`, and two undocumented `driver_cv` settings,
`proxSensorThresholdMultipleConst` (default 1.4) and `proxSensorNoiseExponentConst` (0.85). On
that Frame, `prox_far` 17 and `prox_noise` 5 gave (17 − 5) × 1.4 = 16.8, against worn readings of
19.2 to 19.6 and about 4.5 with the headset off. Lowering the multiplier to 1.0 put the threshold
at 12 and fixed it. `frame-prox` printed those numbers, watched the reading live, and set the
multiplier through vrcmd.

## What 0.4.4 changed

Valve's notes said only that 0.4.4 "added user setting to control Presence Sensor Sensitivity".
Underneath, `driver_cv.so` dropped both old keys, the `prox_noise` read and the line that logged
the computed threshold, and read a new key, `steamvr.proxThresholdMode`: 0 for Normal, 1 for
High Sensitivity, anything else counting as 0. The threshold became `prox_far` × 0.8 (Normal) or
× 0.65 (High Sensitivity), with no hysteresis: on that Frame 13.6 or 11.05, both below the old
default. The UI for it is **VR Settings > Startup / Shutdown > Presence Sensor**, whose explainer
says high sensitivity "keeps displays on under a wider range of conditions, such as when using
glasses spacers". A multiplier set under 0.4.3 stays in `steamvr.vrsettings` and is ignored.

The tool stopped working with that update, since the log line it read was gone, and was rewritten
to follow the new key: `--set high` did what the UI does. 0.4.5 is the same as 0.4.4 here, checked
on 2026-10-07: the key is in `default.vrsettings`, the driver's strings name it, and the old keys
are gone from the driver.

## Why it was removed

Once the setting is in the UI, a shell command for it is a second way to do one thing, and the
rest of the tool, a reading and a threshold check, is a few commands. They are below, with the
numbers from the one Frame measured, so that a future "SteamVR loses me" can be checked without
rebuilding the tool.

## The sensor by hand

```bash
cat /sys/bus/iio/devices/iio:device*/in_proximity_raw
```

```bash
/usr/lib/deckard-eeprom/eeprom_console get prox_far
```

```bash
steamvr cmd --settings-int steamvr.proxThresholdMode
```

```bash
grep -F '[CHmdDirectDeviceControl] Proximity sensing' "$(steamvr logpath)/vrserver.txt" | tail -n1
```

The reading, the factory value the threshold is built on, the mode in force, and the driver's
startup line (`Proximity sensing enable: proxfar 17`, or `disabled (cannot read proxfar)`). The
threshold is `prox_far` × 0.8 or × 0.65 by mode; worn while the reading is above it. To watch:

```bash
while :; do cat /sys/bus/iio/devices/iio:device*/in_proximity_raw; sleep 0.3; done
```

To set the mode from a shell, with SteamVR running:

```bash
steamvr cmd --set-settings-int steamvr.proxThresholdMode 1
```

Readings are per headset and face: the measured Frame reads about 19.4 worn and 4.5 off, so
either mode has room; a Frame that reads lower worn, or a fit with glasses spacers, is what High
Sensitivity is for. `driver_cv.disableProxSensor` (`steamvr cmd --set-settings-bool
driver_cv.disableProxSensor true`) turns detection off altogether.

Use only `eeprom_console get`: its `reset`, `lock`, `unlock` and `upgrade` write the factory
EEPROM. It also holds `prox_noise`, `prox_near` and `prox_mid` (5, 564 and 91 on that Frame),
apparently factory readings at closer distances; the current driver uses none of them.

## Settings files, and why `--set` went through vrcmd

User settings live in `~/.config/openvr/config/steamvr.vrsettings`, where they outlast SteamVR
updates. Editing that file while SteamVR runs doesn't stick: vrserver writes back the settings
it holds in memory on its next change. `steamvr cmd --set-settings-<type> SECTION.KEY VALUE`
changes a setting in the running vrserver, which saves it, and the driver re-reads its settings
on every change. Reading goes the same way, `steamvr cmd --settings-<type> SECTION.KEY`,
defaults included. vrcmd can set a key but not remove one.

Removing a key, then, means editing the file while vrserver is down, and getting it down is the
trick. `systemctl --user stop steamvr.service` doesn't hold: the session answers with a new start
job within the same second, and systemd reports the stop as cancelled (seen on 0.4.5; the unit's
`Restart=always` is not the cause, since that applies to crashes, not to an explicit stop).
Valve's wrapper, `sudo steamvr stop`, holds it by stopping the whole display stack, sddm
included, and `sudo steamvr start` brings it all back. A runtime mask does the same for the one
service, without root and without touching the session:

```bash
systemctl --user mask --runtime steamvr.service && systemctl --user stop steamvr.service
```

```bash
jq 'del(.driver_cv.proxSensorThresholdMultipleConst) | if (.driver_cv // {}) == {} then del(.driver_cv) else . end' \
  ~/.config/openvr/config/steamvr.vrsettings > /tmp/steamvr.vrsettings && mv /tmp/steamvr.vrsettings ~/.config/openvr/config/steamvr.vrsettings
```

```bash
systemctl --user unmask --runtime steamvr.service && systemctl --user start steamvr.service
```

While masked, the session's start attempts fail and the service stays down; the mask lives in
`/run`, so a reboot clears it even if the unmask is forgotten. The gamescope session stays up
throughout, and SteamVR comes back in about ten seconds. That is how the stale
`driver_cv.proxSensorThresholdMultipleConst` 0.9 from 0.4.3 was removed from the measured Frame
on 2026-10-07: afterwards `steamvr cmd --settings-float driver_cv.proxSensorThresholdMultipleConst`
reported the default 1.4, and the Presence Sensor setting was untouched. Back the file up first;
the setting that matters, `steamvr.proxThresholdMode`, is in it.

## Finding an undocumented setting: what worked

None of this is in OpenVR's headers, which name the core keys only, nor in Valve's notes. The
sequence that found both generations of the setting:

- **The settings files.** `grep -ril --include='*.vrsettings' prox /opt/steamvr` finds a key
  with its default: in 0.4.3 the `driver_cv` keys in
  `drivers/frame_hmd/resources/frame_hmd_additional.vrsettings`, in 0.4.4 `proxThresholdMode` in
  `resources/settings/default.vrsettings`.
- **The UI's words.** `resources/webinterface/dashboard/localization/vrmonitor_english.json`
  holds the labels (`Settings_PresenceSensor_*`), and the dashboard's JavaScript maps them to the
  values (`Default=0`, `Sensitive=1`). That ties a menu item to a key without guessing.
- **Who reads the key.** `strings -t x` on the driver's `.so` shows the key names, the commands
  it runs (`eeprom_console get prox_far`, `vrdevice_path prox_sensor`, which prints the sensor's
  sysfs path) and the messages it logs. A key that is in a settings file but in no binary's
  strings is dead, which is how the 0.4.3 keys were found to be ignored after 0.4.4.
- **The log.** `vrserver.txt` under `steamvr logpath` carries what the driver chooses to log,
  which in 0.4.3 was the computed threshold itself. Change a setting with vrcmd and watch the
  line change: that is the proof a formula is right.
- **When it isn't logged.** 0.4.4 logged only `prox_far`, so the constants came from the
  disassembly (`llvm-objdump -d driver_cv.so`): find the code that references the log message's
  address, and a little before it, after the `sscanf("%f")` of the sensor file, the mode is
  compared with 1 and `prox_far` is multiplied by `0x3f4ccccd` (0.8) or `0x3f266666` (0.65) and
  compared with the reading. Float constants in hex are the thing to search for.
- **Expect churn.** Valve renamed the mechanism between two betas four days apart, without a
  note beyond one sentence, and left the old key in users' files. Anything built on such a key
  needs a cheap check that the key still exists (`strings` on the driver) and a plan to retire
  itself once the UI catches up, which is what happened here.

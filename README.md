# KDE Wayland Power Button Screen Toggle

Turn your PC's power button into an on/off switch for your monitors, for a desktop that stays on all the time.

- **One press:** all screens go dark, and moving the mouse or pressing keys does not wake them.
- **Another press:** the screens come back, with the keyboard and mouse working again.
- **Nothing else** turns the screens on or off, and the power button can no longer shut down or suspend the machine.

It sounds trivial. On KDE Plasma under Wayland it isn't, and I'd been trying to get this behaviour for years.

## Why the obvious approaches don't work

| Approach | What goes wrong |
|---|---|
| Plasma's power button action "Turn off screen" / "Toggle screen on/off" | It uses DPMS, and in KWin any mouse or keyboard input wakes the screens again. Bumping the desk turns them on. |
| `kscreen-doctor --dpms off` on a shortcut | Same DPMS, same wake-on-input. |
| Powering monitors off over DDC/CI (`ddcutil setvcp D6 04`) | Many monitors stop answering DDC once they're off, so you can't turn them back on from the PC. On my AOCs, the GPU reported the monitor as unplugged and I had to press its own power button. Some monitors don't do DDC/CI at all. |
| `kscreen-doctor output.X.disable` | KWin rearranges every window onto the remaining outputs, and turning all of them off is asking for trouble. |
| The `ddcci` kernel driver | Auto-probing of displays is gone since kernel 6.8, and it failed to probe my monitors anyway. |

## How this one works

`src/screen-toggle` is a small Python script, run as a systemd user service in your Plasma session. It uses `python3-evdev`.

1. It takes **exclusive hold of the ACPI "Power Button" input devices** (`EVIOCGRAB`). logind, PowerDevil and KWin never see the key, so the button can't shut down, suspend or open the logout dialog.
2. **When you press it to turn the screens off,** it first takes exclusive hold of every keyboard, mouse, touchpad and tablet, then calls `kscreen-doctor --dpms off`. Because KWin receives no input, nothing wakes the screens. Devices plugged in while the screens are off are picked up within 2 seconds.
3. **When you press it again,** it calls `kscreen-doctor --dpms on` and releases all the input devices.
4. It acts on key *release* with a 1-second debounce, so one press is one toggle.
5. **If the service stops or crashes,** the kernel releases its holds and the stop handler turns the screens back on, so you can't get locked out.

It works alongside [input-remapper](https://github.com/sezanzeb/input-remapper). Devices that input-remapper already holds can't be taken twice, but the script takes input-remapper's virtual output devices instead.

The power button itself still works as a power button in one way: holding it for about 4 seconds forces a hard power-off. The motherboard does that, and no operating system can change it.

## Remote control (Home Assistant, MQTT, scripts)

The service also takes signals, with exactly the same behaviour as the button (input grabbed while off):

```bash
systemctl --user kill --kill-whom=main -s SIGUSR1 screen-toggle   # screens off
systemctl --user kill --kill-whom=main -s SIGUSR2 screen-toggle   # screens on
cat ~/.local/state/screen-toggle/state                            # "on" or "off" ($XDG_STATE_HOME respected)
```

A signal that matches the current state does nothing, so these are idempotent. Use them instead of
`kscreen-doctor --dpms off` from another tool: a plain DPMS off is woken by any mouse movement, and it
leaves this service's idea of the state wrong. An MQTT bridge can publish the state file to get button
presses into Home Assistant (poll it every couple of seconds).

## Install

```bash
git clone https://github.com/danielrosehill/KDE-Wayland-Power-Button-Screen-Toggle
cd KDE-Wayland-Power-Button-Screen-Toggle
./install.sh
```

`install.sh` does the following:

- Installs `python3-evdev` if it's missing.
- Adds you to the `input` group if needed. You then have to log out and back in once.
- Installs a logind drop-in (`/etc/systemd/logind.conf.d/50-power-key-ignore.conf`) so the power, suspend and hibernate keys do nothing, including at the login screen.
- Sets Plasma's power button action to "do nothing", because the service handles it.
- Installs and enables the user service `screen-toggle.service`.

To remove everything and restore the defaults, run `./uninstall.sh`.

Useful commands:

```bash
systemctl --user status screen-toggle      # running? which devices it holds
journalctl --user -u screen-toggle -f      # "screens off, grabbed N" / "screens on"
systemctl --user stop screen-toggle        # emergency: screens on, all input released
```

If you want a desktop that is truly always on, also disable sleep, which this repo does not do:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Then set Plasma's screen dimming, screen-off timer and auto-suspend to "never" in System Settings → Power Management.

## Tested on

| | |
|---|---|
| OS | Ubuntu 26.04 LTS, kernel 7.0 |
| Desktop | KDE Plasma 6.6 on Wayland (KWin) |
| GPU | AMD Radeon RX 7700 XT |
| Board | MSI PRO B760M-A WIFI |
| Monitors | Three **AOC 2275W** 21.5-inch 1080p monitors. They're pretty old: one on DisplayPort, two on HDMI, and they're inconsistent about DDC/CI, which is why the DDC route was a dead end. |

The script doesn't depend on the monitors: it only uses KWin's DPMS, so any monitor that blanks on DPMS should work. It does need Plasma on Wayland, because `kscreen-doctor --dpms` is Wayland-only.

## Related

- [KScreen-Config-Scripts-And-Docs](https://github.com/danielrosehill/KScreen-Config-Scripts-And-Docs): saving multi-screen layouts and DPMS shortcuts in KScreen.

## License

MIT

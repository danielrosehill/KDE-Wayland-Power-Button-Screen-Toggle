#!/usr/bin/env bash
# Install the power-button screen toggle for the current user (KDE Plasma 6 on Wayland).
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user (it uses sudo where needed)."; exit 1; }

echo "== dependencies"
command -v kscreen-doctor >/dev/null || { echo "kscreen-doctor not found (package: kscreen / libkscreen-bin)"; exit 1; }
python3 -c 'import evdev' 2>/dev/null || sudo apt-get install -y python3-evdev

echo "== input group (read and grab /dev/input devices)"
if ! id -nG | tr ' ' '\n' | grep -qx input; then
  sudo usermod -aG input "$USER"; NEED_RELOGIN=1
fi

echo "== logind: power/suspend/hibernate keys do nothing"
sudo install -Dm644 systemd/50-power-key-ignore.conf /etc/systemd/logind.conf.d/50-power-key-ignore.conf
sudo systemctl kill -s HUP systemd-logind

echo "== Plasma: power button action = do nothing (the service handles it)"
if command -v kwriteconfig6 >/dev/null; then
  for profile in AC Battery LowBattery; do
    kwriteconfig6 --file powerdevilrc --group "$profile" --group SuspendAndShutdown --key PowerButtonAction 0
  done
  systemctl --user restart plasma-powerdevil.service 2>/dev/null || true
fi

echo "== service"
install -Dm755 src/screen-toggle "$HOME/.local/bin/screen-toggle"
install -Dm644 systemd/screen-toggle.service "$HOME/.config/systemd/user/screen-toggle.service"
systemctl --user daemon-reload
if [ "${NEED_RELOGIN:-0}" = 1 ]; then
  systemctl --user enable screen-toggle.service
  echo "Added you to the 'input' group: log out and back in, then the toggle starts by itself."
else
  systemctl --user enable --now screen-toggle.service
  systemctl --user --no-pager status screen-toggle.service | head -5
fi
echo "Done. Tap the power button to toggle the screens."

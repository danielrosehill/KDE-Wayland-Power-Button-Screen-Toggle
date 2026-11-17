#!/usr/bin/env bash
# Remove the toggle and give the power button back to Plasma/logind defaults.
set -euo pipefail
systemctl --user disable --now screen-toggle.service 2>/dev/null || true   # stopping turns screens on and releases grabs
rm -f "$HOME/.local/bin/screen-toggle" "$HOME/.config/systemd/user/screen-toggle.service"
systemctl --user daemon-reload
sudo rm -f /etc/systemd/logind.conf.d/50-power-key-ignore.conf
sudo systemctl kill -s HUP systemd-logind
if command -v kwriteconfig6 >/dev/null; then
  for profile in AC Battery LowBattery; do
    kwriteconfig6 --file powerdevilrc --group "$profile" --group SuspendAndShutdown --key PowerButtonAction --delete
  done
  systemctl --user restart plasma-powerdevil.service 2>/dev/null || true
fi
echo "Removed. Power button is back to the Plasma default."

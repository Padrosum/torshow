#!/usr/bin/env bash
# Install the Tor Circuit desktop widget for the current user.
# No root needed. Run again after editing the sources to update the copy.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/tor-circuit"
unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tor-circuit-widget.service"

mkdir -p "$dest" "$(dirname "$unit")"
install -m 0644 "$here/shell.qml" "$dest/shell.qml"
install -m 0755 "$here/tor_status.py" "$dest/tor_status.py"
install -d "$HOME/.local/bin"
install -m 0755 "$here/tor-widget" "$HOME/.local/bin/tor-widget"

cat >"$unit" <<'EOF'
[Unit]
Description=Tor Circuit desktop widget
After=graphical-session.target
PartOf=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
ExecStart=/usr/bin/qs --no-duplicate --path %h/.config/quickshell/tor-circuit/shell.qml
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable tor-circuit-widget.service
systemctl --user restart tor-circuit-widget.service
echo "installed: $dest"
echo "service:   tor-circuit-widget.service (enabled, running)"
echo "next:      sudo ./setup-tor-access.sh   # once, grants read access to Tor's control cookie"
echo "toggle:    tor-widget toggle  (bind it to a key in your compositor)"

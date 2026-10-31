#!/usr/bin/env bash
# Grant the desktop user read access to Tor's control cookie so the widget can
# read the active circuit. Run once with sudo:  sudo ./setup-tor-access.sh
#
# Why a separate unit: tor.service runs under a hardened sandbox without
# CAP_FOWNER, so setfacl inside it fails with EPERM (and would take the whole
# service down). A oneshot helper unit runs the ACL step outside that sandbox,
# after Tor signalled readiness, and is restarted together with Tor.
set -euo pipefail
user="${SUDO_USER:-$USER}"
[ "$user" != "root" ] || { echo "run with sudo, not as root" >&2; exit 1; }
command -v setfacl >/dev/null || { echo "setfacl missing: install acl" >&2; exit 1; }

# 1. Repair a tor.service that an older version of this script left broken.
systemctl reset-failed tor.service 2>/dev/null || true

# 2. Tor needs the control port and cookie auth (idempotent).
if ! grep -qE '^[[:space:]]*ControlPort[[:space:]]+127\.0\.0\.1:9051' /etc/tor/torrc; then
    printf '\nControlPort 127.0.0.1:9051\nCookieAuthentication 1\n' >>/etc/tor/torrc
fi
if ! grep -qE '^[[:space:]]*CookieAuthentication[[:space:]]+1' /etc/tor/torrc; then
    printf 'CookieAuthentication 1\n' >>/etc/tor/torrc
fi

# 3. Helper that applies the ACL outside tor.service's sandbox.
cat >/etc/systemd/system/tor-control-acl.service <<EOF
[Unit]
Description=Grant ${user} read access to the Tor control cookie
After=tor.service
Requires=tor.service
PartOf=tor.service

[Service]
Type=oneshot
ExecStart=/usr/bin/setfacl -m u:${user}:x /var/lib/tor
ExecStart=/usr/bin/setfacl -m u:${user}:r /var/lib/tor/control_auth_cookie
RemainAfterExit=yes
EOF

systemctl daemon-reload
systemctl enable tor-control-acl.service >/dev/null
systemctl restart tor.service
systemctl restart tor-control-acl.service

if sudo -u "$user" test -r /var/lib/tor/control_auth_cookie; then
    echo "ok: $user can read /var/lib/tor/control_auth_cookie"
else
    echo "failed: $user still cannot read the cookie" >&2
    exit 1
fi

systemctl restart --user tor-circuit-widget.service 2>/dev/null || true
echo "done. Check the card; it refreshes every 10 seconds."

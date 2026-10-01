#!/usr/bin/env bash
set -Eeuo pipefail

COLLECTOR_CONF="\${SYSLOG_NG_COLLECTOR_CONF:-/etc/syslog-ng/conf.d/asus-edge-collector.conf}"
DROPIN_DIR="\${SYSLOG_NG_DROPIN_DIR:-/etc/systemd/system/syslog-ng.service.d}"
DROPIN_PATH="$DROPIN_DIR/20-asus-edge-tailscale.conf"
COLLECTOR_PORT="\${SYSLOG_NG_COLLECTOR_PORT:-6514}"

fail() {
  echo "ERROR: $*" >&2
  return 1
}

if [[ ! -f "$COLLECTOR_CONF" ]]; then
  if [[ -f "$DROPIN_PATH" ]]; then
    echo "Removing stale ASUS Edge syslog-ng readiness drop-in"
    sudo rm -f "$DROPIN_PATH"
    sudo systemctl daemon-reload
  fi
  echo "INFO: ASUS Edge syslog-ng collector config is not present; readiness integration skipped."
  exit 0
fi

for cmd in awk install mktemp rpm ss sudo systemctl systemd-analyze tailscale; do
  command -v "$cmd" >/dev/null 2>&1 ||
    fail "required command not found: $cmd"
done

rpm -q syslog-ng >/dev/null 2>&1 ||
  fail "syslog-ng package is required when $COLLECTOR_CONF is present."
rpm -q tailscale >/dev/null 2>&1 ||
  fail "tailscale package is required when $COLLECTOR_CONF is present."

tailscale wait --timeout=10s >/dev/null ||
  fail "Tailscale is not ready; restore/authenticate the node before enabling the collector."

ts_ip="$(tailscale ip -4 2>/dev/null | awk 'NF { print; exit }')"
[[ "$ts_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||
  fail "unable to determine the current Tailscale IPv4 address."

tailscale ip --assert="$ts_ip" >/dev/null ||
  fail "current Tailscale IPv4 assertion failed."

tailscale_bin="$(command -v tailscale)"
[[ "$tailscale_bin" == /* ]] ||
  fail "tailscale executable path is not absolute: $tailscale_bin"

tmp_dropin="$(mktemp)"
tmp_previous="$(mktemp)"
had_previous=0

cleanup() {
  rm -f "$tmp_dropin" "$tmp_previous"
}
trap cleanup EXIT

if [[ -f "$DROPIN_PATH" ]]; then
  cat "$DROPIN_PATH" >"$tmp_previous"
  had_previous=1
fi

rollback() {
  local rc=$?
  trap - ERR
  set +e

  echo "ERROR: syslog-ng Tailscale readiness setup failed; restoring previous drop-in state." >&2

  if (( had_previous )); then
    sudo install -D -m 0644 "$tmp_previous" "$DROPIN_PATH"
  else
    sudo rm -f "$DROPIN_PATH"
  fi

  sudo systemctl daemon-reload >/dev/null 2>&1 || true
  exit "$rc"
}
trap rollback ERR

cat >"$tmp_dropin" <<EOF
[Unit]
Wants=tailscaled.service network-online.target
After=tailscaled.service network-online.target

[Service]
ExecStartPre=$tailscale_bin wait --timeout=60s
ExecStartPre=$tailscale_bin ip --assert=$ts_ip
RestartSec=15s
EOF

sudo install -D -m 0644 "$tmp_dropin" "$DROPIN_PATH"
sudo systemctl daemon-reload
sudo systemd-analyze verify syslog-ng.service
sudo systemctl enable syslog-ng.service >/dev/null
sudo systemctl restart syslog-ng.service

systemctl is-active --quiet syslog-ng.service ||
  fail "syslog-ng did not become active after installing the readiness guard."

if ! ss -H -lnt | awk -v addr="$ts_ip:$COLLECTOR_PORT" '
  $4 == addr { found=1 }
  END { exit found ? 0 : 1 }
'; then
  fail "syslog-ng is not listening on the current Tailscale IPv4 address and TCP/$COLLECTOR_PORT."
fi

trap - ERR

echo "PASS: syslog-ng waits for Tailscale readiness before startup"
echo "PASS: Tailscale IPv4 assertion matches the current node address"
echo "PASS: syslog-ng collector is listening on the Tailscale address"

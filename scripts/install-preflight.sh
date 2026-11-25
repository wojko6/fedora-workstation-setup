#!/usr/bin/env bash
# Read-only gate shared by the installer's check, apply and default paths.
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf 'PASS: %s\n' "$*"; }

if (( EUID == 0 )); then
  fail "run install.sh as the desktop user, not as root"
  exit 1
fi
if [[ ! -d "${XDG_RUNTIME_DIR:-}" || ! -O "${XDG_RUNTIME_DIR:-}" || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  fail "the desktop user's runtime directory and graphical session bus are required"
elif [[ "$DBUS_SESSION_BUS_ADDRESS" != unix:* || "$DBUS_SESSION_BUS_ADDRESS" == *";"* ]]; then
  fail "a local GNOME session bus address is required"
elif [[ "$(gdbus call --address "$DBUS_SESSION_BUS_ADDRESS" --timeout 5 \
    --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.NameHasOwner org.gnome.Shell)" != '(true,)' ]]; then
  fail "GNOME Shell must already own its name on the target session bus"
else
  pass "running GNOME user session"
fi

fedora="$(rpm -E %fedora 2>/dev/null)" || fedora=unknown
gnome="$(gnome-shell --version 2>/dev/null)" || gnome=unknown
if ! cat /etc/fedora-release >/dev/null 2>&1 || [[ "$fedora" != 44 ]]; then
  fail "Fedora 44 Workstation is required (RPM release: $fedora)"
elif [[ -e /run/ostree-booted ]] || { command -v rpm-ostree >/dev/null && rpm-ostree status >/dev/null 2>&1; }; then
  fail "rpm-ostree systems are unsupported"
else
  pass "classic Fedora 44"
fi
if [[ "$gnome" =~ ^GNOME\ Shell\ 50([.[:space:]]|$) ]]; then
  pass "$gnome"
else
  fail "GNOME Shell 50 is required (found: $gnome)"
fi

# Tools the restore uses without first installing a provider.
for cmd in bash python3 rpm dnf sudo awk grep ip nmcli systemctl gnome-shell \
    gdbus gresource gsettings dconf gnome-extensions glib-compile-schemas patch tar \
    sha256sum install cmp dracut lsinitrd restorecon udevadm sysctl; do
  command -v "$cmd" >/dev/null || fail "missing required host command: $cmd"
done

# The first stage bootstraps these before it first consumes them.
for cmd in curl gpg; do
  command -v "$cmd" >/dev/null ||
    printf 'WARN: %s is supplied by setup-repositories.sh during bootstrap\n' "$cmd"
done

# A missing tool may be deferred only if the RPM stage requests its provider.
while read -r cmd package; do
  if ! command -v "$cmd" >/dev/null; then
    if grep -Fxq -- "$package" packages/rpm.txt; then
      printf 'WARN: %s is deferred to install-packages.sh (%s)\n' "$cmd" "$package"
    else
      fail "$cmd is missing and packages/rpm.txt lacks its provider $package"
    fi
  fi
done <<'PROVIDERS'
flatpak flatpak
firewall-cmd firewalld
tailscale tailscale
ddcutil ddcutil
unzip unzip
gettext gettext
msgfmt gettext
msgcat gettext
msgcmp gettext
msgunfmt gettext
msgattrib gettext
ptyxis ptyxis
PROVIDERS

for stage in "$@"; do
  [[ -f "$stage" && -r "$stage" && -s "$stage" ]] || fail "missing or unreadable stage: $stage"
done
if ! python3 -IB scripts/validate-repository.py; then
  fail "repository inputs, manifests or extension locks failed validation"
fi
if ! python3 -IB scripts/verify-repository-trust.py --check-policy; then
  fail "invalid external repository trust policy"
fi
if ! bash network/check-trusted-wifi.sh; then
  fail "trusted Wi-Fi preflight failed"
fi
if [[ -n "${WIFI_PROFILE:-}" ]]; then
  if [[ "$(nmcli -g connection.type connection show "$WIFI_PROFILE" 2>/dev/null)" == 802-11-wireless ]]; then
    pass "explicit Wi-Fi power-save profile exists"
  else
    fail "WIFI_PROFILE must identify an existing Wi-Fi connection"
  fi
fi

# This optional stage consumes a private, operator-provisioned syslog-ng setup.
if [[ -f "${SYSLOG_NG_COLLECTOR_CONF:-/etc/syslog-ng/conf.d/asus-edge-collector.conf}" ]]; then
  rpm -q syslog-ng >/dev/null 2>&1 || fail "private collector requires the syslog-ng package"
  for cmd in ss systemd-analyze; do
    command -v "$cmd" >/dev/null || fail "private collector requires $cmd"
  done
  echo "WARN: collector Tailscale authentication and listener readiness are checked at apply time"
else
  echo "SKIP: private syslog-ng collector configuration is absent"
fi
case ":${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:" in
  *:/usr/local/share:*|*:/usr/local/share/:*) pass "managed DING data directory is visible" ;;
  *) fail "managed DING requires /usr/local/share in XDG_DATA_DIRS" ;;
esac

weather=gnome/weather-locations.local.tsv
if [[ -e "$weather" || -L "$weather" ]]; then
  if python3 -IB scripts/manage-weather-locations.py --check-config --config "$weather" >/dev/null 2>&1; then
    pass "private Weather configuration parsed"
  else
    fail "invalid private Weather configuration (check TSV format and coordinates)"
  fi
else
  echo "SKIP: private Weather configuration is absent"
fi
asus=desktop/launchers/asus-router.conf
if [[ -e "$asus" || -L "$asus" ]]; then
  if python3 -IB scripts/render-asus-launcher.py --config "$asus" \
      --template desktop/launchers/asus-router.desktop.template \
      --ddterm-bin "$HOME/.local/share/gnome-shell/extensions/ddterm@amezin.github.com/bin/com.github.amezin.ddterm" \
      --check-key-file --output /dev/null >/dev/null 2>&1; then
    pass "private ASUS launcher inputs validated"
  else
    fail "invalid private ASUS launcher configuration, template or key path"
  fi
else
  echo "SKIP: private ASUS launcher configuration is absent"
fi

if (( failures )); then
  printf 'FAIL: %d mandatory preflight check(s) failed\n' "$failures" >&2
  exit 1
fi
pass "mandatory preflight complete"

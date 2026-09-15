#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RPM_MANIFEST="$ROOT_DIR/packages/rpm.txt"
EXT_LIST="$ROOT_DIR/gnome/enabled-extensions.txt"

pass=0
warn=0
fail=0

ok()   { printf 'PASS: %s\n' "$*"; pass=$((pass + 1)); }
warn() { printf 'WARN: %s\n' "$*"; warn=$((warn + 1)); }
bad()  { printf 'FAIL: %s\n' "$*"; fail=$((fail + 1)); }

echo "=== SYSTEM ==="
if [[ -r /etc/fedora-release ]]; then
  cat /etc/fedora-release
  ok "Fedora release detected"
else
  bad "/etc/fedora-release missing"
fi

gnome-shell --version 2>/dev/null || warn "GNOME Shell version unavailable"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"

echo
echo "=== RPM MANIFEST ==="
if [[ -f "$RPM_MANIFEST" ]]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if rpm -q "$pkg" >/dev/null 2>&1; then
      ok "rpm $pkg"
    else
      warn "rpm missing: $pkg"
    fi
  done < "$RPM_MANIFEST"
else
  bad "missing $RPM_MANIFEST"
fi

echo
echo "=== EXTERNAL REPOSITORIES ==="
repo_ids="$(dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}')"
for repo in rpmfusion-free rpmfusion-nonfree brave-browser nordvpn; do
  if grep -Fxq "$repo" <<<"$repo_ids"; then
    ok "repo $repo"
  else
    warn "repo not enabled: $repo"
  fi
done

echo
echo "=== GNOME EXTENSIONS ==="
if command -v gnome-extensions >/dev/null 2>&1; then
  if [[ -f "$EXT_LIST" ]]; then
    while IFS= read -r uuid; do
      [[ -z "$uuid" || "$uuid" == \#* ]] && continue
      if gnome-extensions info "$uuid" >/dev/null 2>&1; then
        ok "extension installed: $uuid"
      else
        bad "required extension missing: $uuid"
      fi
    done < "$EXT_LIST"
  else
    bad "missing $EXT_LIST"
  fi
else
  bad "gnome-extensions command unavailable"
fi

echo
echo "=== WIFI POWER SAVE ==="
iface="$(iw dev 2>/dev/null | awk '$1=="Interface" {print $2; exit}')"
if [[ -n "$iface" ]]; then
  printf 'Interface: %s\n' "$iface"
  ps="$(iw dev "$iface" get power_save 2>/dev/null || true)"
  printf '%s\n' "$ps"
  if grep -qi 'off' <<<"$ps"; then
    ok "Wi-Fi power save disabled"
  else
    warn "Wi-Fi power save is not confirmed off"
  fi
else
  warn "No Wi-Fi interface detected"
fi

echo
echo "=== FLATPAK APPS ==="
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application 2>/dev/null || true
else
  warn "flatpak command unavailable"
fi

echo
echo "=== GNOME DESIRED STATE ==="
if [[ -x "$ROOT_DIR/scripts/audit-gnome.sh" || -f "$ROOT_DIR/scripts/audit-gnome.sh" ]]; then
  gnome_audit="$(bash "$ROOT_DIR/scripts/audit-gnome.sh" 2>&1 || true)"
  gnome_summary="$(grep -Eo 'PASS=[0-9]+ WARN=[0-9]+' <<<"$gnome_audit" | tail -n 1)"

  if [[ "$gnome_summary" =~ ^PASS=([0-9]+)\ WARN=([0-9]+)$ ]]; then
    gnome_pass="${BASH_REMATCH[1]}"
    gnome_warn="${BASH_REMATCH[2]}"
    if (( gnome_warn == 0 )); then
      ok "GNOME desired state matches (${gnome_pass} checks)"
    else
      warn "GNOME desired state has ${gnome_warn} mismatch(es)"
    fi
  else
    warn "GNOME audit summary unavailable"
  fi
else
  warn "scripts/audit-gnome.sh missing"
fi

echo
echo "=== DING POLISH TRANSLATION ==="
DING_PO="$ROOT_DIR/patches/gnome-extensions/ding/pl.po"
DING_DIR="$HOME/.local/share/gnome-shell/extensions/ding@rastersoft.com/locale/pl/LC_MESSAGES"
DING_INSTALLED_PO="$DING_DIR/pl.po"
DING_MO="$DING_DIR/ding.mo"

if [[ -f "$DING_PO" ]] && command -v msgfmt >/dev/null 2>&1; then
  tmp_mo="$(mktemp)"
  if msgfmt --check "$DING_PO" -o "$tmp_mo" 2>/dev/null; then
    if [[ -f "$DING_INSTALLED_PO" ]] && cmp -s "$DING_PO" "$DING_INSTALLED_PO"; then
      ok "DING pl.po matches repository"
    else
      warn "DING installed pl.po differs or is missing"
    fi

    if [[ -f "$DING_MO" ]] && cmp -s "$tmp_mo" "$DING_MO"; then
      ok "DING ding.mo matches repository translation"
    else
      warn "DING ding.mo differs or is missing"
    fi
  else
    bad "repository DING pl.po failed msgfmt validation"
  fi
  rm -f "$tmp_mo"
else
  warn "DING translation source or msgfmt unavailable"
fi

echo
echo "=== DESKTOP LAUNCHERS ==="
for launcher in "Counter-Strike 2.desktop" "asus-router.desktop"; do
  if [[ -f "$HOME/Pulpit/$launcher" ]]; then
    ok "desktop launcher: $launcher"
  else
    warn "desktop launcher missing: $launcher"
  fi
done

if [[ -f "$ROOT_DIR/desktop/launchers/asus-router.conf" ]]; then
  ok "private ASUS launcher configuration available"
else
  warn "private ASUS launcher configuration missing"
fi

echo
echo "=== EXTENSION VERSIONS ==="
EXT_INVENTORY="$ROOT_DIR/gnome/extensions-inventory.tsv"

if [[ -f "$EXT_INVENTORY" ]]; then
  while IFS=$'\t' read -r uuid name expected_version shell_versions url location; do
    [[ "$uuid" == "uuid" || -z "$uuid" || -z "$expected_version" ]] && continue

    # System extensions under /usr/share are restored and versioned by Fedora RPMs.
    # Pin exact metadata versions only for user extensions under ~/.local.
    [[ "$location" != "~/.local/"* ]] && continue

    current="$(
      gnome-extensions info "$uuid" 2>/dev/null |
      sed -nE 's/^[[:space:]]*(Version|Wersja):[[:space:]]*//p' |
      head -n 1
    )"

    if [[ -z "$current" ]]; then
      bad "required extension version unavailable: $uuid"
    elif [[ "$current" == "$expected_version" ||
            "$current" =~ \("$expected_version"\)$ ]]; then
      ok "extension version $uuid = $expected_version"
    else
      bad "extension version $uuid: expected $expected_version, found $current"
    fi
  done < "$EXT_INVENTORY"
else
  bad "extension inventory missing"
fi

echo
echo "=== SUMMARY ==="
printf 'PASS=%d WARN=%d FAIL=%d\n' "$pass" "$warn" "$fail"

(( fail == 0 ))

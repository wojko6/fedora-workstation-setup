#!/usr/bin/env bash
set -u

PASS=0
WARN=0
FAIL=0

pass() {
    printf 'PASS: %s\n' "$1"
    PASS=$((PASS + 1))
}

warn() {
    printf 'WARN: %s\n' "$1"
    WARN=$((WARN + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1"
    FAIL=$((FAIL + 1))
}

DAEMON="/usr/bin/gnome-keyring-daemon"
PL_MO="/usr/share/locale/pl/LC_MESSAGES/gnome-keyring.mo"

echo "=== GNOME KEYRING I18N ==="

if rpm -q gnome-keyring >/dev/null 2>&1; then
    KEYRING_NEVRA="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' gnome-keyring)"
    pass "installed package: $KEYRING_NEVRA"
else
    fail "gnome-keyring package is not installed"
fi

if rpm -q gnome-keyring-pam >/dev/null 2>&1; then
    PAM_NEVRA="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' gnome-keyring-pam)"
    pass "installed PAM package: $PAM_NEVRA"
else
    fail "gnome-keyring-pam package is not installed"
fi

if [[ -x "$DAEMON" ]]; then
    pass "gnome-keyring-daemon is available"
else
    fail "gnome-keyring-daemon is missing"
fi

if [[ -x "$DAEMON" ]] && command -v objdump >/dev/null 2>&1; then
    SYMBOLS="$(objdump -T "$DAEMON" 2>/dev/null || true)"

    if grep -q '[[:space:]]bindtextdomain$' <<<"$SYMBOLS" &&
       grep -q '[[:space:]]textdomain$' <<<"$SYMBOLS"; then
        pass "gettext initialization symbols are present in gnome-keyring-daemon"
    else
        fail "gettext initialization symbols are missing from gnome-keyring-daemon"
    fi
else
    fail "cannot inspect gettext symbols"
fi

if [[ -f "$PL_MO" ]]; then
    pass "Polish gnome-keyring message catalog is installed"
else
    fail "Polish gnome-keyring message catalog is missing"
fi

if [[ -f "$PL_MO" ]] && command -v msgunfmt >/dev/null 2>&1; then
    MO_TEXT="$(msgunfmt "$PL_MO" 2>/dev/null || true)"

    if grep -Fq 'msgstr "Wymagane jest uwierzytelnienie"' <<<"$MO_TEXT" &&
       grep -Fq 'msgstr "Odblokuj"' <<<"$MO_TEXT"; then
        pass "required Polish authentication translations are present"
    else
        fail "required Polish authentication translations were not found"
    fi
else
    warn "Polish message catalog contents were not inspected"
fi

if rpm -q gnome-keyring >/dev/null 2>&1; then
    RELEASE="$(rpm -q --qf '%{RELEASE}\n' gnome-keyring)"

    if [[ "$RELEASE" == *i18nfix* ]]; then
        pass "local gettext backport is installed"
    else
        pass "GNOME Keyring uses a non-backport package release"
    fi
fi

echo
printf 'SUMMARY: PASS=%d WARN=%d FAIL=%d\n' "$PASS" "$WARN" "$FAIL"

if (( FAIL > 0 )); then
    exit 1
fi

exit 0

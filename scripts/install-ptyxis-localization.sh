#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="ptyxis"
EXPECTED_NVR="50.1-2.fc44"
SOURCE_PO="$ROOT_DIR/localization/ptyxis/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo"
BACKUP_MO="${TARGET_MO}.fedora-workstation-setup.upstream.bak"
DESKTOP_FILE="/usr/share/applications/org.gnome.Ptyxis.desktop"
DESKTOP_BACKUP="${DESKTOP_FILE}.fedora-workstation-setup.upstream.bak"
EXPECTED_DESKTOP_SHA256="8c596c2aff40ac062f61e6c541f0bccfa62091ce8503d63e2306d2e0a97f2b88"
DESKTOP_PATCHER="$ROOT_DIR/scripts/ptyxis_desktop_actions.py"
RESOURCE_AUDITOR="$ROOT_DIR/scripts/ptyxis_resource_audit.py"

for cmd in rpm msgfmt gettext cmp sudo sha256sum python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "FAIL: required package not installed: $PACKAGE" >&2
    exit 1
fi

nvr="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$PACKAGE")"
if [[ "$nvr" != "$EXPECTED_NVR" ]]; then
    echo "FAIL: Ptyxis package drift: expected $EXPECTED_NVR, found $nvr" >&2
    exit 1
fi

for path in "$SOURCE_PO" "$DESKTOP_FILE" "$DESKTOP_PATCHER" "$RESOURCE_AUDITOR"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required Ptyxis localization source missing: $path" >&2
        exit 1
    fi
done

installed_package="$(rpm -q "$PACKAGE")"
desktop_owner="$(rpm -qf "$DESKTOP_FILE" 2>/dev/null || true)"
if [[ "$desktop_owner" != "$installed_package" ]]; then
    echo "FAIL: Ptyxis desktop file is not owned by expected package: $DESKTOP_FILE" >&2
    exit 1
fi

tmp_mo="$(mktemp)"
tmp_desktop="$(mktemp)"
trap 'rm -f "$tmp_mo" "$tmp_desktop"' EXIT

msgfmt --check "$SOURCE_PO" -o "$tmp_mo"

if [[ ! -f "$TARGET_MO" ]] || ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    if [[ -f "$TARGET_MO" && ! -f "$BACKUP_MO" ]]; then
        if rpm -qf "$TARGET_MO" >/dev/null 2>&1; then
            sudo cp -a "$TARGET_MO" "$BACKUP_MO"
            echo "Backup: $BACKUP_MO"
        else
            echo "INFO: replacing unowned/local Ptyxis catalog without creating an upstream backup"
        fi
    fi

    sudo install -D -m 0644 "$tmp_mo" "$TARGET_MO"
    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon "$TARGET_MO"
    fi
fi

if ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "FAIL: installed Ptyxis Polish catalog differs from repository catalog" >&2
    exit 1
fi

read -r desktop_hash _ < <(sha256sum "$DESKTOP_FILE")

if [[ -f "$DESKTOP_BACKUP" ]]; then
    read -r backup_hash _ < <(sha256sum "$DESKTOP_BACKUP")
    if [[ "$backup_hash" != "$EXPECTED_DESKTOP_SHA256" ]]; then
        echo "FAIL: Ptyxis pristine desktop backup fingerprint drift: $backup_hash" >&2
        exit 1
    fi
else
    if [[ "$desktop_hash" != "$EXPECTED_DESKTOP_SHA256" ]]; then
        echo "FAIL: Ptyxis desktop file is neither audited pristine state nor backed up; refusing to overwrite" >&2
        echo "INFO: expected pristine SHA-256: $EXPECTED_DESKTOP_SHA256" >&2
        echo "INFO: current SHA-256:          $desktop_hash" >&2
        exit 1
    fi

    sudo cp -a "$DESKTOP_FILE" "$DESKTOP_BACKUP"
    echo "Backup: $DESKTOP_BACKUP"
fi

python3 "$DESKTOP_PATCHER" --input "$DESKTOP_BACKUP" --output "$tmp_desktop"

if ! cmp -s "$tmp_desktop" "$DESKTOP_FILE"; then
    read -r desktop_hash _ < <(sha256sum "$DESKTOP_FILE")
    if [[ "$desktop_hash" != "$EXPECTED_DESKTOP_SHA256" ]]; then
        echo "FAIL: Ptyxis desktop file differs from both audited pristine and expected localized state" >&2
        exit 1
    fi

    sudo install -m 0644 "$tmp_desktop" "$DESKTOP_FILE"
    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon "$DESKTOP_FILE"
    fi
fi

if ! cmp -s "$tmp_desktop" "$DESKTOP_FILE"; then
    echo "FAIL: installed Ptyxis desktop actions differ from repository-managed expected state" >&2
    exit 1
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$DESKTOP_FILE"
fi

PTYXIS_BIN="$(command -v ptyxis)"
python3 "$RESOURCE_AUDITOR" --binary "$PTYXIS_BIN" --mo "$TARGET_MO"

while IFS='|' read -r source expected; do
    actual="$(
        LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
            gettext -d ptyxis "$source"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Ptyxis gettext smoke test for '$source': expected '$expected', found '$actual'" >&2
        exit 1
    fi
done <<'EOF'
New _Tab|Nowa _karta
New _Window|Nowe _okno
Show Open Tabs|Pokaż otwarte karty
Fullscreen|Pełny ekran
_Preferences|_Preferencje
_Keyboard Shortcuts|_Skróty klawiszowe
_About|_O programie
_Open Link|Otwórz _odnośnik
_Copy Link|_Kopiuj odnośnik
Search…|Szukaj…
_Copy|_Kopiuj
Copy selection from terminal to clipboard|Skopiuj zaznaczenie z terminala do schowka
Copy as _HTML|Kopiuj jako _HTML
Copy selection from terminal to clipboard with HTML formatting|Skopiuj zaznaczenie z terminala do schowka z formatowaniem HTML
_Paste|_Wklej
Paste from clipboard into the terminal|Wklej ze schowka do terminala
Select _All|Zaznacz _wszystko
Selection all text from terminal including scrollback|Zaznacz cały tekst terminala, w tym historię przewijania
Select _None|Odznacz _wszystko
Read-Only|Tylko do odczytu
Reset|Zresetuj
Reset and Clear|Zresetuj i wyczyść
Set Title|Ustaw tytuł
Change Profile|Zmień profil
Leave Fullscreen|Opuść pełny ekran
_Inspect Terminal|_Zbadaj terminal
Search History|Szukaj w historii
Inspector|Inspektor
Process|Proces
Foreground Process|Proces pierwszoplanowy
Window Title|Tytuł okna
Current Directory|Bieżący katalog
Current File|Bieżący plik
Container|Kontener
Runtime|Środowisko uruchomieniowe
Name|Nazwa
Appearance|Wygląd
Grid Size|Rozmiar siatki
Palette|Paleta
Colors|Kolory
Font|Czcionka
Cell Size|Rozmiar komórki
Input|Wejście
Cursor|Kursor
Position|Pozycja
Row|Wiersz
Column|Kolumna
Mouse|Mysz
Hyperlink|Hiperłącze
unset|nie ustawiono
untracked|nieśledzona
Shell|Powłoka
Title|Tytuł
Include Process Title|Uwzględnij tytuł procesu
Append title from Shell application|Dołącz tytuł z aplikacji powłoki
Match _Case|Rozróżniaj _wielkość liter
Whole _Words|_Całe słowa
Use _Regular Expressions|Używaj _wyrażeń regularnych
Add Link|Dodaj odnośnik
Add Profile|Dodaj profil
Show Fewer Palettes|Pokaż mniej palet
Select Font|Wybierz czcionkę
EOF

echo "PASS: Ptyxis 50.1 Polish catalog, complete audited preferences/profile resources, and GNOME Shell desktop-action localization installed"
echo "INFO: launcher actions: New Window -> Nowe okno; New Tab -> Nowa karta; Preferences -> Preferencje"
echo "INFO: reopen the GNOME app grid; sign out/in only if Shell still caches the old desktop-action labels"

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="ptyxis"
EXPECTED_VERSION="50.1"
SOURCE_PO="$ROOT_DIR/localization/ptyxis/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo"
BACKUP_MO="${TARGET_MO}.fedora-workstation-setup.upstream.bak"

for cmd in rpm msgfmt gettext cmp sudo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "FAIL: required command not found: $cmd" >&2
        exit 1
    fi
done

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    echo "FAIL: required package not installed: $PACKAGE" >&2
    exit 1
fi

version="$(rpm -q --qf '%{VERSION}\n' "$PACKAGE")"
if [[ "$version" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: Ptyxis version drift: expected $EXPECTED_VERSION, found $version" >&2
    exit 1
fi

if [[ ! -f "$SOURCE_PO" ]]; then
    echo "FAIL: missing Ptyxis Polish catalog source: $SOURCE_PO" >&2
    exit 1
fi

tmp_mo="$(mktemp)"
trap 'rm -f "$tmp_mo"' EXIT

msgfmt --check "$SOURCE_PO" -o "$tmp_mo"

if [[ -f "$TARGET_MO" ]] && cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "PASS: Ptyxis 50.1 Polish localization bridge already installed"
    exit 0
fi

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

if ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "FAIL: installed Ptyxis Polish catalog differs from repository catalog" >&2
    exit 1
fi

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
EOF

echo "PASS: Ptyxis 50.1 Polish main-window, search, context-menu, and inspector localization installed"
echo "INFO: start a new Ptyxis process to refresh translated main-window, search, context-menu, inspector, and libadwaita strings"

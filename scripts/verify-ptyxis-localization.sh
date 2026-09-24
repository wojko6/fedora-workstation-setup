#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="ptyxis"
EXPECTED_NVR="50.1-2.fc44"
SOURCE_PO="$ROOT_DIR/localization/ptyxis/pl.po"
TARGET_MO="/usr/share/locale/pl/LC_MESSAGES/ptyxis.mo"
LIBADWAITA_MO="/usr/share/locale/pl/LC_MESSAGES/libadwaita.mo"
DESKTOP_FILE="/usr/share/applications/org.gnome.Ptyxis.desktop"
DESKTOP_BACKUP="${DESKTOP_FILE}.fedora-workstation-setup.upstream.bak"
EXPECTED_DESKTOP_SHA256="8c596c2aff40ac062f61e6c541f0bccfa62091ce8503d63e2306d2e0a97f2b88"
DESKTOP_PATCHER="$ROOT_DIR/scripts/ptyxis_desktop_actions.py"
RESOURCE_AUDITOR="$ROOT_DIR/scripts/ptyxis_resource_audit.py"

for cmd in rpm msgfmt gettext cmp gresource sha256sum python3; do
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

for path in "$SOURCE_PO" "$TARGET_MO" "$LIBADWAITA_MO" "$DESKTOP_FILE" "$DESKTOP_BACKUP" "$DESKTOP_PATCHER" "$RESOURCE_AUDITOR"; do
    if [[ ! -f "$path" ]]; then
        echo "FAIL: required localization file missing: $path" >&2
        exit 1
    fi
done

installed_package="$(rpm -q "$PACKAGE")"
desktop_owner="$(rpm -qf "$DESKTOP_FILE" 2>/dev/null || true)"
if [[ "$desktop_owner" != "$installed_package" ]]; then
    echo "FAIL: Ptyxis desktop file is not owned by expected package: $DESKTOP_FILE" >&2
    exit 1
fi

read -r backup_hash _ < <(sha256sum "$DESKTOP_BACKUP")
if [[ "$backup_hash" != "$EXPECTED_DESKTOP_SHA256" ]]; then
    echo "FAIL: Ptyxis pristine desktop backup fingerprint drift: $backup_hash" >&2
    exit 1
fi

tmp_mo="$(mktemp)"
tmp_desktop="$(mktemp)"
find_bar_ui="$(mktemp)"
trap 'rm -f "$tmp_mo" "$tmp_desktop" "$find_bar_ui"' EXIT

msgfmt --check "$SOURCE_PO" -o "$tmp_mo"

if ! cmp -s "$tmp_mo" "$TARGET_MO"; then
    echo "FAIL: live Ptyxis Polish catalog differs from repository catalog" >&2
    exit 1
fi

python3 "$DESKTOP_PATCHER" --input "$DESKTOP_BACKUP" --output "$tmp_desktop"
if ! cmp -s "$tmp_desktop" "$DESKTOP_FILE"; then
    echo "FAIL: Ptyxis GNOME Shell desktop-action localization differs from repository-managed expected state" >&2
    exit 1
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$DESKTOP_FILE"
fi

PTYXIS_BIN="$(command -v ptyxis)"
python3 "$RESOURCE_AUDITOR" --binary "$PTYXIS_BIN" --mo "$TARGET_MO"

FIND_BAR_RESOURCE="/org/gnome/Ptyxis/ptyxis-find-bar.ui"

if ! gresource extract "$PTYXIS_BIN" "$FIND_BAR_RESOURCE" >"$find_bar_ui" 2>/dev/null; then
    echo "FAIL: unable to extract Ptyxis find-bar resource" >&2
    exit 1
fi

for source in 'Match _Case' 'Whole _Words' 'Use _Regular Expressions'; do
    if ! grep -Fq ">$source<" "$find_bar_ui"; then
        echo "FAIL: audited Ptyxis resource string missing: $source" >&2
        exit 1
    fi
done

while IFS='|' read -r source expected; do
    actual="$(
        LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
            gettext -d ptyxis "$source"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Ptyxis Polish string $source: expected '$expected', found '$actual'" >&2
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

while IFS='|' read -r source expected; do
    actual="$(
        LANGUAGE=pl LANG=pl_PL.UTF-8 LC_ALL=pl_PL.UTF-8 \
            gettext -d libadwaita "$source"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: libadwaita Polish string $source: expected '$expected', found '$actual'" >&2
        exit 1
    fi
done <<'EOF'
_Website|Str_ona programu
_Report an Issue|Zgłoś _błąd
_Troubleshooting|_Rozwiązywanie problemów
_Credits|_Zasługi
_Legal|_Kwestie prawne
EOF

echo "PASS: Ptyxis 50.1 Polish catalog, complete audited preference/profile resources, libadwaita About strings, and GNOME Shell desktop actions match repository"

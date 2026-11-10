# Fedora Tahoe — Plasma Flex Hub: poprawki KDE Plasma 6.8

Zestaw lokalnych poprawek [Plasma Flex Hub](https://github.com/zayronxio/Plasma.Flex.Hub), zweryfikowany na **Fedora 44 / KDE Plasma 6.8.2 / Wayland** (10 listopada 2026).

## Zakres

| Patch | Funkcja |
|---|---|
| `0001-szerokosc-panelu-360.patch` | Poszerzenie wyskakującego centrum sterowania do ok. 360 px z zachowaniem osobnego trybu edycji |
| `0002-podpowiedzi-wifi-bluetooth.patch` | Pełna nazwa SSID / urządzenia Bluetooth po najechaniu na kafelek |
| `0003-zgodnosc-jasnosci-plasma-6-8.patch` | Zastąpienie błędnego testu tekstowego `6.4` sprawdzaniem wersji co najmniej 6.4 |
| `0004-bezwzgledne-ustawianie-jasnosci.patch` | Bezpośrednie ustawianie jasności w skali procentowej zamiast pojedynczych kroków |
| `Fedora-Tahoe-FlexHub-all.patch` | Wszystkie cztery poprawki w jednym pliku |

`SHA256SUMS` weryfikuje **oryginalne, niezmodyfikowane** pliki `.patch` pochodzące z lokalnego pakietu testowego. `manifest.json` zawiera sumy SHA-256 plików źródłowych przed i po poprawkach, **bez lokalnych ścieżek kopii zapasowych**.

## Zastosowanie na zgodnej wersji

**Nie stosuj poprawek na już zmodyfikowanej instalacji** ani na nowym wydaniu upstream bez przeglądu różnic. Nie używaj `--force`.

```bash
cd patches/kde-tahoe/flex-hub
sha256sum -c SHA256SUMS

WIDGET="$HOME/.local/share/plasma/plasmoids/Plasma.Flex.Hub"
test -d "$WIDGET" || exit 1
cp -a "$WIDGET" "$WIDGET.backup-$(date +%Y%m%d-%H%M%S)"

# Najpierw porównaj sha256sum siedmiu plików z sha256_before w manifest.json.
patch --dry-run -p1 -d "$WIDGET" < Fedora-Tahoe-FlexHub-all.patch
# Dopiero po pomyślnym dry-run i zgodności wersji bazowej:
patch -p1 -d "$WIDGET" < Fedora-Tahoe-FlexHub-all.patch
```

Dopiero po weryfikacji można przeładować powłokę `plasma-plasmashell` (najpierw kopia paneli). Nie należy przywracać całego pliku `plasma-org.kde.plasma.desktop-appletsrc` z przypadkowego starszego backupu: może przywrócić usunięty Dock.

## Weryfikacja

- Lokalny generator: `VERIFY_ORIGINALS=PASS`, `VERIFY_CURRENT_PATCHED_FILES=PASS`, `COMBINED_PATCH=PASS`.
- Sprawdzenie `sha256sum -c SHA256SUMS`: wszystkie pięć plików `.patch` OK.
- Testy użytkownika: podpowiedzi Wi-Fi/Bluetooth oraz ustawianie jasności, łącznie z 100%, działają w sesji Plasma 6.8.2.
- To **nie jest gwarancja kompatybilności** z kolejnymi wydaniami Plasma / Flex Hub. Przed aktualizacją należy sprawdzić, czy poprawki nie zostały już dodane przez autorów.
- Suwak jasności w tym wariancie używa pierwszego ekranu wykrytego przez model PowerDevil; wybór monitora przy konfiguracji wieloekranowej wymaga osobnych testów.

Źródło: lokalny zweryfikowany pakiet `Fedora-Tahoe-FlexHub-Patches-20261110-171157`. Dokumentacja i manifest są pozbawione absolutnych ścieżek do katalogu użytkownika; zawartość plików `.patch` zachowana bez zmian.

# KDE Plasma / Mac Tahoe Liquid — polskie tłumaczenia B291 i B292

**Stan z 2026-11-07:** obie poprawki zostały zainstalowane przez użytkownika
i wizualnie potwierdzone w KDE Plasma (Fedora 44, KDE 6.8.2, Wayland).
To **punkt kontrolny działającego pulpitu KDE**, a nie zatwierdzenie
historycznego, odtwarzalnego profilu GNOME ani pełna certyfikacja KDE.

## Zakres

| Etap | Plasmoid | Domena gettext | Przetłumaczone komunikaty |
| --- | --- | --- | ---: |
| B291 | `org.kde.mac.tahoe.liquid.globalmenu` | `plasma_applet_org.kde.mac.tahoe.liquid.globalmenu` | 54 |
| B292 | `org.kde.mac-tahoe-liquid-kde.launcher` | `plasma_applet_org.kde.mac-tahoe-liquid-kde.launcher` | 45 |

**Razem: 99 komunikatów**. Liczba wiadomości katalogu `.mo` uwzględnia
dodatkowy wpis nagłówkowy: odpowiednio 55 i 46.

W obu przypadkach źródłem są komunikaty publicznego projektu
[macos-tahoe-liquid-kde](https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde).
To niezależne, lokalne polskie tłumaczenia do weryfikowanej konfiguracji.
Katalog źródłowy repozytorium projektowego zawiera pliki `.po`
pozwalające na dalsze aktualizacje i poprawki. **Nie modyfikowano**
źródeł QML/C++, bibliotek, układu paneli ani motywu.

## Archiwum

Każda domena ma dokładnie dwa pliki w tym katalogu: edytowalne `.po`
i działające, skompilowane `.mo`. Zgodność sum SHA-256 obu źródeł `.po`
z tym archiwum została ponownie sprawdzona 2026-11-07. Pliki `.mo` to
**wzorcowe, sprawdzone na pulpicie artefakty** — po ręcznej edycji `.po`
trzeba ponownie przeprowadzić walidację tłumaczeń i test wizualny; nie
należy zakładać, że każda ponowna kompilacja da binarnie identyczny plik.
Poniżej SHA-256 rzeczywistych plików:

| Plik | SHA-256 |
| --- | --- |
| `plasma_applet_org.kde.mac.tahoe.liquid.globalmenu.po` | `5447beaf22fb94ef8815b1a135e3971cb448ee32184fb3c3b88788dc03f945eb` |
| `plasma_applet_org.kde.mac.tahoe.liquid.globalmenu.mo` | `984b2b021b28532d6ba6d8e5b357fe05698919481628f018e3e6f9dda81ce386` |
| `plasma_applet_org.kde.mac-tahoe-liquid-kde.launcher.po` | `2674d789bf311054c21f37f2f4fc20dc048009486259c0a9684114200f031386` |
| `plasma_applet_org.kde.mac-tahoe-liquid-kde.launcher.mo` | `d005d4fe34873dbdccc90af4527e5faa3d9df0db5f20fd5ef0c45e4bc5240f13` |

## Odtworzenie na Fedorze

Po sklonowaniu tego repozytorium, **bez `sudo`**:

```bash
# Tylko diagnostyka: bez zapisu na dysku i bez restartu Plasmy
bash scripts/install-kde-tahoe-localizations.sh --verify

# Świadoma instalacja, tylko dla bieżącego użytkownika
bash scripts/install-kde-tahoe-localizations.sh --install
```

Skrypt sprawdza SHA-256 czterech plików źródłowych, nie nadpisuje dowiązań
symbolicznych, zachowuje inną dotychczasową wersję `.mo` w kopii zapasowej
i instaluje oba katalogi w:

```text
~/.local/share/locale/pl/LC_MESSAGES/
```

Jeśli `XDG_DATA_HOME` jest zdefiniowane, używa tego katalogu zamiast
`~/.local/share`. Po instalacji należy zapisać pracę, wylogować się
z sesji Plasma i zalogować ponownie, po czym **wizualnie zweryfikować**:
- B291: menu Apple: „Informacje o tym komputerze”, „Ustawienia systemowe”,
  „Uśpij”, „Wyłącz komputer”.
- B292: launcher: „Aplikacje”, „Ulubione”, „Propozycje”,
  „Wariant 1 — Tahoe”, „Pokaż aplikacje w siatce”.

Tylko dwa `.mo` dotyczą działania menu. Same pliki `.po` pozostają
w repozytorium, aby można było przygotować poprawki dla nowszej wersji.
Nie należy podmieniać kodu widżetów ani uruchamiać jego instalatora
do odtwarzania samych tłumaczeń.

## Ograniczenia i bezpieczeństwo

- Lokalny test potwierdził poprawne wyświetlanie menu po polsku; nie
  stanowi audytu wszystkich zakładek lub kolejnych wydań projektu.
- Przy aktualizacji Tahoe Liquid KDE trzeba ponownie sprawdzić domeny
  gettext i zmienione komunikaty; nie zakładać pełnej zgodności w przyszłości.
- Archiwum nie zawiera danych hosta, kont, seriali, tokenów, obrazów pulpitu,
  ani konfiguracji panelu. Publiczne repozytorium przechowuje tylko katalogi
  ogólnych tłumaczeń i dokumentację.
- KDE pozostało w stanie działającym; nie wykonano przy B291/B292 `sudo`,
  restartu `plasmashell`, rekompilacji C++ ani zmian motywu.

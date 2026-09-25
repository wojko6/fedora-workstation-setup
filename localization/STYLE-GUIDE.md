# Polish localization style guide

This document defines repository conventions for Polish UI localization.

It is deliberately **not** a global search-and-replace table. Identical English
msgids can require different Polish wording when they play different UI roles.
Context, grammar, upstream semantics, and physical visual validation take
priority over superficial string equality.

## Gettext metadata

Repository-managed Polish `.po` sources use:

```text
Language: pl
nplurals=3
```

The runtime session locale remains `pl_PL.UTF-8`; gettext catalog language
metadata and the operating-system locale are separate concerns.

Existing translator attribution should be preserved. Do not rewrite
`Last-Translator` merely for cosmetic uniformity.

## Preferred UI terminology

| English source | Preferred Polish | Rule |
| --- | --- | --- |
| Preferences | Preferencje | Standalone preferences page/window/action. A deliberately composed title such as `<name> — ustawienia` may be retained when verified in context. |
| Settings | Ustawienia | General settings noun/page. |
| Copy | Kopiuj | Standalone command/menu action. Use `Skopiuj ...` naturally in a full sentence when Polish aspect requires it. |
| New Folder | Nowy folder | User-facing file-manager UI. Use `katalog` for technical directory/path wording where that is the actual concept. |
| Search | Szukaj / Wyszukiwanie | `Szukaj` for an action, field, or command; `Wyszukiwanie` for a feature/section noun. |
| Reset | Przywróć / Zresetuj | Use `Przywróć` when restoring defaults; use `Zresetuj` for runtime/process/terminal state. Avoid changing strings without checking UI context. |
| About | O programie / O rozszerzeniu | Prefer `O programie` for applications and `O rozszerzeniu` for GNOME Shell extensions. `Informacje` can remain when the source is a generic information section rather than an About dialog. |
| Link | Odnośnik | Preferred user-facing term; keep `adres URL` when the source explicitly refers to a URL. |

## Context-sensitive exceptions

The following differences are intentional and must not be flattened
automatically:

- Vitals v85 uses `Preferences -> — ustawienia` in the audited completion
  because it is treated as a title fragment in that UI. Any future change
  requires source/runtime review rather than a blind terminology replacement.
- Just Perfection uses `Search -> Wyszukiwanie` for a feature/section noun,
  while Clipboard Indicator uses `Search -> Szukaj` for an action.
- `About` wording may differ between an application, an extension, and a
  generic information page.
- Direction labels such as `Left` / `Right` depend on the grammatical gender
  of the implied Polish noun.
- `Dash` can mean the GNOME application dash or a line/dash indicator; those
  are different concepts.

## Review workflow

For a changed localization target:

1. validate the exact upstream/runtime version and source fingerprints;
2. run `msgfmt --check` and the target-specific verifier;
3. install the candidate on the physical workstation;
4. visually inspect the affected UI in Polish;
5. run the full workstation verifier;
6. update the extension-tree integrity lock only after the final accepted live
   tree is known;
7. merge only after the repository source, installed runtime, and integrity lock
   describe the same accepted state.

`scripts/test_localization_consistency.py` enforces metadata invariants and a
small set of reviewed terminology checks. It intentionally does not reject
every cross-catalog wording difference.

# Case Study 3 — GNOME localization and integrity engineering

## Executive summary

A visual localization audit of the Fedora GNOME desktop exposed a small
user-facing problem: some extension names and User Themes preference strings
were still in English.

The resulting engineering work went far beyond replacing text.

The final solution combined:

- exact runtime/source inspection;
- gettext analysis;
- metadata localization;
- SHA-256 fingerprinting;
- fail-closed patching;
- deterministic tree-integrity locks;
- GNOME Shell runtime-cache diagnosis;
- physical visual acceptance;
- full-system verification.

The final workstation acceptance result was:

```text
PASS=258 WARN=0 FAIL=0 SKIP=0
```

## Initial problem

User Themes v79 / 50.4 displayed:

```text
User Themes
Themes
Default
```

Source inspection showed two different localization paths:

- `Themes` and `Default` were literal strings in `prefs.js`;
- the preferences window title came directly from
  `extension.metadata.name`.

That meant a gettext-only fix could never localize the complete visible UI.

## User Themes remediation

The accepted implementation uses:

- gettext wrapping for `Themes` and `Default`;
- a minimal Polish runtime catalog;
- a version-pinned metadata patch for the extension name and description;
- pristine backups;
- exact source fingerprints;
- reconstruction-based verification.

The final UI was visually confirmed as:

```text
Motywy użytkownika
Motywy
Domyślny
```

Accepted User Themes tree SHA-256:

```text
fe416a5c49f9ecdb00a2758a4f552feba34d69a61a55eb9b545d8f7ffe627414
```

## Selective display-name policy

The successful User Themes metadata path was then generalized carefully.

The project does not translate every extension title. It distinguishes between:

- descriptive names that can be localized;
- project or brand names that should remain unchanged.

Ten descriptive extension names were selected:

| Original | Polish |
| --- | --- |
| Add to Desktop | Dodaj do pulpitu |
| Advanced Media Controller | Zaawansowany kontroler multimediów |
| Bluetooth Battery Meter | Wskaźnik baterii Bluetooth |
| Brightness control using ddcutil | Sterowanie jasnością przez ddcutil |
| Browser Switcher | Przełącznik przeglądarki |
| Clipboard Indicator | Wskaźnik schowka |
| Desktop Icons NG (DING) | Ikony pulpitu NG (DING) |
| Just Another Search Bar | Dodatkowy pasek wyszukiwania |
| Monitor Smart Saver | Oszczędzanie energii monitora |
| Removable Drive Menu | Menu nośników wymiennych |

Names intentionally left unchanged include ArcMenu, GSConnect, Dhruva, Vitals,
ddterm, Space Bar, Spotlight and Tiling Shell.

## Fail-closed metadata manager

The shared display-name manager records:

- UUID;
- runtime version;
- version-name where present;
- pristine `metadata.json` SHA-256;
- original display name;
- managed Polish display name.

It accepts only two states:

1. the exact pristine metadata file;
2. the exact managed form produced by changing only the `name` field.

Unknown same-version metadata is rejected.

This matters because a declared extension version alone does not prove that the
runtime file is the audited file.

## Unexpected runtime failure

Immediately after the metadata edits, Extension Manager showed empty extension
sections and a generic error.

The first hypothesis could have been that one of the JSON files had been
broken. Instead of rolling back immediately, read-only evidence was collected.

The diagnostics showed:

- `gnome-extensions list` still returned the installed extensions;
- all ten managed `metadata.json` files parsed successfully;
- all ten files contained the intended Polish names;
- the journal recorded the GNOME Shell Extensions D-Bus peer disconnecting.

After Extension Manager restarted, the list returned but the names were still
English.

A direct comparison then produced the key evidence:

```text
DISK:  Dodaj do pulpitu
GNOME: Add to Desktop
```

The same pattern existed for all ten managed extensions.

This separated file correctness from GNOME Shell runtime state.

## Root cause and recovery

A full GNOME session logout/login forced the shell to reload extension
metadata.

After login:

- the Polish names appeared correctly;
- the dedicated display-name verifier passed;
- the edited files remained valid;
- no rollback was needed.

The important lesson was that the observed UI state came from cached runtime
metadata rather than the current on-disk file.

## Integrity promotion

Changing `metadata.json` correctly caused the whole-tree integrity hashes to
change.

The project did not update the locks first and then assume the new state was
valid.

The sequence was:

```text
candidate change
      ↓
physical installation
      ↓
visual validation
      ↓
dedicated verifier
      ↓
new tree hash measurement
      ↓
accepted tree-lock promotion
      ↓
full verifier
```

The final extension-tree verifier passed all 22 enabled user extensions.

## Unrelated drift discovered during acceptance

The full verifier also found two changes unrelated to the localization work:

- Space Bar appearance CSS had drifted;
- Dhruva had gained an extra `org.gnome.Settings.desktop` dock item.

Those values were restored from repository desired state instead of being
folded into the localization PR.

This kept the acceptance boundary clean.

## Final acceptance

After restoring the unrelated drift and returning the machine to the intended
Wi-Fi validation state:

```text
GNOME audit:
PASS=78 WARN=0

Full physical verifier:
PASS=258 WARN=0 FAIL=0 SKIP=0
```

All affected tree hashes were accepted only after this sequence.

## Why this case study matters

The visible symptom was "some names are in English", but the work demonstrates
several broader engineering skills:

- source-level debugging;
- gettext and GNOME metadata understanding;
- controlled patching;
- fingerprint-based drift detection;
- runtime vs on-disk state analysis;
- D-Bus/journal diagnostics;
- deterministic integrity verification;
- disciplined separation of intended changes from unrelated drift;
- physical acceptance testing.

## Interview version

> I was fixing incomplete GNOME extension localization, but I treated it as a
> configuration-integrity problem rather than a text-editing task. I pinned
> exact metadata fingerprints, allowed only pristine or exact managed states,
> and tied the result into whole-tree SHA-256 verification. During validation
> Extension Manager failed and later showed stale English names even though the
> files were already Polish. By comparing disk state with
> `gnome-extensions info` and checking the journal, I separated a D-Bus/cache
> issue from file corruption. A full GNOME session reload confirmed the root
> cause, and only then did I promote the new integrity hashes.

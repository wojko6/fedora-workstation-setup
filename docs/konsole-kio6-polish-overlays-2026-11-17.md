# Konsole 26.08.3 and KIO6 — Polish menu overlays (2026-11-17)

> **Acceptance:** the operator confirmed that the relevant Konsole context-menu labels now work in Polish on the physical Fedora 45 KDE/Wayland workstation. This is **bounded UI acceptance**, not a complete Konsole/KIO6 localization audit, system-package change, Fedora 45 clean-room restore test or universal compatibility claim.
>
> **Deployment model:** two independent, reversible user-local GNU gettext `.mo` overlays. RPM-owned files in `/usr/share/locale/` remain untouched.

## Environment and evidence

- Target application: `konsole 26.08.3`, RPM `konsole-26.08.3-1.fc45.x86_64`.
- Locale: `LANG=pl_PL.UTF-8`; `LANGUAGE` empty, `LC_MESSAGES` unset.
- System catalogs present: `/usr/share/locale/pl/LC_MESSAGES/konsole.mo`, `kio5.mo`, `kio6.mo`.
- Initial issue: the Konsole context menu mixed an awkward translation (`Split View` → `Widok podzielony`) and English `Open Folder With`.
- The original `kio5.mo` had a Polish `@title:menu | &Open Folder With` entry, while the installed `kio6.mo` did not have that exact singular/context key. KIO6 uses contextual singular/plural message IDs for this menu entry.
- Evidence: operator-pasted read-only GNU gettext audits, the installed Konsole overlay SHA-256 and manifest, and an explicit final statement that the corrected UI **works**. No post-deployment KIO6 host SHA-256/manifest dump has been provided.

## Konsole overlay v0.1 — five reviewed replacements

| Source message | Original Polish | Localized value |
| --- | --- | --- |
| `Split View` | `Widok podzielony` | `Podziel widok` |
| `Clear Scrollback` | `Wyczyść przewijanie wstecz` | `Wyczyść historię przewijania` |
| `Adjust Scrollback...` | `Dostosuj przewijanie wstecz...` | `Ustawienia historii przewijania…` |
| `@title:window | Adjust Scrollback` | `Dostosuj przewijanie wstecz` | `Ustawienia historii przewijania` |
| `Scrollback:` | `Przewijanie wstecz:` | `Historia przewijania:` |

The exact context is preserved in gettext (`msgctxt\x04msgid`) where applicable.

Operator-reported, verified-on-host Konsole catalog fingerprints:

| Artifact | SHA-256 |
| --- | --- |
| RPM-owned `konsole.mo` input | `90d318ae737a41bef5038948eefda02951f99089824c9dcdb6a3d213e71b132a` |
| User overlay `konsole.mo` | `2b86353d497c748dc9da39ba3996c028562100abf2f8c7934085c9130920e100` |

The operator read back the user-local overlay and obtained `MATCHES_V01=True`; the manifest identified `konsole_pl_overlay_v01` with `replacements: 5`.

## KIO6 overlay v0.1 — contextual plurals

Two additional gettext entries are added to the locally copied `kio6.mo`, each retaining **three Polish plural forms**:

| Source / context | Singular translation | Plural translation |
| --- | --- | --- |
| `@title:menu | &Open Folder With / &Open Folders With` | `&Otwórz katalog w` | `&Otwórz katalogi w` |
| `@action:inmenu | &Open Folder With… / &Open Folders With…` | `&Otwórz katalog w…` | `&Otwórz katalogi w…` |

For both entries the second and third Polish plural forms use the plural value above. The leading `&` preserves Qt/KDE mnemonic handling. This overlay affects shared KIO6 translations, not exclusively Konsole, and therefore must be checked after relevant framework updates.

The KIO6 physical UI fix was explicitly accepted by the operator. **KIO6 source/overlay SHA-256 values are not yet recorded from the host**; do not infer them from the Konsole hash or claim a KIO6 post-install hash audit passed.

## Artifacts, script fingerprints and ownership

| Item | User-local location / exact filename |
| --- | --- |
| Konsole installer script | `konsole_pl_overlay_v01.py` |
| KIO6 installer script | `kio6_pl_open_folder_overlay_v01.py` |
| Konsole overlay | `$HOME/.local/share/locale/pl/LC_MESSAGES/konsole.mo` |
| KIO6 overlay | `$HOME/.local/share/locale/pl/LC_MESSAGES/kio6.mo` |
| Konsole managed manifest | `$HOME/.local/share/konsole-pl-overlay/manifest.json` |
| KIO6 managed manifest | `$HOME/.local/share/kio6-pl-open-folder/manifest.json` |

SHA-256 of the **exact Python scripts supplied for this session**, computed from retained local artifacts (these are script hashes, **not** KIO6 catalog hashes):

```text
589a26952e95eb5845243296f17087d9fda6caa71c43707aecd1ea97177b3bed  konsole_pl_overlay_v01.py
4f182da9ece279bdd35a60a8d69c40c47a1d7067ef802d362fc77e5f8f4a842a  kio6_pl_open_folder_overlay_v01.py
```

These Python files are **not currently committed to this repository**; the fingerprints document the reviewed, user-delivered artifacts rather than promising a repository-managed installer. Retain the original script files alongside this record for disaster recovery.

## Verification and use on the existing workstation

The operator has **already deployed both overlays**. Do not re-run `--apply` against them: both installers deliberately reject an existing destination or manifest.

```bash
sha256sum "$HOME/Pobrane/konsole_pl_overlay_v01.py" \
          "$HOME/Pobrane/kio6_pl_open_folder_overlay_v01.py"

python3 -B "$HOME/Pobrane/konsole_pl_overlay_v01.py" --self-test
python3 -B "$HOME/Pobrane/konsole_pl_overlay_v01.py" --audit
python3 -B "$HOME/Pobrane/kio6_pl_open_folder_overlay_v01.py" --self-test
python3 -B "$HOME/Pobrane/kio6_pl_open_folder_overlay_v01.py" --audit

sha256sum /usr/share/locale/pl/LC_MESSAGES/konsole.mo \
          "$HOME/.local/share/locale/pl/LC_MESSAGES/konsole.mo" \
          /usr/share/locale/pl/LC_MESSAGES/kio6.mo \
          "$HOME/.local/share/locale/pl/LC_MESSAGES/kio6.mo"
cat "$HOME/.local/share/kio6-pl-open-folder/manifest.json"
konsole --separate
```

Verify both `Podziel widok` and the Polish `Otwórz katalog w` context-menu label in a newly started Konsole process. In earlier tests the Konsole catalog matched v0.1 byte-for-byte; the KIO6 host catalog hash remains a documentation follow-up.

## Fresh installation — **only** on a compatible, unmodified baseline

1. Verify the installed Konsole/KIO6 versions, Polish locale, current system catalog fingerprints and the script SHA-256 values listed above; obtain both original scripts before starting. Do **not** assume arbitrary Fedora/KDE updates preserve exact message IDs or catalog content.
2. Run `--self-test` and `--audit` for both scripts first. Stop if the system Konsole catalog differs from its documented fingerprint, either user-local destination/manifest already exists, expected source translations differ, or the KIO6 two new contextual plural keys already exist upstream.
3. Only after those gates pass, run:

```bash
python3 -B "$HOME/Pobrane/konsole_pl_overlay_v01.py" --apply
python3 -B "$HOME/Pobrane/kio6_pl_open_folder_overlay_v01.py" --apply
konsole --separate
```

No `sudo`, RPM package edit, Plasma restart or deletion of an unrelated locale file is necessary. The scripts create their own user-local manifests and refuse to overwrite unmanaged destinations.

## Guarded rollback

Only remove overlays installed by the same versioned script, with its manifest and overlay hash unchanged. Roll back KIO6 and Konsole independently:

```bash
python3 -B "$HOME/Pobrane/kio6_pl_open_folder_overlay_v01.py" --restore
python3 -B "$HOME/Pobrane/konsole_pl_overlay_v01.py" --restore
konsole --separate
```

A missing manifest, mismatched owner/metadata, modified catalog or unexpected user-local file should be investigated rather than deleted manually. The scripts remove **only their own** user-local catalog and manifest; the RPM-owned Polish catalogs remain in place. Opening a new process is required to re-check effective gettext translations.

## Maintenance and acceptance boundary

- **PASS (operator-reported, bounded):** Konsole menu wording, including the KIO6-backed folder-open action.
- **PASS (operator-provided hash evidence):** the Konsole catalog/manifest matches v0.1.
- **NOT YET RECORDED:** KIO6 host source/overlay SHA-256 and final manifest readback.
- **NOT TESTED:** every Konsole/KIO6 menu variant, multi-folder plural behavior across applications, clean-room restore and full Fedora 45/KDE verifier.
- On an update to Konsole or KDE Frameworks, re-audit system source strings, KIO6 plural/context keys, system catalog hashes and any existing user overlay before replacing or removing anything. A user-local catalog can shadow new upstream translations.
- Keep Fedora 45/KDE fully reproducible baseline **HOLD** pending a separate clean-room restore and full verifier run. This localized UI acceptance does not alter historical GNOME baseline counts.

## Related records

- [KDE Polish localization audit (2026-11-10)](kde-localization-audit-2026-11-10.md)
- [Localization status](LOCALIZATION-STATUS.md)
- [Worklog (2026-11-17)](WORKLOG-2026-11-17.md)

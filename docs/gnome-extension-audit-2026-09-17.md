# GNOME extension runtime audit — 2026-09-17

Physical-workstation validation and cleanup after the Lau-inspired GNOME refresh.

## Environment

- Fedora 44
- GNOME Shell 50.4
- Wayland session
- Physical Lenovo Legion 5 workstation

## Audit method

The refresh was not promoted directly into desired state. New extensions were first tracked as candidates and tested with `scripts/audit-extension-runtime.sh`. The audit checked installation/runtime state, declared GNOME compatibility, the Dhruva/Dash2Dock conflict, and GSConnect D-Bus/firewalld health.

After ArcMenu was enabled, the candidate-stage audit completed with:

```text
PASS=32 WARN=1 FAIL=0 INFO=5
```

The only remaining warning was Media Controls, which reported `OUT OF DATE` and did not declare GNOME 50 compatibility.

## Accepted extensions at audit close

The following extensions were active on the physical Fedora workstation, declared GNOME 50 compatibility, and were promoted into `gnome/enabled-extensions.txt` at the close of this audit:

- ArcMenu (`arcmenu@arcmenu.com`)
- Bluetooth Battery Meter (`Bluetooth-Battery-Meter@maniacx.github.com`)
- Caffeine (`caffeine@patapon.info`)
- Freon (`freon@UshakovVasilii_Github.yahoo.com`)
- GSConnect (`gsconnect@andyholmes.github.io`)
- Tiling Shell (`tilingshell@ferrarodomenico.com`)
- User Themes (`user-theme@gnome-shell-extensions.gcampax.github.com`)

These are third-party GNOME Shell extensions. Their upstream authorship and licenses remain separate from this repository; this project records integration, configuration, validation, selected localization, and reproducibility work.

## Rejected and removed extensions

### Media Controls

`mediacontrols@cliffniff.github.com` was installed as version 47 but declared GNOME 46–49 compatibility only. GNOME Shell reported it as `OUT OF DATE` on GNOME 50. It was not promoted into desired state and was subsequently uninstalled from the physical workstation.

### Dash2Dock Animated

`dash2dock-lite@icedman.github.com` declared GNOME 50 compatibility, but it was intentionally rejected because Dhruva is the canonical dock. Running both produced duplicate docks. Dash2Dock Animated was disabled and then uninstalled.

## GSConnect validation

GSConnect passed the workstation-side integration checks:

- GNOME Shell extension: `ACTIVE`
- user D-Bus service: registered
- D-Bus introspection: successful
- firewalld: `kdeconnect` service allowed in the active Wi-Fi zone (`public`)

The earlier `ServiceUnknown` condition was resolved after the required GNOME session refresh. The restore workflow therefore treats a sign-out/sign-in as a normal post-install registration step for newly installed GNOME extensions where required.

Android KDE Connect may bypass Tailscale using Android app-based split tunneling when local-LAN interoperability is desired. That phone-side policy is intentionally outside Fedora desired state.

## Desired-state drift resolved during the refresh

The physical audit also identified legitimate configuration changes that were incorporated into the accepted state rather than overwritten blindly:

- Mutter overlay key: `Super_L`
- Just Perfection clock position: right (`clock-menu-position=1`)
- Dhruva dock state: stale `folder:software-folder` entry replaced by `org.gnome.Ptyxis.desktop`

Dhruva v17 remained active and passed the repository's localization checks, including the 20-patch gettext integration and generated 1907-entry Polish CLDR emoji data.

## Inventory reproducibility

The first post-refresh inventory generation exposed the concrete local home path in extension locations. `scripts/inventory-extensions.sh` was corrected before acceptance so that it:

- normalizes user-extension paths to `~/.local/...`;
- prefers the user copy when a UUID exists both per-user and system-wide;
- removes duplicate UUID rows;
- sorts output deterministically for stable reviewable diffs.

The inventory was regenerated after Media Controls and Dash2Dock Animated were removed and then committed as the accepted physical-host extension inventory.

## Final verification of the refresh

After promotion of the seven accepted extensions, desired-state updates, removal of the rejected extensions, and inventory regeneration, the full physical-workstation verifier completed with:

```text
PASS=217 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the historical accepted Fedora 44 / GNOME 50.4 physical-host result for the extension-refresh checkpoint itself.

## Subsequent same-day desired-state changes

After this audit was closed, two deliberate changes were made:

1. **Freon was removed** from the workstation and from `gnome/enabled-extensions.txt` / `gnome/extensions-inventory.tsv`. Its earlier acceptance above remains part of the historical audit record, but it is no longer in current desired state.
2. **Advanced Media Controller v31 / 6.5** (`advanced-media-controller@sanjai.com`) was physically tested, added to desired state, and given a complete repository-managed Polish gettext catalog for its exact tested build.

The last completed full physical verifier after Freon removal but before the final Advanced Media Controller/localization wiring reported:

```text
PASS=214 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

A newer aggregate must be recorded after the final localization-integrated verifier run; see `PROJECT-STATUS.md` and `docs/LOCALIZATION-STATUS.md` for the current state.

## Status

**CLOSED / HISTORICAL CHECKPOINT.** The candidate queue is historical. Current desired state is defined by `gnome/enabled-extensions.txt`, `gnome/extensions-inventory.tsv`, and the live verifier rather than by freezing the extension list at this audit checkpoint. Future extension additions or GNOME upgrades must repeat compatibility/runtime validation before changing desired state.

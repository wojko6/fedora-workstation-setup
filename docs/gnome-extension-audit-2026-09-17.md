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

## Accepted extensions

The following extensions were active on the physical Fedora workstation, declared GNOME 50 compatibility, and were promoted into `gnome/enabled-extensions.txt`:

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

## Final verification

After promotion of the seven accepted extensions, desired-state updates, removal of the rejected extensions, and inventory regeneration, the full physical-workstation verifier completed with:

```text
PASS=217 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

This is the accepted Fedora 44 / GNOME 50.4 physical-host result for the 2026-09-17 extension refresh.

## Status

**CLOSED / ACCEPTED.** The candidate queue is historical. Future extension additions or GNOME upgrades must repeat compatibility/runtime validation before changing `gnome/enabled-extensions.txt`.

# GNOME extension runtime audit — 2026-09-17

Physical workstation validation after the Lau-inspired GNOME refresh.

## Environment

- GNOME Shell 50.4
- Wayland session
- Physical Fedora workstation

## Result

- PASS: 32
- WARN: 1
- FAIL: 0
- INFO: 5

The accepted pre-existing desired-state extensions were active and compatible with GNOME 50.

## Newly tested extensions

The following refresh candidates were ACTIVE and declared GNOME 50 compatibility during the physical-host audit:

- ArcMenu (`arcmenu@arcmenu.com`)
- Bluetooth Battery Meter (`Bluetooth-Battery-Meter@maniacx.github.com`)
- Caffeine (`caffeine@patapon.info`)
- Freon (`freon@UshakovVasilii_Github.yahoo.com`)
- GSConnect (`gsconnect@andyholmes.github.io`)
- Tiling Shell (`tilingshell@ferrarodomenico.com`)
- User Themes (`user-theme@gnome-shell-extensions.gcampax.github.com`)

## Unsupported candidate

Media Controls (`mediacontrols@cliffniff.github.com`) reported `OUT OF DATE` and did not declare GNOME 50 compatibility. It remains outside accepted desired state.

## Dock conflict validation

Dhruva was ACTIVE and remains the canonical dock. Dash2Dock Animated was installed but not active (`INITIALIZED`). Running both had previously produced duplicate docks, so Dash2Dock Animated remains intentionally excluded from desired state.

## GSConnect validation

GSConnect passed all workstation-side health checks:

- GNOME Shell extension: ACTIVE
- D-Bus service: registered
- D-Bus introspection: successful
- firewalld: `kdeconnect` service allowed in the active Wi-Fi zone (`public`)

Android KDE Connect may bypass Tailscale through Android app-based split tunneling. That phone-side policy is intentionally not stored as Fedora desired state.

## Reproducibility note

The first post-refresh inventory generation exposed the concrete local home path in extension locations. `scripts/inventory-extensions.sh` was corrected to normalize user-extension locations to `~` and to produce stable, deterministic UUID-sorted output before the refreshed inventory is committed.

## Next step

Regenerate `gnome/extensions-inventory.tsv` with the corrected inventory script, review the diff, then promote the validated candidates into `gnome/enabled-extensions.txt`. Media Controls and Dash2Dock Animated must remain outside accepted desired state unless a later audit changes that decision.

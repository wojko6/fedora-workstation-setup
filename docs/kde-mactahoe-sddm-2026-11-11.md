# Fedora 45 / Plasma 6.8.2 — MacTahoe SDDM login manager (2026-11-11)

> Evidence: operator-supplied console output and real-boot photographs on the physical workstation, plus upstream QML inspection. No remote host access, reproducible installation test, CI-based runtime check or independent rollback exercise is claimed.
> Scope: the **running** Fedora 45 KDE Wayland desktop; this is **not** promotion of the historical Fedora 44/GNOME clean-room restore baseline.

## Outcome

The physical workstation switched from GDM to **SDDM 0.21.0** using a locally adapted MacTahoe Qt 6 greeter, `Fedora-MacTahoe-v04`. The operator subsequently **logged in successfully** and reported:

~~~text
systemctl is-enabled sddm.service  -> enabled
systemctl is-active sddm.service   -> active
XDG_CURRENT_DESKTOP                -> KDE
XDG_SESSION_TYPE                   -> wayland
LANG / LC_MESSAGES                 -> pl_PL.UTF-8
~~~

Real boot photography confirmed the themed login screen on the external DisplayPort monitor, Polish date, power labels, visible account selection and `Sesja: Plasma`. The login transition to KDE Wayland succeeded; no complete stress or clean-room test was performed.

## Implementation and sources

- **Origin:** [vinceliuice/MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde), `sddm/MacTahoe-6.0`. The upstream artwork and QML remain the original author's work. The local modifications are **not** a claim of an upstream release or a published fork.
- **Compatibility:** Plasma 6.8 removed the QML `VirtualKeyboardLoader` type used by the upstream theme; see [upstream issue #21](https://github.com/vinceliuice/MacTahoe-kde/issues/21). The local lab/staged v0.4 variant omitted the obsolete virtual-keyboard path, adapted hard-coded icon references for the staged theme name and provided Polish UI labels. The original virtual keyboard was **not** validated.
- **Pre-deployment:** `sddm-0.21.0-16.fc45.x86_64`, `sddm-kcm-6.8.2-1.fc45.x86_64`, and `sddm-wayland-plasma-6.8.2-1.fc45.noarch` were installed without removing GDM. Separate `sddm-greeter-qt6 --test-mode` previews confirmed QML rendering and manual switching from GNOME to Plasma in the selector; they did **not** prove authentication.
- **Theme:** files staged at `/usr/share/sddm/themes/Fedora-MacTahoe-v04/`; selected by `/etc/sddm.conf.d/60-fedora-mactahoe.conf` using `[Theme] Current=Fedora-MacTahoe-v04`.
- **Wayland greeter:** package configuration `/usr/lib/sddm/sddm.conf.d/plasma-wayland.conf` sets `DisplayServer=wayland` and launches KWin Wayland with `--no-global-shortcuts --no-lockscreen --inputmethod plasma-keyboard --locale1`. The existing `/etc/sddm.conf` had no conflicting values among the inspected keys.
- **Display:** the user-session output configuration identified external `DP-1` at **2560×1440 @ 180 Hz**, with built-in `eDP-1` disabled. The operator copied the validated KWin output JSON to the SDDM service account's home configuration (with `sddm:sddm` ownership), and verified that a file was present before the switch. The later boot photo confirmed the login screen appeared on the external monitor. A disconnected external display remains a recovery consideration.
- **Migration:** after staging checks and backup, the operator enabled SDDM with `systemctl enable --force sddm.service` for the next boot rather than stopping GDM during the active session. The next successful boot/login confirmed SDDM became the enabled and active manager.

## First-boot caveat

At the first documented reboot after switching, the display showed **Plasma Setup** rather than the themed login screen. A conditional check of `plasma-setup.service` and `/etc/plasma-setup-done` was recommended. A later real-boot photograph showed the MacTahoe SDDM greeter, and login then succeeded. Because the intermediate terminal verification was not supplied, **do not assert which command resolved the setup screen** or treat the setup service as the confirmed root cause. Never skip legitimate initial account provisioning on a fresh installation.

## Logs and appearance

Two `sddm-helper` warnings reported locale `C` with ASCII encoding; Qt automatically selected `C.UTF-8` for those helper processes. The system and user locale were separately verified as `pl_PL.UTF-8`. No login failure was associated with these messages; no global locale workaround was applied.

The real greeter showed a white account avatar and brighter cyan password-field styling than the test preview. These are **cosmetic follow-ups**, not blockers. Power-button actions (sleep, reboot, shutdown), password-rejection UI and session persistence across multiple boots were **not independently tested**.

## KScreenLocker visual follow-up — separate from SDDM

KScreenLocker is the KDE **session lock screen** and is independent of the SDDM login greeter. The operator chose the MacTahoe background in Plasma's Screen Locking appearance settings and supplied a photograph showing the Tahoe wallpaper, clock, Polish date and password prompt. The operator clarified that the avatar **is gold** (its lighter appearance was a camera artifact) and explicitly accepted the lock screen as-is. No custom lock-screen QML, changes to authentication, or additional styling patches were authorized or deployed. This is visual acceptance only, not a tested multi-cycle unlock/resume or clean-room restoration.

**Gate:** `KSCREENLOCKER_TAHOE_VISUAL=PASS_OPERATOR`, `KSCREENLOCKER_FURTHER_CHANGES=NONE`.

## Recovery and gates

Keep the earlier GDM installation and the operator's local pre-switch backup outside Git. If a future SDDM change prevents login, switch to a text TTY (often `Ctrl+Alt+F3`) and, from an authenticated administrator shell, restore GDM:

~~~bash
sudo systemctl disable sddm.service
sudo systemctl enable --force gdm.service
sudo reboot
~~~

This is a **documented recovery procedure, not an exercised rollback**. The upstream installation script was not run as an unreviewed system-wide desktop replacement. Theme source, the backup archive and per-host output JSON are deliberately **not committed** to this repository.

**Decision:** `SDDM_REAL_LOGIN=PASS_OPERATOR_PHYSICAL`; `SDDM_WAYLAND_DP1=PASS_OPERATOR_PHYSICAL`; `SDDM_QML_PREVIEW=PASS_OPERATOR_UI`; `SDDM_ROLLBACK=DOCUMENTED_NOT_TESTED`; `FEDORA45_KDE_REPRODUCIBLE_RESTORE=HOLD`.

## Related records

- [Worklog — 2026-11-11](WORKLOG-2026-11-11.md)
- [Project status](../PROJECT-STATUS.md)
- [Upgrade / restore validation](UPGRADE.md)
- [Upstream MacTahoe Plasma 6.8 issue](https://github.com/vinceliuice/MacTahoe-kde/issues/21)

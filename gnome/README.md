# GNOME configuration

This directory contains a sanitized, reproducible subset of the current GNOME configuration.

Do not commit the raw `dconf dump /` output. The source inventory contains transient state such as recent directories, window geometry, timestamps, command history, and location/weather data that is not required to reproduce the desktop.

The reviewed configuration should cover, where applicable:

- GNOME interface and window-manager preferences
- favorite applications and app-grid layout
- enabled extension list
- extension settings (including Space Bar custom CSS)
- Blur My Shell settings
- Dhruva dock settings
- Just Perfection settings
- relevant keybindings

`enabled-extensions.txt` is accepted desired state. Extensions introduced during experiments must not be added there until they have been validated on the physical Fedora workstation.

`extension-candidates-lau.txt` tracks the extensions introduced by the 2026-09-17 Lau-inspired desktop refresh while that validation is in progress. Run:

```bash
bash scripts/audit-extension-runtime.sh
```

The runtime audit compares accepted desired state, the candidate set, and every extension currently installed on the machine. It also checks the Dhruva/Dash2Dock conflict and GSConnect D-Bus/firewalld health. After the physical audit is accepted, retained candidates can be promoted into `enabled-extensions.txt` and the extension inventory/settings can be refreshed.

Dhruva remains the canonical dock. Dash2Dock Animated is intentionally excluded from desired state because running both at the same time creates duplicate docks.

Historical settings for disabled extensions should not be restored unless intentionally selected.

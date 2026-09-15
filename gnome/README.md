# GNOME configuration

This directory will contain a sanitized, reproducible subset of the current GNOME configuration.

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

Historical settings for disabled extensions should not be restored unless intentionally selected.

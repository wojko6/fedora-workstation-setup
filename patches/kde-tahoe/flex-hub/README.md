# Fedora Tahoe — Plasma Flex Hub patches for KDE Plasma 6.8

A set of local patches for [Plasma Flex Hub](https://github.com/zayronxio/Plasma.Flex.Hub), tested on **Fedora 44 / KDE Plasma 6.8.2 / Wayland** on November 10, 2026.

## Included patches

| File | Purpose |
|---|---|
| `0001-szerokosc-panelu-360.patch` | Expand the control-center popup to approximately 360 px while retaining the separate editing layout |
| `0002-podpowiedzi-wifi-bluetooth.patch` | Show the full Wi-Fi SSID or Bluetooth device name in a tooltip on hover |
| `0003-zgodnosc-jasnosci-plasma-6-8.patch` | Replace an exact `6.4` text check with version detection supporting Plasma 6.4 and later |
| `0004-bezwzgledne-ustawianie-jasnosci.patch` | Set an absolute brightness percentage instead of sending individual increase/decrease steps |
| `Fedora-Tahoe-FlexHub-all.patch` | Combined patch containing all four changes |

The filenames are retained from the original verified local bundle (and therefore contain Polish words). Their **contents have not been modified** for publication.

`SHA256SUMS` verifies the five original `.patch` files byte-for-byte. `manifest.json` records SHA-256 hashes of the seven affected source files before and after patching, with workstation-specific absolute paths omitted.

## Applying to a compatible version

**Do not apply these patches to an already modified widget installation.** Before using them with a newer upstream release, review its changes and confirm that these fixes have not already been integrated. Do not use `--force`.

From the root of a clone of this repository:

```bash
cd patches/kde-tahoe/flex-hub
sha256sum -c SHA256SUMS

WIDGET="$HOME/.local/share/plasma/plasmoids/Plasma.Flex.Hub"
test -d "$WIDGET" || exit 1
cp -a "$WIDGET" "$WIDGET.backup-$(date +%Y%m%d-%H%M%S)"

# First compare SHA-256 hashes of the seven source files with
# the sha256_before entries in manifest.json.
patch --dry-run -p1 -d "$WIDGET" < Fedora-Tahoe-FlexHub-all.patch

# Only after a successful dry run and verification of the base version:
patch -p1 -d "$WIDGET" < Fedora-Tahoe-FlexHub-all.patch
```

After verifying the result, the Plasma shell may be restarted to reload the QML files. Back up the current panel configuration first. Avoid restoring an unrelated old `plasma-org.kde.plasma.desktop-appletsrc` backup: it may reintroduce a removed panel or dock.

## Verification and limitations

- Local patch generator: `VERIFY_ORIGINALS=PASS`, `VERIFY_CURRENT_PATCHED_FILES=PASS`, and `COMBINED_PATCH=PASS`.
- Local integrity check: `sha256sum -c SHA256SUMS` succeeded for all five `.patch` files.
- Functional testing on Plasma 6.8.2: Wi-Fi and Bluetooth tooltips worked; the brightness slider could set actual brightness, including 100%.
- These results **do not guarantee compatibility** with later Plasma or Flex Hub releases.
- The patched brightness control still selects the first display reported by the PowerDevil model. Explicit display selection in multi-monitor setups has not been separately validated.

**Provenance:** Verified local bundle `Fedora-Tahoe-FlexHub-Patches-20261110-171157`. The published README and manifest omit workstation-specific backup paths, while all five `.patch` files retain their original verified bytes.

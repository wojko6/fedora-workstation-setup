# Fedora Graphite Design System

> **Status:** proposed living UI standard; not an installed theme or a validated workstation baseline.
>
> **Scope:** Fedora KDE Plasma / Wayland desktop experience, first-party local
> experiments and carefully integrated third-party applications.
>
> **Principle:** create the most coherent and usable Fedora desktop possible.
> Draw on successful macOS interaction patterns, but do not attempt a
> pixel-perfect macOS clone or sacrifice accessibility, stability or Linux
> conventions.

## 1. Vision and decision rules

Graphite is a *system*, not a collection of unrelated Tahoe-looking skins.
A component is successful only when it fits the whole desktop.

Design decisions are evaluated in this order:

1. **Behavioral consistency:** predictable navigation, shortcuts, commands
   and feedback across surfaces.
2. **Accessibility and clarity:** readable typography, visible focus and
   sufficient contrast beat decorative glass effects.
3. **Visual consistency:** matching semantic color, geometry, density,
   elevation and icon treatment.
4. **Native integration and maintainability:** prefer toolkit-supported,
   reversible changes to fragile global stylesheet or shell hacks.
5. **Motion and polish:** use restrained, reliable animations only after
   interaction and rendering quality are established.

Do not copy a macOS behavior solely because macOS has it. Use it when it
improves the local desktop.

## 2. Current scope and evidence boundary

| Surface | Role in Graphite | Evidence/status boundary |
| --- | --- | --- |
| KDE Plasma shell / KWin | Window management, panels, focus, compositing | Active physical KDE pilot; not a promoted reproducible restore baseline |
| Tahoe-inspired theme and icons | Visual starting point | Local customization, not proof of cross-application consistency |
| Global menu in the top panel | Shared menu placement | Locally configured; app-specific support must be checked |
| Krema Dock | Running apps, pinning, minimize interaction | Local UI integration, separate from application internals |
| AppBay | Native Plasma application-grid surface | Bounded activation and grid checks recorded in the [AppBay/Krema evidence](../kde-appbay-krema-launchpad-2026-11-11.md) |
| Flex Hub / utility widgets | Compact system controls | Local patches and behavior require independent verification |
| Finder Graphite | Reference pilot for navigation, toolbar, tab and search behavior | Separately developed local LAB application; **not** a replacement for or modification of system Dolphin |
| GTK / Electron / Flatpak / vendor apps | Cross-toolkit integration targets | No blanket claim of Graphite compliance; assess app by app |

The Fedora repository owns workstation configuration and operational evidence.
Finder Graphite keeps its own implementation/build history. This document owns
*cross-application design decisions*, not a second source of truth for
implementation-specific patches. Future local experiments must not be
described here as deployed until they are observed and validated.

The last fully accepted reproducible desktop baseline and the physically
running KDE pilot remain distinct; see [project status](../../PROJECT-STATUS.md)
and the [roadmap](../../ROADMAP.md). The design system does not promote either
status by itself.

## 3. Visual language: Graphite

### 3.1 Palette

- **Primary:** neutral charcoal / graphite. Never default to purple accents.
- **Accent:** restrained desaturated steel blue for focused or selected states.
- **Semantics:** reserved status colors for success, warning and destructive
  operations; not general decoration.
- **Depth:** separate surfaces primarily with tone, fine borders and spacing;
  avoid multiple competing gradients, heavy shadows and full-screen blur.
- **Contrast:** interface text and icons must remain readable regardless of
  wallpaper or active-window background.

The values below are **candidate design tokens, not assertions about the
currently installed theme**. Verify contrast and visual behavior in the
actual UI before adopting them as a configuration.

| Semantic token | Candidate dark value | Intended use |
| --- | --- | --- |
| background.canvas | #14171A | Main desktop application background |
| background.surface | #1D2227 | Content areas, panels, menus |
| background.raised | #272E35 | Raised controls, popovers |
| background.hover | #323B44 | Transient pointer hover |
| border.subtle | #414B55 | Separators and low-contrast outlines |
| text.primary | #E8EBEE | Primary content |
| text.secondary | #B6C0C8 | Supporting text |
| text.disabled | #87939E | Non-interactive information only |
| accent.steel | #87ACC7 | Selection, active state, focus |
| accent.steel-muted | #354B5C | Filled selected backgrounds |
| feedback.success | #83B99A | Successful result |
| feedback.warning | #E0B778 | Warnings that need attention |
| feedback.error | #E39A9A | Errors and destructive action |

Contrast is judged on the **actual foreground/background pair**, not by the
hex code alone. Aim for WCAG AA text contrast (4.5:1 normal text, 3:1 large
text) and at least 3:1 for essential UI indicators wherever applicable.
Do not use secondary or disabled colors for essential instructions unless
they remain readable. A later light-mode palette needs separate validation;
do not invert these tokens mechanically.

### 3.2 Typography

Use a single system-available sans-serif family across applications where
toolkits permit. Prefer Fedora/KDE-native font rendering and fallback
coverage, including Polish diacritics. Avoid bundling proprietary fonts or
forcing typography globally across incompatible toolkits.

**Proposed reference scale, subject to UI testing:**

| Role | Nominal size | Guidance |
| --- | --- | --- |
| Supporting metadata | 12 px | High enough contrast; never crucial information only |
| Compact control / caption | 13 px | Dense lists, secondary toolbar text |
| Standard body / control | 14 px | Default everyday reading |
| Section title | 16 px | Distinguish groups without over-emphasizing |
| Page title | 20–24 px | Use rarely, only with hierarchy |

Prefer regular and medium weights over excessive bold text. Use consistent
line height, baseline alignment, truncation, ellipsis and keyboard mnemonic
handling. Respect user font scaling and translations rather than enforcing
fixed pixel clipping.

### 3.3 Spacing, geometry and density

Proposed spacing rhythm: **4 / 8 / 12 / 16 / 24 / 32 px**.

Reference dimensions to validate on the actual display:

- compact control height: approximately **30–32 px**;
- standard button / field height: approximately **36 px**;
- prominent action height: approximately **40 px**;
- small control corner radius: **6–8 px**;
- cards, menus and dialogs: **10–12 px** radius where native styling permits;
- consistent icon alignment: match optical center, not only bitmap bounds.

These are *design candidates*, not hard-coded requirements for every toolkit.
Platform-native touch targets, accessibility scaling, text length and layout
constraints take precedence. Density should be consistent *within an
interaction class*: do not stretch every system widget to a Finder-sized
toolbar simply to force identical dimensions.

### 3.4 Icons, elevation and transparency

- Prefer one icon family and consistent optical size for system surfaces.
- Preserve recognizable application branding where replacement harms
  discoverability; do not fake upstream/vendor identities.
- Use regular, active, disabled and warning states consistently.
- Prefer subtle surface differences and a single clear separator over layers
  of borders plus shadows.
- Blur/transparency are optional and must never reduce legibility.
- Avoid white translucent panels over busy wallpapers unless text contrast
  is guaranteed and a fully opaque fallback exists.

## 4. Interaction patterns

### 4.1 Shell and application boundaries

- **Top panel:** system status, global menu where supported and compact
  system controls; avoid duplicating the same app action in several places.
- **Krema Dock:** app launching, running state, minimize/restore and pinned
  apps; no independent second favorites dock in AppBay.
- **AppBay:** launcher/search grid, not a competing dock or another full
  desktop shell.
- **Application chrome:** retain a consistent toolbar and window controls
  without hiding required functionality.

The user should understand which surface owns each action.

### 4.2 Finder Graphite as the reference pilot

Finder Graphite is the initial *design-quality reference*, not the universal
interaction layout for every application. Keep these already agreed
preferences as the reference direction:

- Default Finder layout does **not** show a permanently editable address
  field or an always-visible separate search row.
- Search is opened on demand from the upper toolbar.
- Search offers scopes equivalent to **Current folder / Everywhere**.
- Address/location entry remains accessible on demand, including keyboard
  use; do not remove functionality to simplify appearance.
- Tabs, breadcrumbs, toolbar actions and context menus must have clear
  ownership and avoid unnecessary duplicate commands.
- Multiple open tabs may legitimately display similar tab titles; do not
  treat them as duplicate UI chrome without checking tab state.
- Preserve a neutral graphite theme with modest steel-blue selection/focus
  and no unwanted purple tint.
- Finder-only stylesheet and behavioral changes must remain isolated from
  the stock Dolphin and other KDE applications.

For each Finder interaction accepted in the pilot, record *why* it works and
whether it generalizes. Do not transplant its search scope into apps where
search semantics are fundamentally different.

### 4.3 Commands, navigation, search, dialogs

- Identical actions should use comparable labels, icons and shortcuts.
- Keyboard navigation, tab order, escape/cancel and focus return must be
  predictable.
- Primary action placement should be consistent across comparable dialogs.
- Search must make its **scope** and active filters visible when relevant.
- Destructive operations require clear intent, consequences and safe
  confirmation; avoid ambiguous icon-only affordances.
- Loading, empty, error and success states need distinct, actionable feedback.
- Avoid stacked dialogs, duplicated titles, nested scrolling and unnecessary
  permanent toolbars.

### 4.4 Motion

**Proposed motion ranges for pilot testing:** approximately 120–180 ms for
small control transitions and 180–240 ms for panel/popover transitions.
Animation must be interruptible and must not delay input or create jitter.
Honor reduced-motion settings and prefer an immediate/no-animation fallback.
Do not claim an animation is smooth based solely on the monitor refresh rate.

## 5. Cross-toolkit policy

| Application family | Preferred strategy | Avoid |
| --- | --- | --- |
| Native KDE / Qt | Prefer supported style/theme APIs and native desktop integration | Unscoped changes to Qt runtime or all KDE app styles |
| GTK apps | Native GTK theming and portal-supported behavior as available | Forcing Qt assumptions into GTK widget geometry |
| Electron / Chromium apps | Supported window-decoration and theme options per application | Injecting fragile application patches or overriding vendor CSS globally |
| Flatpak | Portal/theme integration and per-app permissions/overrides | Unreviewed global sandbox permissions or rewriting application contents |
| Custom Finder Graphite | Local stylesheet and targeted behavior with rollback | Replacing the system Dolphin, its assets or MIME ownership implicitly |

Aim for **coherent appearance and behavior**, not impossible byte-for-byte
uniformity across distinct toolkit internals. Any necessary exception must
have an explicit rationale and owner.

## 6. Language, accessibility and resilience

- Use consistent Polish terminology for system and app controls; English
  documentation stays the repository standard.
- Respect [the localization style guide](../../localization/STYLE-GUIDE.md)
  and do not hard-code translated strings into layout assumptions.
- Show visible keyboard focus in steel blue on both dark and raised surfaces.
- Test keyboard-only operation, screen reader semantics where available,
  pointer use, long labels, text scaling and window resizing.
- Preserve contrast under translucency, focus/hover overlap and disabled
  states.
- Avoid icon-only commands when meaning is unclear; provide accessible
  names/tooltips and shortcuts.
- Never disable security controls, portal checks, permission prompts or
  system functionality just to mimic macOS.

## 7. Acceptance and measurement

A change is **PROPOSED**, **LOCALLY TESTED** or **ADOPTED**, never silently
promoted. A screenshot alone proves appearance, not functionality.

**Minimum review matrix per component:**

1. Compare normal, hover, focus, selected, disabled and error states.
2. Confirm pointer and keyboard interaction (including Escape and return
   focus), Polish labels and icon affordances.
3. Test windowed and maximized layouts at common scale factors
   (e.g. 100%, 125%, 150%) where supported.
4. Examine both the internal display and external monitor when applicable;
   record resolution, scale, GPU/session conditions with the test evidence.
5. Confirm menu/popover positioning, clipping, tooltips, high-DPI rendering,
   minimum widths and long text.
6. Inspect CPU/GPU cost and animation stability when changing blur, motion
   or custom rendering; do not infer frame rates without measurements.
7. Verify that stock Dolphin, desktop launchers, KDE panels, Steam and
   unrelated apps still behave normally after the change.
8. Recheck after logout/login, restart and relevant upstream updates before
   claiming persistence.

**Gate definitions:**

| Gate | Meaning |
| --- | --- |
| PROPOSED | Design principle documented; visual and runtime outcomes untested |
| LOCAL PILOT | Scope-limited change with backup and operator-visible test |
| LOCALLY TESTED | Reproducible checks with screenshots/logs and known exceptions |
| ADOPTED | Approved design decision with repeatable restore path and regression tests |
| HOLD | A blocker, regression, security issue or unresolved compatibility risk |

The workstation's overall KDE reproducible-restore acceptance is **not**
automatically achieved when an individual UI pilot reaches ADOPTED.

## 8. Implementation discipline and rollback

- Make changes narrowly scoped: user-level override or isolated LAB build
  first; system-wide style/panel changes only with explicit approval.
- Before a write, preserve original files/configuration and document a
  complete revert procedure.
- Use deterministic artifacts, hashes and short, targeted checks where
  practical. Record environment and upstream revision in *test reports*,
  not as a permanently embedded version requirement in this living spec.
- Preserve external launchers and working menu/widget mappings until the
  replacement is verified. Watch for unstable dynamic Plasma applet IDs.
- Avoid modifying stock Dolphin, vendor packages, upstream sources or Flatpak
  internals as a side effect of Finder Graphite design work.
- Restore all previous behavior on failure; no silent fallback to a
  partially styled or nonfunctional UI.
- Keep local private paths, host identifiers, raw logs and configuration
  secrets out of this public document.

## 9. Delivery sequence

1. **Inventory and screenshots:** establish a consistent baseline of
   Finder, panels, Krema, AppBay, Flex Hub and a representative Qt/GTK/
   Electron/Flatpak app set.
2. **Reference tokens:** approve a neutral palette, text hierarchy, control
   density and icon semantics after accessibility/contrast checks.
3. **Finder Graphite pilot:** refine on-demand search, tabs, navigation,
   toolbar and menu patterns in the isolated LAB.
4. **Shell convergence:** reconcile top panel, global menu, Krema, AppBay and
   utility widgets; remove duplicated affordances, not features.
5. **Cross-toolkit convergence:** use supported per-app settings to reduce
   obvious discrepancies without breaking vendor UI.
6. **Regression and restore:** repeat visual/behavior checks after upstream
   updates; promote reproducible choices only after rollback is proven.

Treat this as an ordered direction, **not authorization to change the live
workstation**. Implementation cadence remains governed by
[the Fedora roadmap](../../ROADMAP.md).

## 10. Decision-record template

For each proposed visual or interaction change, add an implementation-local
record with:

- **Surface and user problem**
- **Current observed behavior / evidence**
- **Proposed Graphite rule and any token override**
- **Reason and alternative considered**
- **Affected toolkit, applications and accessibility risks**
- **Backup, rollback and isolation boundary**
- **Validation result and unresolved exceptions**
- **Status:** PROPOSED / LOCAL PILOT / LOCALLY TESTED / ADOPTED / HOLD

**Final design test:** does the entire desktop feel like one coherent product,
rather than a collection of individually themed components? If not, favor
simplification and behavioral consistency over adding another visual effect.

## Related documentation

- [Documentation index](../README.md)
- [Krema + AppBay native integration evidence](../kde-appbay-krema-launchpad-2026-11-11.md)
- [Polish UI terminology](../../localization/STYLE-GUIDE.md)
- [Fedora project status](../../PROJECT-STATUS.md)
- [Fedora roadmap](../../ROADMAP.md)

# Fedora workstation — documentation consistency reconciliation (2026-11-15)

> **Scope:** public repository documentation only; GitHub source/PR metadata reviewed
> as of 2026-11-15. This is **not** a new live workstation inventory, clean-room
> restore, runtime test, security audit or approval to deploy.
>
> **Evidence precedence:** dated operator-reported observations remain attributed to
> their worklogs. A merged PR proves publication of source, not installation,
> current runtime state or complete verification.

## Current-facing state and evidence

| Topic | Latest supported statement | Primary evidence / remaining gate |
| --- | --- | --- |
| Physical operating system | Fedora 45 / KDE Plasma 6.8.2 / Wayland, NVIDIA 620.70.06, reported and boundedly checked on 2026-11-10 | [Nov 10 worklog](../WORKLOG-2026-11-10.md); [PROJECT-STATUS](../../PROJECT-STATUS.md) |
| Accepted reproducible desktop baseline | Historical Fedora 44 / GNOME Shell 50.5 / Wayland | [PROJECT-STATUS](../../PROJECT-STATUS.md); Fedora 45 KDE clean-room restore and full verifier **HOLD** under [Issue #12](https://github.com/wojko6/fedora-workstation-setup/issues/12) |
| Fedora-only app experiments | OpenNOW 1.0.5 Polish AppImage accepted within app scope on 2026-11-12 | [Nov 12 worklog](../WORKLOG-2026-11-12.md); does not validate Fedora restore |
| Finder Graphite | 2026-11-13/14 pilot and dialog audit recorded in [merged PR #59](https://github.com/wojko6/fedora-workstation-setup/pull/59) | [Nov 13](../WORKLOG-2026-11-13.md), [Nov 14](../WORKLOG-2026-11-14.md); A6588.1 runtime report **PENDING**, default launcher and Fedora restore **HOLD** |
| Local coding-agent laboratory | 2026-10-25 synthetic lab record published in [merged PR #53](https://github.com/wojko6/fedora-workstation-setup/pull/53) | [Oct 25 worklog](../WORKLOG-2026-10-25.md); no production promotion |
| Tailscale firewalld verifier | Runtime-zone target read fix published in [merged PR #20](https://github.com/wojko6/fedora-workstation-setup/pull/20) | Script/test publication only; no new physical firewalld policy acceptance claimed |
| Pending documentation | [PR #57](https://github.com/wojko6/fedora-workstation-setup/pull/57) and [PR #58](https://github.com/wojko6/fedora-workstation-setup/pull/58) remain **open Draft** as of the check | #58 targets the Fedora 45 KDE restore-design feature branch, **not** `main`; do not count these drafts as published current-state evidence |

## Reconciliation decisions

1. Give `PROJECT-STATUS.md` and the root `README.md` an explicitly dated
   navigation note referring to the November 13/14 Finder records while
   preserving the November 10 **physical-host** evidence date.
2. Keep `ROADMAP.md` clear about publication versus promotion and document the
   remaining KDE restore/design gates; historic Fedora 44 preflight sections
   retain their original dates and results.
3. Sort the dated worklog links in `docs/README.md` and explain that the
   GNOME `scripts/verify.sh` procedure documents the **historical** accepted
   desired state, not a completed Fedora 45/KDE verification.
4. Link this report from the documentation index. Do not change any scripts,
   dependencies, launchers, packages, desktop settings or installed applications.

## Validation and publication boundaries

- Review scope: main entry points and relevant linked worklogs and GitHub PR
  state, **not** every Markdown file or every external URL in the repository.
- Relative file links in the updated entry points must resolve within the
  proposed branch and point to the correct historical record.
- Historical Fedora 44/GNOME `PASS=277 WARN=0 FAIL=0 SKIP=0` remains historical;
  do **not** reinterpret it as Fedora 45 acceptance.
- No new on-host, restore, package, GUI, functional, security or vulnerability
  test was run for this documentation-only change.
- Preserve private notes, screenshots, shell histories, personal configuration,
  local paths and machine secrets outside the public repository.
- Re-review the cross-document state after later PR merges, Finder experiments,
  major updates or a real Fedora 45 clean-room test.

**Result:** `DOCUMENTATION_SCOPE=ENTRYPOINT_RECONCILIATION` ·
`CODE_CHANGED=NO` · `PHYSICAL_RUNTIME_VERIFIED=NO` ·
`FEDORA45_CLEAN_ROOM=HOLD` · `REVIEW_BEFORE_MERGE=YES`.

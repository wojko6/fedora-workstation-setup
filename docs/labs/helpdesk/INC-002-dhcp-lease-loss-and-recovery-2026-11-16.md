# INC-002 — DHCP lease loss and network recovery

**Date:** 2026-11-16  
**Category:** Network / IPv4 / DHCP  
**Priority:** P3 (training scenario, not a production SLA classification)  
**Final status:** **RESOLVED — operator-confirmed recovery**  
**Exercise type:** Controlled DHCP client lease release in a VirtualBox NAT guest; **not a real customer incident and not a DHCP server outage**.

## User scenario

> "The computer is connected to the network, but it cannot access the Internet."

The goal was to contrast an IPv4 addressing or lease problem with the DNS-only failure from [INC-001](INC-001-dns-resolution-failure-2026-11-16.md). The operator inspected the guest configuration, deliberately released its DHCP lease, diagnosed the consequences, requested a new lease, and verified recovery.

## Laboratory environment

- Host: Fedora 45, KDE Wayland; VirtualBox **7.2.22**.
- VM: `Helpdesk-DNS-LAB-01`, Debian GNU/Linux **13 (Trixie)**, text-mode console.
- Network: VirtualBox **NAT** (not bridged), guest interface `enp0s3`.
- Baseline guest address: `10.0.2.15/24`; IPv4 default gateway: `10.0.2.2`; DNS: `10.0.2.3`.
- The guest used `dhcpcd`; `/usr/sbin/dhcpcd` and `/usr/sbin/ifup` were present, and `networking.service` was active before the exercise.
- Snapshot `CLEAN-BASELINE` existed from the earlier lab. The independent `Fedora-DR-Test` VM and home router/Pi-hole were not modified.

## Baseline verification

The operator provided console evidence that:

- `dhcpcd` processes were active for `enp0s3`.
- `ping -c 2 -W 2 1.1.1.1` succeeded with **2/2 packets received and zero packet loss**.
- `getent ahostsv4 debian.org` returned IPv4 addresses.
- The guest had `10.0.2.15/24` and a default route via `10.0.2.2`.

## Controlled fault injection

Inside the guest console with root privileges, the operator executed:

```bash
dhcpcd -k enp0s3
```

The output included `sending signal ALRM to pid 727` and `waiting for pid 727 to exit`. The following result was recorded:

```text
RELEASE_EXIT_CODE=0
```

A later console screenshot showed:

- `ip -4 addr show enp0s3` returned **no IPv4 address line**.
- `ip -4 route` returned **no IPv4 routes**.
- `pgrep -a dhcpcd || true` printed **no remaining dhcpcd process**.

**During the outage, the operator also ran an IPv4 ping, and confirms that it failed.** The earlier console output could not be recovered because the VirtualBox text console could not be scrolled to it. Therefore, **the failed ping is operator-reported evidence, not screenshot-captured evidence**; the exact diagnostic message, exit code, sent/received packet counts and timestamps are **not available**. Do not invent them.

This was a **client-side release of a DHCP lease**, not a simulated DHCP server shutdown. We have no evidence that the VirtualBox DHCP service stopped responding.

## Root cause

The lab client released its DHCP lease and exited, removing its configured IPv4 address and default route. As a result, the guest no longer had the IPv4 configuration required for external traffic. This is categorically different from INC-001, where the IP configuration and public IP ping continued to work while hostname resolution failed.

## Remediation and post-fix verification

The operator requested a new lease within the **guest**:

```bash
dhcpcd enp0s3
```

The observed post-fix state was:

| Check | Observed result | Status |
| --- | --- | --- |
| `ip -4 addr show enp0s3` | `enp0s3` UP; `10.0.2.15/24` dynamic | **PASS** |
| `ip -4 route` | Default via `10.0.2.2`; `10.0.2.0/24` on `enp0s3` | **PASS** |
| `ping -c 2 -W 2 1.1.1.1` | **2 transmitted, 2 received, 0% loss**, average approximately **11.2 ms** | **PASS** |
| `getent ahostsv4 debian.org` | Returned multiple IPv4 addresses | **PASS** |
| DNS exit check | `DNS_EXIT_CODE=0` | **PASS** |

During the verification, one `getent ahostsv` invocation produced an "Unknown database" error because the subcommand was mistyped. The corrected `getent ahostsv4 debian.org` then succeeded. The typo was a **command-input error**, not evidence of a continuing network problem.

**Disposition:** `INC-002=RESOLVED` — the guest reacquired its IPv4 address and gateway and passed IP and DNS tests. The fault was induced and remediated without restoring the baseline snapshot.

## Service Desk closure note

**Issue:** Network interface appears active, but IPv4 connectivity fails.  
**Impact:** One laboratory guest loses its DHCP-provided IPv4 configuration.  
**Diagnosis:** After DHCP release, `enp0s3` had no IPv4 address and the guest had no IPv4 route. The operator reports that ping during the outage failed; its exact output was not captured.  
**Root cause:** Deliberately released DHCP lease on the guest, leaving no active client-managed IPv4 address or default gateway.  
**Fix:** Restarted the DHCP client for `enp0s3` and obtained a working lease.  
**Verification:** `10.0.2.15/24` restored, default route via `10.0.2.2`, public IP ping 2/2 with 0% loss, and DNS lookup successful with exit code 0.  
**Status:** Resolved.

## What this proves — and does not prove

This demonstrates a repeatable, bounded **DHCP client lease-loss/reacquisition workflow** and structured L1 diagnosis of addressing versus name resolution. It does **not** demonstrate an outage or repair of a DHCP server, a production SLA response, browser troubleshooting, a longer-term reliability test, or experience handling real customer tickets. Operator-reported ping failure during the induced outage is explicitly separated from screenshot-verifiable facts.

The VirtualBox `CLEAN-BASELINE` snapshot remains a point-in-time VM recovery facility, not an independent backup. All network changes were confined to the Debian guest.

**CV-safe statement:** "Performed a Debian 13/VirtualBox network troubleshooting lab: reproduced a DHCP client lease-loss incident, identified missing IPv4 addressing and routes, reacquired the lease with `dhcpcd`, and validated restored IP/DNS connectivity."

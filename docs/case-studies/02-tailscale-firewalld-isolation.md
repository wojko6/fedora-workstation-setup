# Case Study 2 — Tailscale + firewalld isolation

## Executive summary

A network-security audit found that the Fedora workstation's Tailscale
interface had no dedicated firewalld zone.

The default `FedoraWorkstation` zone allowed broad high-port traffic. A remote
scan from another Tailnet peer proved that locally listening services were
reachable through the Tailscale path.

The final design introduced a dedicated zone:

```text
workstation-tailscale

target: DROP
interface: tailscale0
services: none
ports: none
protocols: none
forward: no
masquerade: no
rich rules: none
```

The change preserved normal outbound Tailscale connectivity while filtering
the tested inbound services.

## Initial observation

The trusted Wi-Fi interface was already assigned correctly:

```text
wlp4s0 -> workstation-kdeconnect
```

Its intended services were limited to:

```text
dhcpv6-client
kdeconnect
mdns
```

The broader default zone still contained a much more permissive policy:

```text
FedoraWorkstation

services:
dhcpv6-client
samba-client
ssh

ports:
1025-65535/udp
1025-65535/tcp

forward: yes
```

The Tailscale interface had no explicit firewalld assignment:

```text
tailscale0 -> no zone
```

That made the fallback path important enough to verify experimentally rather
than treating it as a theoretical configuration concern.

## Evidence collection

Local listener correlation showed, among other services:

```text
GSConnect / gjs
TCP/1716
UDP/1716

Steam
TCP/27036
UDP/27036
```

OpenSSH server was not running and no TCP/22 listener existed.

From a separate Windows Tailnet peer, the Fedora Tailscale address was scanned.

Baseline result:

```text
22/tcp      closed
1716/tcp    open
27036/tcp   open
```

The important finding was not TCP/22. The important finding was that
high-numbered locally listening services were reachable over the Tailnet path.

## Controlled A/B test

Before making a permanent change, `tailscale0` was temporarily placed in the
restrictive firewalld `block` zone.

Outbound Tailscale connectivity remained operational:

```text
tailscale ping desktop-rrbnrq3
-> pong
```

The same remote scan then changed to:

```text
22/tcp      filtered
1716/tcp    filtered
27036/tcp   filtered
```

This produced a direct before/after result:

```text
broad fallback -> services reachable
restrictive interface zone -> tested services filtered
```

The A/B test provided causal evidence before the configuration was made
persistent.

## Permanent design

Instead of modifying the default Fedora zone globally, the hardening was scoped
to the Tailscale interface.

The repository added a dedicated exact-state policy:

```text
workstation-tailscale
target: DROP
interfaces: tailscale0
services: none
ports: none
protocols: none
forward: no
masquerade: no
rich rules: none
```

After reload:

```text
wlp4s0     -> workstation-kdeconnect
tailscale0 -> workstation-tailscale
tailscale ping Windows -> PASS
```

The remote scan remained filtered for the tested ports.

## Reboot persistence

The workstation was rebooted to ensure the result was not only a runtime
artifact.

Post-reboot validation confirmed:

```text
wlp4s0     -> workstation-kdeconnect
tailscale0 -> workstation-tailscale
tailscale status -> healthy peer visibility
tailscale ping Windows -> PASS

22/tcp      filtered
1716/tcp    filtered
27036/tcp   filtered
```

## Reproducible implementation

The accepted state was promoted into repository-managed automation and tests:

```text
network/tailscale-firewall-zone.sh
install.sh
scripts/verify-security-posture.sh
scripts/test_tailscale_firewall_policy.py
scripts/test_verify_security_posture.py
scripts/check-static.sh
```

The dedicated security posture verifier ultimately completed at:

```text
PASS=62 WARN=0 FAIL=0 SKIP=0
```

The full workstation verifier for that acceptance cycle completed at:

```text
PASS=256 WARN=0 FAIL=0 SKIP=0
VERIFY_RC=0
```

## Engineering decisions

Several decisions made the change safer:

- inspect first, mutate second;
- verify exposure remotely, not only from localhost;
- perform a bounded runtime A/B test before persistence;
- preserve the broader Fedora default zone instead of rewriting unrelated
  policy;
- scope the hardening to `tailscale0`;
- verify behavior after reboot;
- add automated checks so the policy cannot silently regress.

## Why this case study matters

This is a compact network-security story with observable evidence:

```text
configuration review
        ↓
listener correlation
        ↓
remote exposure test
        ↓
runtime A/B control
        ↓
least-privilege interface policy
        ↓
reboot persistence
        ↓
automated verification
```

It demonstrates Linux networking, firewalld/nftables reasoning, remote
validation, least-privilege design and disciplined promotion of a manual fix
into reproducible code.

## Interview version

> I found that my Tailscale interface did not have a dedicated firewalld zone
> and could fall through to a broad default policy. I verified the real impact
> from another Tailnet device, where GSConnect and Steam ports were reachable.
> I then performed a temporary A/B firewall test, proved that outbound
> Tailscale still worked while the inbound ports became filtered, and promoted
> the result into a dedicated DROP-by-default `workstation-tailscale` zone
> with automated verification and reboot testing.

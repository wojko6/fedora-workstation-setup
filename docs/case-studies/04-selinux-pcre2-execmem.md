# Case Study 4 — SELinux, syslog-ng and PCRE2 JIT

## Executive summary

A Fedora 44 workstation running an ASUS Edge syslog-ng collector produced a
repeatable SELinux denial on every syslog-ng process start:

```text
avc: denied { execmem }
scontext=system_u:system_r:syslogd_t:s0
tcontext=system_u:system_r:syslogd_t:s0
tclass=process
permissive=0
```

The service still started successfully, so the investigation deliberately
avoided the common shortcut of generating a local `audit2allow` rule.

A sequence of controlled probes showed that:

- the denial occurs even with an otherwise empty syslog-ng configuration;
- `syslog-ng --version` does not trigger it;
- including or excluding `scl.conf` does not change the one-denial-per-start
  behavior;
- the workstation's PCRE2 package has JIT enabled;
- Fedora's PCRE2 source package explicitly disables the SELinux-oriented JIT
  allocator;
- a direct PCRE2 JIT allocation probe succeeds in `unconfined_t`, but the
  identical binary fails with `PCRE2_ERROR_NOMEMORY` and generates an
  `execmem` AVC when executed in `syslogd_t`.

The resulting engineering decision was to keep SELinux enforcing and not grant
`syslogd_t` broad `execmem` permission.

## Initial signal

The production syslog-ng process ran in the expected SELinux domain:

```text
system_u:system_r:syslogd_t:s0
```

The executable and configuration also carried expected policy types:

```text
/usr/sbin/syslog-ng -> syslogd_exec_t
/etc/syslog-ng      -> syslog_conf_t
```

Despite those correct labels, the audit subsystem recorded one denial whenever
the process started:

```text
avc: denied { execmem }
comm="syslog-ng-main"
scontext=system_u:system_r:syslogd_t:s0
tcontext=system_u:system_r:syslogd_t:s0
tclass=process
permissive=0
```

This made a simple relabeling fix inappropriate.

## Isolation sequence

### 1. Production collector configuration

The private ASUS Edge collector used TLS networking, a source-netmask filter and
a file destination. It did not contain PCRE filters or rewrite expressions that
could simply be annotated with `flags(disable-jit)`.

### 2. Minimal syslog-ng configuration

A transient syslog-ng instance was started from a minimal configuration without
`scl.conf`.

Result:

```text
MINIMAL_DELTA=1
```

Exactly one additional `execmem` AVC appeared.

### 3. SCL comparison

The same minimal configuration was tested again with `@include "scl.conf"`.

Result:

```text
SCL_DELTA=1
```

The denial count remained one per process start, so SCL content was not the
cause of the behavior.

### 4. Startup-stage isolation

Two more probes separated basic executable startup from configuration
initialization:

```text
syslog-ng --version
VERSION_DELTA=0

syslog-ng -s -f empty.conf
SYNTAX_DELTA=1
```

This localized the event to configuration initialization rather than ELF
startup alone.

## Fedora PCRE2 package evidence

The tested Fedora package was:

```text
pcre2-10.47-1.fc44.1
```

The exact Fedora source RPM was downloaded and its spec file inspected.

The build enables PCRE2 JIT on the workstation architecture:

```text
--enable-jit
--enable-pcre2grep-jit
```

At the same time, the package explicitly disables the SELinux-oriented JIT
allocator:

```text
%bcond_with pcre2_enables_sealloc

--disable-jit-sealloc
```

The spec comment explains that this allocator is disabled because it is not
considered fork-safe.

## Direct PCRE2 A/B proof

A small temporary C probe used:

```text
pcre2_config(PCRE2_CONFIG_JIT)
pcre2_jit_compile(NULL, PCRE2_JIT_TEST_ALLOC)
```

The same compiled binary was executed in two SELinux domains.

### Unconfined domain

```text
SELINUX_CONTEXT=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
PCRE2_CONFIG_JIT=1
PCRE2_JIT_TEST_ALLOC_RC=0
RESULT=JIT_ALLOCATOR_OK
```

### syslogd_t domain

The probe binary was temporarily labelled `syslogd_exec_t`, which caused the
process transition into the same `syslogd_t` domain used by production
syslog-ng.

```text
SELINUX_CONTEXT=system_u:system_r:syslogd_t:s0
PCRE2_CONFIG_JIT=1
PCRE2_JIT_TEST_ALLOC_RC=-48
PCRE2_ERROR_NOMEMORY=-48
RESULT=JIT_ALLOCATOR_BLOCKED_OR_UNAVAILABLE_MEMORY
```

The audit counter increased by one and the matching denial was:

```text
avc: denied { execmem }
comm=pcre2-jit-selin
scontext=system_u:system_r:syslogd_t:s0
tcontext=system_u:system_r:syslogd_t:s0
tclass=process
permissive=0
```

This reproduced the security boundary independently of the syslog-ng
configuration.

## Root-cause statement

The evidence confirms the root-cause class:

```text
Fedora PCRE2 JIT enabled
        +
SELinux-oriented JIT allocator disabled
        +
syslogd_t does not permit executable writable memory
        ↓
PCRE2 JIT allocation is denied in syslogd_t
        ↓
execmem AVC
```

The investigation does not claim to identify one specific internal syslog-ng
matcher responsible for the configuration-initialization attempt. Debug logging
did not expose such a matcher. What was established independently is that the
PCRE2 JIT allocator itself reproduces the same SELinux denial in the exact
`syslogd_t` domain.

## Security decision

The following options were deliberately rejected:

- disabling SELinux;
- setting the system or domain permissive;
- generating an `audit2allow` rule granting `syslogd_t self:process execmem`;
- rebuilding Fedora PCRE2 locally with a package option that Fedora explicitly
  disables for fork-safety reasons;
- suppressing the denial with a broad local `dontaudit` rule.

The accepted approach is:

- keep SELinux in Enforcing mode;
- keep the `execmem` denial enforced;
- recognize only the exact, documented one-per-boot syslog-ng/PCRE2 signature
  in the workstation verifier;
- continue to fail the zero-warning acceptance gate for every unexpected AVC,
  USER_AVC, SELINUX_ERR or USER_SELINUX_ERR record;
- treat repeated occurrences of the documented syslog-ng signature in one boot
  as suspicious enough to require review rather than silently accepting them.

This preserves the security control instead of weakening policy to remove log
noise.

## Verification architecture

Issue #28 upgrades the security-posture verifier from journal-only searching to
authoritative audit-subsystem evidence.

The intended logic is:

```text
SELinux Enforcing
        ↓
ausearch current boot
AVC / USER_AVC / SELINUX_ERR / USER_SELINUX_ERR
        ↓
no records
        -> PASS

exactly one documented syslog-ng execmem record
        -> PASS, documented exception

repeated documented record
        -> WARN / physical acceptance fails

any other denial/error
        -> WARN / physical acceptance fails

ausearch unavailable or unreadable
        -> explicit degraded-evidence WARN
        -> journal fallback for diagnostics only
        -> physical acceptance still fails
```

The journal is therefore no longer allowed to masquerade as authoritative audit
evidence.

## Why this case study matters

The important result is not merely that an AVC was explained.

The workflow demonstrates:

```text
audit evidence
    ↓
SELinux context validation
    ↓
minimal reproducer
    ↓
component isolation
    ↓
source-RPM build inspection
    ↓
same-binary SELinux-domain A/B test
    ↓
least-privilege decision
    ↓
fail-closed verifier improvement
```

This is a practical example of Linux security engineering: preserve the control,
prove the interaction, reject overly broad policy changes, and encode the
result as reproducible verification.

## Interview version

> I investigated a repeatable SELinux `execmem` denial from syslog-ng instead
> of immediately using audit2allow. I proved it happened even with an empty
> configuration, inspected Fedora's exact PCRE2 source build, and found JIT
> enabled while the SELinux-oriented allocator was deliberately disabled. I
> then wrote a small PCRE2 allocator probe and ran the same binary first in an
> unconfined domain and then in syslogd_t. It succeeded unconfined and failed
> with PCRE2_ERROR_NOMEMORY plus the same execmem AVC in syslogd_t. I kept
> SELinux enforcing and changed the project verifier to recognize only that
> exact documented one-per-boot signature while still failing on any other AVC.

# Portfolio case studies

These case studies present selected engineering problems from the Fedora
workstation project as recruiter-friendly technical narratives.

They are intentionally narrower than the main project documentation. Each one
focuses on a concrete problem, the evidence used to diagnose it, the engineering
decision that followed, and the way the result was validated.

## Case studies

1. [Reproducible Fedora Workstation](01-reproducible-fedora-workstation.md)  
   Desired state, fail-closed restore, drift detection, physical acceptance and
   recovery-oriented workstation engineering.

2. [Tailscale + firewalld isolation](02-tailscale-firewalld-isolation.md)  
   A network-security investigation that turned a broad fallback firewall path
   into a dedicated DROP-by-default policy for `tailscale0`.

3. [GNOME localization and integrity engineering](03-gnome-localization-integrity.md)  
   Exact-version localization, metadata fingerprinting, GNOME Shell cache
   diagnosis, deterministic extension-tree locks and physical visual acceptance.

The broader project overview remains in [../CASE-STUDY.md](../CASE-STUDY.md).

#!/usr/bin/env python3

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "scripts" / "verify-security-posture.sh"
MAIN_VERIFY = ROOT / "scripts" / "verify.sh"

MOCK = r'''#!/usr/bin/env python3
import os
import sys
from pathlib import Path

name = Path(sys.argv[0]).name
args = sys.argv[1:]

def env(name, default=""):
    return os.environ.get(name, default)

if name == "systemd-detect-virt":
    print(env("SEC_TEST_VIRT", "none"))
    raise SystemExit(0)

if name == "getenforce":
    print(env("SEC_TEST_SELINUX", "Enforcing"))
    raise SystemExit(0)

if name == "journalctl":
    if "-n" in args:
        print("boot journal readable")
        raise SystemExit(0)
    count = int(env("SEC_TEST_AVC_COUNT", "0"))
    for _ in range(count):
        print("kernel: avc:  denied  { read } for pid=123 comm=test")
    raise SystemExit(0)

if name == "systemctl":
    unit = args[-1] if args else ""
    if args[:4] == ["show", "-p", "LoadState", "--value"]:
        if unit in {"sshd.service", "sshd.socket"}:
            if env("SEC_TEST_OPENSSH_SERVER_INSTALLED", "0") == "1":
                print("loaded")
            else:
                print("not-found")
        else:
            print("not-found")
        raise SystemExit(0)
    if args and args[0] == "is-active":
        if unit == "sshd.service":
            print(env("SEC_TEST_SSH_ACTIVE", "inactive"))
        else:
            print("inactive")
        raise SystemExit(0 if env("SEC_TEST_SSH_ACTIVE", "inactive") == "active" else 3)
    if args and args[0] == "is-enabled":
        if unit == "sshd.service":
            state = env("SEC_TEST_SSH_ENABLED", "disabled")
        else:
            state = env("SEC_TEST_SOCKET_ENABLED", "disabled")
        print(state)
        raise SystemExit(0 if state == "enabled" else 1)
    raise SystemExit(1)

if name == "ss":
    if env("SEC_TEST_SSH_LISTENER", "0") == "1":
        print("LISTEN 0 128 0.0.0.0:22 0.0.0.0:*")
    raise SystemExit(0)

if name == "rpm":
    if args[:2] == ["-q", "akmod-nvidia"]:
        raise SystemExit(0)
    if args[:2] == ["-q", "openssh-server"]:
        raise SystemExit(0 if env("SEC_TEST_OPENSSH_SERVER_INSTALLED", "0") == "1" else 1)
    raise SystemExit(1)

if name == "mokutil":
    if args and args[0] == "--test-key":
        raise SystemExit(0 if env("SEC_TEST_MOK_TEST", "1") == "1" else 1)
    if args == ["--list-enrolled"]:
        if env("SEC_TEST_SIGNER_ENROLLED", "1") == "1":
            print("Subject: CN=Fedora akmods")
            if env("SEC_TEST_MOK_LARGE_OUTPUT", "0") == "1":
                print("X" * 262144)
        else:
            print("Subject: CN=Different certificate")
        raise SystemExit(0)
    raise SystemExit(1)

if name == "modinfo":
    if args[:3] == ["-F", "signer", "nvidia"]:
        print("Fedora akmods")
        raise SystemExit(0)
    if args[:3] == ["-F", "sig_hashalgo", "nvidia"]:
        print("sha256")
        raise SystemExit(0)
    raise SystemExit(1)

if name == "ip":
    if args == ["route", "show", "default"]:
        print("default via 192.168.1.1 dev wlp1s0 proto dhcp src 192.168.1.10 metric 600")
        raise SystemExit(0)
    if args == ["link", "show", "tailscale0"]:
        raise SystemExit(0 if env("SEC_TEST_TS_IFACE", "1") == "1" else 1)
    raise SystemExit(1)

if name == "iw":
    if args == ["dev"]:
        print("phy#0")
        print("\tInterface wlp1s0")
        raise SystemExit(0)
    raise SystemExit(1)

if name == "nmcli":
    if args == ["-t", "-f", "DEVICE,TYPE", "device", "status"]:
        print(f"wlp1s0:{env('SEC_TEST_IFACE_TYPE', 'wifi')}")
        raise SystemExit(0)
    if args[:4] == ["-g", "GENERAL.CONNECTION", "device", "show"]:
        print("Home WiFi")
        raise SystemExit(0)
    if args[:4] == ["-g", "connection.zone", "connection", "show"]:
        print(env("SEC_TEST_SAVED_ZONE", "workstation-kdeconnect"))
        raise SystemExit(0)
    raise SystemExit(1)

if name == "firewall-cmd":
    if args == ["--state"]:
        print("running")
        raise SystemExit(0)

    if args and args[0].startswith("--get-zone-of-interface="):
        iface = args[0].split("=", 1)[1]
        if iface == "tailscale0":
            print(env("SEC_TEST_TS_ACTIVE_ZONE", "workstation-tailscale"))
        else:
            print(env("SEC_TEST_ACTIVE_ZONE", "workstation-kdeconnect"))
        raise SystemExit(0)

    if args == ["--permanent", "--get-zones"]:
        print("FedoraWorkstation workstation-kdeconnect workstation-tailscale")
        raise SystemExit(0)

    zone = None
    for arg in args:
        if arg.startswith("--zone="):
            zone = arg.split("=", 1)[1]

    permanent = "--permanent" in args

    if "--query-service=kdeconnect" in args:
        if zone == "workstation-kdeconnect":
            raise SystemExit(0)
        raise SystemExit(0 if env("SEC_TEST_CROSS_ZONE_KDE", "0") == "1" else 1)

    if "--list-services" in args:
        if zone == "workstation-tailscale":
            if env("SEC_TEST_TS_SERVICE_DRIFT", "0") == "1":
                print("ssh")
            else:
                print("")
        elif env("SEC_TEST_SERVICE_DRIFT", "0") == "1" and not permanent:
            print("dhcpv6-client kdeconnect mdns ssh")
        else:
            print("dhcpv6-client kdeconnect mdns")
        raise SystemExit(0)

    if "--list-interfaces" in args:
        if zone == "workstation-tailscale":
            print(env("SEC_TEST_TS_INTERFACES", "tailscale0"))
        else:
            print("")
        raise SystemExit(0)

    if "--get-target" in args:
        if zone == "workstation-tailscale":
            print(env("SEC_TEST_TS_TARGET", "DROP"))
        else:
            print("default")
        raise SystemExit(0)

    if "--list-all" in args:
        print(f"{zone} (active)")
        print("  target: default")
        print("  services: dhcpv6-client kdeconnect mdns")
        raise SystemExit(0)

    if "--query-forward" in args:
        if zone == "workstation-tailscale":
            raise SystemExit(0 if env("SEC_TEST_TS_FORWARD", "0") == "1" else 1)
        raise SystemExit(0 if env("SEC_TEST_FORWARD", "0") == "1" else 1)

    if "--query-masquerade" in args:
        raise SystemExit(1)

    if "--query-icmp-block-inversion" in args:
        raise SystemExit(1)

    for option in [
        "--list-ports",
        "--list-protocols",
        "--list-source-ports",
        "--list-forward-ports",
        "--list-sources",
        "--list-icmp-blocks",
        "--list-rich-rules",
    ]:
        if option in args:
            print("")
            raise SystemExit(0)

    raise SystemExit(1)

raise SystemExit(127)
'''

COMMANDS = [
    "systemd-detect-virt",
    "getenforce",
    "journalctl",
    "systemctl",
    "ss",
    "rpm",
    "mokutil",
    "modinfo",
    "ip",
    "iw",
    "nmcli",
    "firewall-cmd",
]


def write_mock_bin(root: Path) -> Path:
    bindir = root / "bin"
    bindir.mkdir()
    for name in COMMANDS:
        path = bindir / name
        path.write_text(MOCK, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return bindir


def run_case(root: Path, *, create_cert: bool = True, **overrides: str):
    bindir = write_mock_bin(root)
    lockdown = root / "lockdown"
    lockdown.write_text("none [integrity] confidentiality\n", encoding="utf-8")
    cert = root / "public_key.der"
    if create_cert:
        cert.write_bytes(b"fixture certificate")

    env = os.environ.copy()
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env["VERIFY_LOCKDOWN_FILE"] = str(lockdown)
    env["VERIFY_AKMOD_CERT"] = str(cert)
    env.update(overrides)

    return subprocess.run(
        ["bash", str(TARGET)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )


def expect_pass(name: str, result):
    if result.returncode != 0:
        raise SystemExit(
            f"FAIL: {name}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    print(f"PASS: {name}")


def expect_fail(name: str, result, phrase: str):
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        raise SystemExit(f"FAIL: {name}: unexpectedly accepted")
    if phrase not in combined:
        raise SystemExit(
            f"FAIL: {name}: missing {phrase!r}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    print(f"PASS: {name} rejected")


with tempfile.TemporaryDirectory(prefix="security-posture-tests-") as td:
    base = Path(td)

    case = base / "valid"
    case.mkdir()
    expect_pass("valid physical security posture", run_case(case))

    case = base / "valid-no-cert-file"
    case.mkdir()
    expect_pass(
        "valid signer posture without retained akmods certificate file",
        run_case(case, create_cert=False),
    )

    case = base / "permissive"
    case.mkdir()
    expect_fail(
        "SELinux permissive",
        run_case(case, SEC_TEST_SELINUX="Permissive"),
        "SELinux state is not Enforcing",
    )

    case = base / "avc"
    case.mkdir()
    expect_fail(
        "current-boot AVC denial",
        run_case(case, SEC_TEST_AVC_COUNT="2"),
        "WARN: SELinux AVC denials observed",
    )

    case = base / "openssh-server-installed"
    case.mkdir()
    expect_fail(
        "installed OpenSSH server package",
        run_case(case, SEC_TEST_OPENSSH_SERVER_INSTALLED="1"),
        "openssh-server package must be absent",
    )

    case = base / "ssh-active"
    case.mkdir()
    expect_fail(
        "active SSH service",
        run_case(
            case,
            SEC_TEST_OPENSSH_SERVER_INSTALLED="1",
            SEC_TEST_SSH_ACTIVE="active",
        ),
        "sshd.service must be inactive",
    )

    case = base / "not-wifi"
    case.mkdir()
    expect_fail(
        "default-route interface is not Wi-Fi",
        run_case(case, SEC_TEST_IFACE_TYPE="ethernet"),
        "default-route interface is not Wi-Fi",
    )

    case = base / "firewall-drift"
    case.mkdir()
    expect_fail(
        "trusted-zone service drift",
        run_case(case, SEC_TEST_SERVICE_DRIFT="1"),
        "runtime firewalld services differ",
    )

    case = base / "cross-zone"
    case.mkdir()
    expect_fail(
        "cross-zone KDE Connect exposure",
        run_case(case, SEC_TEST_CROSS_ZONE_KDE="1"),
        "kdeconnect exposed in non-trusted permanent zone",
    )

    case = base / "tailscale-target"
    case.mkdir()
    expect_fail(
        "Tailscale zone target drift",
        run_case(case, SEC_TEST_TS_TARGET="default"),
        "Tailscale-zone target drift",
    )

    case = base / "tailscale-service"
    case.mkdir()
    expect_fail(
        "Tailscale zone service drift",
        run_case(case, SEC_TEST_TS_SERVICE_DRIFT="1"),
        "Tailscale-zone services contain unexpected state",
    )

    case = base / "tailscale-active-zone"
    case.mkdir()
    expect_fail(
        "Tailscale active-zone drift",
        run_case(case, SEC_TEST_TS_ACTIVE_ZONE="FedoraWorkstation"),
        "active Tailscale zone drift",
    )

    case = base / "large-mok-output"
    case.mkdir()
    expect_pass(
        "enrolled NVIDIA signer with large MOK output",
        run_case(case, SEC_TEST_MOK_LARGE_OUTPUT="1"),
    )

    case = base / "signer"
    case.mkdir()
    expect_fail(
        "unenrolled NVIDIA signer",
        run_case(case, SEC_TEST_SIGNER_ENROLLED="0"),
        "NVIDIA module signer identity is not found",
    )

main_verify = MAIN_VERIFY.read_text(encoding="utf-8")
required_contract = [
    'bad "required rpm missing: $pkg"',
    'bad "required repo not enabled: $repo"',
    'bad "required VPCS COPR repository not enabled: tgerov/vpcs"',
    'bad "Tailscale client missing"',
    'flatpak --system info "$app"',
    'bad "required system Flatpak app missing: $app"',
    '(( fail == 0 && warn == 0 ))',
    'verify-security-posture.sh',
]

for phrase in required_contract:
    if phrase not in main_verify:
        raise SystemExit(
            f"FAIL: fail-closed verifier contract missing: {phrase}"
        )

print("PASS: main verifier fail-closed contract present")
print("=== SECURITY POSTURE TESTS: PASS ===")

#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import stat
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "network" / "tailscale-firewall-zone.sh"
IFACE = "tailscale0"
ZONE = "workstation-tailscale"

MOCK = r'''#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

name = Path(sys.argv[0]).name
args = sys.argv[1:]
state_path = Path(os.environ["TS_FW_TEST_STATE"])
log_path = Path(os.environ["TS_FW_TEST_LOG"])

def load():
    return json.loads(state_path.read_text())

def save(state):
    state_path.write_text(json.dumps(state, indent=2) + "\n")

def log(msg):
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(msg + "\n")

def zone_from_args(args):
    for arg in args:
        if arg.startswith("--zone="):
            return arg.split("=", 1)[1]
    return None

def option_value(args, prefix):
    for arg in args:
        if arg.startswith(prefix + "="):
            return arg.split("=", 1)[1]
    return None

if name == "sudo":
    os.execvp(args[0], args)

state = load()

if name == "rpm":
    if args[:2] == ["-q", "firewalld"]:
        raise SystemExit(0)
    if args[:2] == ["-q", "tailscale"]:
        raise SystemExit(0)
    raise SystemExit(1)

if name == "systemctl":
    if args[:3] == ["is-active", "--quiet", "firewalld"]:
        raise SystemExit(0)
    if args and args[0] in {"unmask", "enable"}:
        log("systemctl " + " ".join(args))
        raise SystemExit(0)
    raise SystemExit(1)

if name == "ip":
    if args[:3] == ["link", "show", "tailscale0"]:
        raise SystemExit(0)
    raise SystemExit(1)

if name != "firewall-cmd":
    raise SystemExit(127)

if args == ["--state"]:
    print("running")
    raise SystemExit(0)

if args == ["--permanent", "--get-zones"]:
    print(" ".join(state["zones"].keys()))
    raise SystemExit(0)

for arg in args:
    if arg.startswith("--get-zone-of-interface="):
        iface = arg.split("=", 1)[1]
        if iface != "tailscale0":
            raise SystemExit(1)
        if os.environ.get("TS_FW_TEST_FAIL_ACTIVE") == "1" and "--permanent" not in args:
            print("FedoraWorkstation")
            raise SystemExit(0)
        print(state.get("iface_zone", "no zone"))
        raise SystemExit(0)

zone = zone_from_args(args)
if zone is not None:
    data = state["zones"].setdefault(zone, {
        "target": "default",
        "interfaces": [],
        "services": [],
        "ports": [],
        "protocols": [],
        "source_ports": [],
        "forward_ports": [],
        "sources": [],
        "icmp_blocks": [],
        "rich_rules": [],
        "forward": False,
        "masquerade": False,
        "icmp_inversion": False,
    })

    if "--get-target" in args:
        print(data["target"])
        raise SystemExit(0)
    if "--query-forward" in args:
        raise SystemExit(0 if data["forward"] else 1)
    if "--query-masquerade" in args:
        raise SystemExit(0 if data["masquerade"] else 1)
    if "--query-icmp-block-inversion" in args:
        raise SystemExit(0 if data["icmp_inversion"] else 1)

    mapping = {
        "--list-interfaces": "interfaces",
        "--list-services": "services",
        "--list-ports": "ports",
        "--list-protocols": "protocols",
        "--list-source-ports": "source_ports",
        "--list-forward-ports": "forward_ports",
        "--list-sources": "sources",
        "--list-icmp-blocks": "icmp_blocks",
        "--list-rich-rules": "rich_rules",
    }
    for opt, key in mapping.items():
        if opt in args:
            if key == "rich_rules":
                print("\n".join(data[key]))
            else:
                print(" ".join(data[key]))
            raise SystemExit(0)

    mutations = [
        ("--remove-interface", "interfaces", False),
        ("--add-interface", "interfaces", True),
        ("--remove-service", "services", False),
        ("--add-service", "services", True),
        ("--remove-port", "ports", False),
        ("--add-port", "ports", True),
        ("--remove-protocol", "protocols", False),
        ("--add-protocol", "protocols", True),
        ("--remove-source-port", "source_ports", False),
        ("--add-source-port", "source_ports", True),
        ("--remove-forward-port", "forward_ports", False),
        ("--add-forward-port", "forward_ports", True),
        ("--remove-source", "sources", False),
        ("--add-source", "sources", True),
        ("--remove-icmp-block", "icmp_blocks", False),
        ("--add-icmp-block", "icmp_blocks", True),
        ("--remove-rich-rule", "rich_rules", False),
        ("--add-rich-rule", "rich_rules", True),
    ]
    for prefix, key, add in mutations:
        value = option_value(args, prefix)
        if value is not None:
            log("firewall-cmd " + " ".join(args))
            if add and value not in data[key]:
                data[key].append(value)
            if not add and value in data[key]:
                data[key].remove(value)
            if key == "interfaces" and value == "tailscale0":
                if add:
                    for other_zone, other_data in state["zones"].items():
                        if other_zone != zone and value in other_data["interfaces"]:
                            other_data["interfaces"].remove(value)
                    state["iface_zone"] = zone
                elif state.get("iface_zone") == zone:
                    state["iface_zone"] = "no zone"
            save(state)
            raise SystemExit(0)

    bool_mutations = {
        "--remove-forward": ("forward", False),
        "--add-forward": ("forward", True),
        "--remove-masquerade": ("masquerade", False),
        "--add-masquerade": ("masquerade", True),
        "--remove-icmp-block-inversion": ("icmp_inversion", False),
        "--add-icmp-block-inversion": ("icmp_inversion", True),
    }
    for opt, (key, value) in bool_mutations.items():
        if opt in args:
            log("firewall-cmd " + " ".join(args))
            data[key] = value
            save(state)
            raise SystemExit(0)

    target = option_value(args, "--set-target")
    if target is not None:
        log("firewall-cmd " + " ".join(args))
        data["target"] = target
        save(state)
        raise SystemExit(0)

new_zone = option_value(args, "--new-zone")
if new_zone is not None:
    log("firewall-cmd " + " ".join(args))
    state["zones"][new_zone] = {
        "target": "default",
        "interfaces": [],
        "services": [],
        "ports": [],
        "protocols": [],
        "source_ports": [],
        "forward_ports": [],
        "sources": [],
        "icmp_blocks": [],
        "rich_rules": [],
        "forward": False,
        "masquerade": False,
        "icmp_inversion": False,
    }
    save(state)
    raise SystemExit(0)

delete_zone = option_value(args, "--delete-zone")
if delete_zone is not None:
    log("firewall-cmd " + " ".join(args))
    state["zones"].pop(delete_zone, None)
    save(state)
    raise SystemExit(0)

if args == ["--reload"]:
    log("firewall-cmd --reload")
    raise SystemExit(0)

raise SystemExit(1)
'''

def zone(
    *,
    target="default",
    interfaces=None,
    services=None,
    ports=None,
    protocols=None,
    source_ports=None,
    forward_ports=None,
    sources=None,
    icmp_blocks=None,
    rich_rules=None,
    forward=False,
    masquerade=False,
    icmp_inversion=False,
):
    return {
        "target": target,
        "interfaces": list(interfaces or []),
        "services": list(services or []),
        "ports": list(ports or []),
        "protocols": list(protocols or []),
        "source_ports": list(source_ports or []),
        "forward_ports": list(forward_ports or []),
        "sources": list(sources or []),
        "icmp_blocks": list(icmp_blocks or []),
        "rich_rules": list(rich_rules or []),
        "forward": forward,
        "masquerade": masquerade,
        "icmp_inversion": icmp_inversion,
    }

def dirty_state():
    return {
        "iface_zone": "FedoraWorkstation",
        "zones": {
            "FedoraWorkstation": zone(
                interfaces=[IFACE],
                services=["dhcpv6-client", "samba-client", "ssh"],
                ports=["1025-65535/udp", "1025-65535/tcp"],
                forward=True,
            ),
            ZONE: zone(
                target="ACCEPT",
                interfaces=["tun0"],
                services=["ssh", "kdeconnect"],
                ports=["22/tcp"],
                protocols=["gre"],
                source_ports=["5353/udp"],
                forward_ports=["port=8080:proto=tcp:toport=80:toaddr="],
                sources=["192.0.2.0/24"],
                icmp_blocks=["echo-request"],
                rich_rules=["rule family=ipv4 port port=1234 protocol=tcp accept"],
                forward=True,
                masquerade=True,
                icmp_inversion=True,
            ),
        },
    }

def write_mock_bin(root: Path) -> Path:
    bindir = root / "bin"
    bindir.mkdir()
    for name in ["ip", "rpm", "systemctl", "firewall-cmd", "sudo"]:
        path = bindir / name
        path.write_text(MOCK, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return bindir

def run_case(tmp: Path, state, *, fail_active=False):
    state_path = tmp / "state.json"
    log_path = tmp / "mutations.log"
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    log_path.write_text("", encoding="utf-8")
    bindir = write_mock_bin(tmp)

    env = os.environ.copy()
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env["TS_FW_TEST_STATE"] = str(state_path)
    env["TS_FW_TEST_LOG"] = str(log_path)
    if fail_active:
        env["TS_FW_TEST_FAIL_ACTIVE"] = "1"

    result = subprocess.run(
        ["bash", str(TARGET)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    return result, json.loads(state_path.read_text()), log_path.read_text()

with tempfile.TemporaryDirectory(prefix="tailscale-firewall-policy-tests-") as td:
    base = Path(td)

    case1 = base / "dirty"
    case1.mkdir()
    result, state, mutations = run_case(case1, dirty_state())
    if result.returncode != 0:
        raise SystemExit(
            "FAIL: dirty Tailscale zone did not converge\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}\n"
            f"mutations:\n{mutations}"
        )

    ts_zone = state["zones"][ZONE]
    if ts_zone["target"] != "DROP":
        raise SystemExit(f"FAIL: target mismatch: {ts_zone['target']}")
    if ts_zone["interfaces"] != [IFACE]:
        raise SystemExit(f"FAIL: interface exact-state mismatch: {ts_zone['interfaces']}")
    for key in [
        "services",
        "ports",
        "protocols",
        "source_ports",
        "forward_ports",
        "sources",
        "icmp_blocks",
        "rich_rules",
    ]:
        if ts_zone[key]:
            raise SystemExit(f"FAIL: residual {key}: {ts_zone[key]}")
    if ts_zone["forward"] or ts_zone["masquerade"] or ts_zone["icmp_inversion"]:
        raise SystemExit("FAIL: unsafe boolean state remains enabled")
    if state["iface_zone"] != ZONE:
        raise SystemExit("FAIL: tailscale0 was not moved into the dedicated zone")

    fallback = state["zones"]["FedoraWorkstation"]
    if fallback["interfaces"]:
        raise SystemExit("FAIL: tailscale0 remains assigned to FedoraWorkstation")
    if set(fallback["services"]) != {"dhcpv6-client", "samba-client", "ssh"}:
        raise SystemExit("FAIL: unrelated fallback services were modified")
    if fallback["ports"] != ["1025-65535/udp", "1025-65535/tcp"]:
        raise SystemExit("FAIL: unrelated fallback ports were modified")
    if not fallback["forward"]:
        raise SystemExit("FAIL: unrelated fallback forwarding was modified")

    print("PASS: dirty Tailscale zone converged to exact DROP policy")
    print("PASS: tailscale0 isolated from fallback without unrelated fallback changes")

    case2 = base / "rollback"
    case2.mkdir()
    original = dirty_state()
    result, state, _mutations = run_case(case2, original, fail_active=True)
    if result.returncode == 0:
        raise SystemExit("FAIL: simulated active-zone verification failure unexpectedly succeeded")

    restored_ts = state["zones"][ZONE]
    for key, value in original["zones"][ZONE].items():
        if restored_ts[key] != value:
            raise SystemExit(f"FAIL: rollback mismatch in Tailscale zone field: {key}")
    restored_fallback = state["zones"]["FedoraWorkstation"]
    if IFACE not in restored_fallback["interfaces"]:
        raise SystemExit("FAIL: rollback did not restore tailscale0 to previous fallback zone")
    if state["iface_zone"] != "FedoraWorkstation":
        raise SystemExit("FAIL: rollback did not restore previous interface zone")

    print("PASS: rollback restores previous zone state and interface assignment")

print("=== TAILSCALE FIREWALL POLICY TESTS: PASS ===")

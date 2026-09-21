#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "network" / "firewall-zone.sh"

TRUSTED_UUID = "11111111-2222-3333-4444-555555555555"
UNTRUSTED_UUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
PROFILE = "Home WiFi"
IFACE = "wlp1s0"

MOCK = r'''#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

name = Path(sys.argv[0]).name
args = sys.argv[1:]
state_path = Path(os.environ["FW_TEST_STATE"])
log_path = Path(os.environ["FW_TEST_LOG"])

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

if name == "ip":
    if args[:3] == ["route", "show", "default"]:
        print(f"default via 192.0.2.1 dev {state['iface']} proto dhcp")
        raise SystemExit(0)
    raise SystemExit(1)

if name == "rpm":
    if args[:2] == ["-q", "firewalld"]:
        raise SystemExit(0)
    raise SystemExit(1)

if name == "systemctl":
    if args[:3] == ["is-active", "--quiet", "firewalld"]:
        raise SystemExit(0 if state["firewalld_active"] else 3)
    if args and args[0] in {"unmask", "enable"}:
        log("systemctl " + " ".join(args))
        if args[0] == "enable":
            state["firewalld_active"] = True
            save(state)
        raise SystemExit(0)
    raise SystemExit(0)

if name == "nmcli":
    if args[:4] == ["-g", "GENERAL.CONNECTION", "device", "show"]:
        print(state["profile"])
        raise SystemExit(0)
    if args[:4] == ["-g", "GENERAL.CON-UUID", "device", "show"]:
        print(state["active_uuid"])
        raise SystemExit(0)
    if args[:4] == ["-t", "-f", "DEVICE,TYPE", "device"]:
        print(f"{state['iface']}:wifi")
        raise SystemExit(0)
    if len(args) >= 5 and args[:2] == ["-g", "connection.uuid"] and args[2:4] == ["connection", "show"]:
        print(state["active_uuid"])
        raise SystemExit(0)
    if len(args) >= 5 and args[:2] == ["-g", "connection.type"] and args[2:4] == ["connection", "show"]:
        print("802-11-wireless")
        raise SystemExit(0)
    if len(args) >= 5 and args[:2] == ["-g", "connection.zone"] and args[2:4] == ["connection", "show"]:
        print(state["profile_zone"])
        raise SystemExit(0)
    if len(args) >= 5 and args[:2] == ["connection", "modify"]:
        log("nmcli " + " ".join(args))
        if args[3] == "connection.zone":
            state["profile_zone"] = args[4]
            save(state)
            raise SystemExit(0)
    raise SystemExit(1)

if name != "firewall-cmd":
    raise SystemExit(127)

if args == ["--state"]:
    print("running")
    raise SystemExit(0)

if args == ["--get-services"]:
    print("dhcpv6-client mdns ssh kdeconnect cockpit")
    raise SystemExit(0)

if args == ["--get-active-zones"]:
    for zone, data in state["zones"].items():
        if data.get("active"):
            print(zone)
            print("  interfaces: " + " ".join(data.get("interfaces", [])))
    raise SystemExit(0)

if args == ["--permanent", "--get-zones"]:
    print(" ".join(state["zones"].keys()))
    raise SystemExit(0)

zone = zone_from_args(args)
if zone is not None:
    data = state["zones"].setdefault(zone, {
        "active": False,
        "interfaces": [],
        "target": "default",
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

    if "--query-service=kdeconnect" in args:
        raise SystemExit(0 if "kdeconnect" in data["services"] else 1)
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

    iface = option_value(args, "--change-interface")
    if iface is not None:
        log("firewall-cmd " + " ".join(args))
        if os.environ.get("FW_TEST_FAIL_CHANGE_INTERFACE") == "1":
            raise SystemExit(1)
        for zdata in state["zones"].values():
            if iface in zdata.get("interfaces", []):
                zdata["interfaces"].remove(iface)
        data["interfaces"].append(iface)
        data["active"] = True
        state["active_zone"] = zone
        save(state)
        raise SystemExit(0)

new_zone = option_value(args, "--new-zone")
if new_zone is not None:
    log("firewall-cmd " + " ".join(args))
    state["zones"][new_zone] = {
        "active": False,
        "interfaces": [],
        "target": "default",
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

for arg in args:
    if arg.startswith("--get-zone-of-interface="):
        print(state.get("active_zone", ""))
        raise SystemExit(0)

raise SystemExit(1)
'''

def initial_state(*, active_uuid=TRUSTED_UUID):
    return {
        "iface": IFACE,
        "profile": PROFILE,
        "active_uuid": active_uuid,
        "profile_zone": "public",
        "active_zone": "workstation-kdeconnect",
        "firewalld_active": True,
        "zones": {
            "FedoraWorkstation": {
                "active": True,
                "interfaces": [],
                "target": "default",
                "services": [
                    "dhcpv6-client",
                    "kdeconnect",
                    "samba-client",
                    "ssh",
                ],
                "ports": ["1025-65535/udp", "1025-65535/tcp"],
                "protocols": [],
                "source_ports": [],
                "forward_ports": [],
                "sources": [],
                "icmp_blocks": [],
                "rich_rules": [],
                "forward": True,
                "masquerade": False,
                "icmp_inversion": False,
            },
            "public": {
                "active": True,
                "interfaces": ["enp1s0"],
                "target": "default",
                "services": ["dhcpv6-client"],
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
            },
            "workstation-kdeconnect": {
                "active": True,
                "interfaces": [IFACE],
                "target": "ACCEPT",
                "services": [
                    "dhcpv6-client",
                    "mdns",
                    "ssh",
                    "kdeconnect",
                    "cockpit",
                ],
                "ports": ["22/tcp"],
                "protocols": ["gre"],
                "source_ports": ["5353/udp"],
                "forward_ports": ["port=8080:proto=tcp:toport=80:toaddr="],
                "sources": ["192.0.2.0/24"],
                "icmp_blocks": ["echo-request"],
                "rich_rules": [
                    "rule family=ipv4 port port=1234 protocol=tcp accept"
                ],
                "forward": True,
                "masquerade": True,
                "icmp_inversion": True,
            },
        },
    }

def write_mock_bin(root: Path):
    bindir = root / "bin"
    bindir.mkdir()
    for name in ["ip", "nmcli", "rpm", "systemctl", "firewall-cmd", "sudo"]:
        path = bindir / name
        path.write_text(MOCK, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return bindir

def run_case(tmp: Path, state, trusted_uuid, *, fail_change_interface=False):
    state_path = tmp / "state.json"
    log_path = tmp / "mutations.log"
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    log_path.write_text("", encoding="utf-8")
    bindir = write_mock_bin(tmp)
    env = os.environ.copy()
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env["FW_TEST_STATE"] = str(state_path)
    env["FW_TEST_LOG"] = str(log_path)
    env["TRUSTED_WIFI_UUID"] = trusted_uuid
    env["TRUSTED_WIFI_PROFILE"] = PROFILE
    if fail_change_interface:
        env["FW_TEST_FAIL_CHANGE_INTERFACE"] = "1"
    result = subprocess.run(
        ["bash", str(TARGET)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    return result, json.loads(state_path.read_text()), log_path.read_text()

with tempfile.TemporaryDirectory(prefix="firewall-policy-tests-") as td:
    base = Path(td)

    case1 = base / "untrusted"
    case1.mkdir()
    result, _state, mutations = run_case(
        case1,
        initial_state(active_uuid=UNTRUSTED_UUID),
        TRUSTED_UUID,
    )
    if result.returncode == 0:
        raise SystemExit("FAIL: untrusted profile unexpectedly accepted")
    if mutations.strip():
        raise SystemExit(
            "FAIL: untrusted profile caused mutation before rejection:\n"
            + mutations
        )
    if "active Wi-Fi profile is not trusted" not in result.stderr:
        raise SystemExit(
            "FAIL: untrusted profile rejection reason missing\n"
            + result.stderr
        )
    print("PASS: untrusted profile rejected before mutation")

    case2 = base / "trusted-dirty"
    case2.mkdir()
    result, state, mutations = run_case(
        case2,
        initial_state(),
        TRUSTED_UUID,
    )
    if result.returncode != 0:
        raise SystemExit(
            "FAIL: trusted dirty-zone fixture did not converge\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}\n"
            f"mutations:\n{mutations}"
        )

    zone = state["zones"]["workstation-kdeconnect"]
    expected_services = {"dhcpv6-client", "mdns", "kdeconnect"}
    if set(zone["services"]) != expected_services:
        raise SystemExit(f"FAIL: service exact-state mismatch: {zone['services']}")
    for key in [
        "ports",
        "protocols",
        "source_ports",
        "forward_ports",
        "sources",
        "icmp_blocks",
        "rich_rules",
    ]:
        if zone[key]:
            raise SystemExit(f"FAIL: residual {key}: {zone[key]}")
    if zone["forward"] or zone["masquerade"] or zone["icmp_inversion"]:
        raise SystemExit("FAIL: forwarding/masquerade/ICMP inversion still enabled")
    if zone["target"] != "default":
        raise SystemExit(f"FAIL: target is not default: {zone['target']}")
    if state["profile_zone"] != "workstation-kdeconnect":
        raise SystemExit("FAIL: trusted profile was not assigned to dedicated zone")
    if "--remove-service=ssh" not in mutations:
        raise SystemExit("FAIL: stale ssh service was not explicitly removed")
    if "--remove-forward" not in mutations:
        raise SystemExit("FAIL: forwarding was not explicitly removed")
    if "--remove-masquerade" not in mutations:
        raise SystemExit("FAIL: masquerade was not explicitly removed")
    if "--add-service=ssh" in mutations or "--add-forward" in mutations:
        raise SystemExit("FAIL: unsafe ssh/forward policy was reintroduced")

    fallback = state["zones"]["FedoraWorkstation"]
    if "kdeconnect" in fallback["services"]:
        raise SystemExit("FAIL: kdeconnect remains in fallback FedoraWorkstation zone")
    if set(fallback["services"]) != {"dhcpv6-client", "samba-client", "ssh"}:
        raise SystemExit(
            "FAIL: unrelated FedoraWorkstation services were modified: "
            + repr(fallback["services"])
        )
    if fallback["ports"] != ["1025-65535/udp", "1025-65535/tcp"]:
        raise SystemExit("FAIL: unrelated FedoraWorkstation ports were modified")
    if not fallback["forward"]:
        raise SystemExit("FAIL: unrelated FedoraWorkstation forwarding was modified")
    if "--zone=FedoraWorkstation --remove-service=kdeconnect" not in mutations:
        raise SystemExit("FAIL: fallback-zone KDE Connect was not explicitly removed")

    print("PASS: trusted dirty zone converged to exact minimal state")
    print("PASS: KDE Connect removed from fallback zone without unrelated changes")

    case3 = base / "rollback"
    case3.mkdir()
    original = initial_state()
    result, state, mutations = run_case(
        case3,
        original,
        TRUSTED_UUID,
        fail_change_interface=True,
    )
    if result.returncode == 0:
        raise SystemExit("FAIL: simulated post-mutation failure unexpectedly succeeded")
    if state["profile_zone"] != original["profile_zone"]:
        raise SystemExit("FAIL: rollback did not restore NetworkManager zone")
    restored = state["zones"]["FedoraWorkstation"]
    if "kdeconnect" not in restored["services"]:
        raise SystemExit("FAIL: rollback did not restore fallback-zone KDE Connect")
    restored_target = state["zones"]["workstation-kdeconnect"]
    for key in [
        "target",
        "services",
        "ports",
        "protocols",
        "source_ports",
        "forward_ports",
        "sources",
        "icmp_blocks",
        "rich_rules",
        "forward",
        "masquerade",
        "icmp_inversion",
    ]:
        if restored_target[key] != original["zones"]["workstation-kdeconnect"][key]:
            raise SystemExit(f"FAIL: rollback mismatch for target-zone field: {key}")

    print("PASS: rollback restores target zone, profile zone, and KDE Connect isolation changes")

print("=== FIREWALL POLICY SECURITY TESTS: PASS ===")

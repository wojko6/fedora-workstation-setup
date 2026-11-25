#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import os
import pwd
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
LAUNCHER_INSTALLER = ROOT / "scripts" / "install-launchers.sh"
PACKAGE_INSTALLER = ROOT / "scripts" / "install-packages.sh"
FLATPAK_INSTALLER = ROOT / "scripts" / "install-flatpaks.sh"
VERIFIER = ROOT / "scripts" / "verify.sh"

if not INSTALLER.stat().st_mode & stat.S_IXUSR:
    raise SystemExit("FAIL: install.sh is not executable by its owner")

launcher_installer = LAUNCHER_INSTALLER.read_text(encoding="utf-8")
if 'source "$ASUS_CONF"' in launcher_installer:
    raise SystemExit("FAIL: private ASUS launcher config is still sourced as shell code")

for phrase in [
    "render-asus-launcher.py",
    "--check-key-file",
    "desktop-file-validate",
]:
    if phrase not in launcher_installer:
        raise SystemExit(f"FAIL: ASUS launcher hardening contract missing: {phrase}")

package_installer = PACKAGE_INSTALLER.read_text(encoding="utf-8")
for phrase in [
    'for manifest in "$MANIFEST" "$ABSENT_MANIFEST"; do',
    'if [[ ! -r "$manifest" ]]; then',
    "ERROR: required package manifest missing or unreadable:",
    "ERROR: required RPM manifest is empty:",
]:
    if phrase not in package_installer:
        raise SystemExit(f"FAIL: package-manifest fail-closed contract missing: {phrase}")

if "RPM manifest is not populated yet; skipping." in package_installer:
    raise SystemExit("FAIL: empty required RPM manifest can still be accepted as SKIP")

flatpak_installer = FLATPAK_INSTALLER.read_text(encoding="utf-8")
for phrase in [
    "flatpak remotes --system --columns=name",
    "sudo flatpak remote-add --system --if-not-exists flathub",
    'sudo flatpak install --system -y flathub "$app"',
]:
    if phrase not in flatpak_installer:
        raise SystemExit(f"FAIL: system Flatpak install contract missing: {phrase}")

verifier = VERIFIER.read_text(encoding="utf-8")
for phrase in [
    "flatpak remotes --system --columns=name",
    'flatpak --system info "$app"',
]:
    if phrase not in verifier:
        raise SystemExit(f"FAIL: system Flatpak verification contract missing: {phrase}")

print("PASS: ASUS launcher config remains data-only")
print("PASS: RPM desired-state manifests fail closed before package mutation")
print("PASS: Flatpak desired state is consistently system-scoped")

# Keep stage dispatch observable even if a regression invokes a stage that uses
# only shell builtins. No test executes an actual restore stage.
STAGES = """
scripts/setup-repositories.sh scripts/install-packages.sh scripts/install-flatpaks.sh
scripts/install-geforce-now.sh scripts/install-theme-switcher.sh scripts/install-ding-managed-system.sh
scripts/install-extensions.sh scripts/setup-ddcutil.sh scripts/install-localizations.sh
scripts/install-launchers.sh scripts/restore-gnome.sh scripts/install-weather-locations.sh
scripts/install-dhruva-config.sh network/wifi-power-save.sh network/firewall-zone.sh
network/tailscale-firewall-zone.sh system/syslog-ng-tailscale-readiness.sh security/disable-llmnr.sh
security/kernel-hardening.sh security/disable-wsdd.sh
""".split()

MOCK = r'''#!/bin/bash
case "${0##*/}:$*" in
  'cat:/etc/fedora-release') exit 0 ;;
  'rpm:-q syslog-ng') exit 1 ;;
  'nmcli:-g connection.type connection show Missing') exit 10 ;;
  'rpm:-E %fedora') echo "${TEST_FEDORA:-44}"; exit 0 ;;
  'gnome-shell:--version') echo "GNOME Shell ${TEST_GNOME:-50.5}"; exit 0 ;;
  'rpm-ostree:status') exit "${TEST_OSTREE_RC:-1}" ;;
  'systemd-detect-virt:') echo "${TEST_VIRT:-none}"; exit 0 ;;
  'gdbus:call --address unix:path=/mock --timeout 5 --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner org.gnome.Shell')
    echo "${TEST_BUS_REPLY:-(true,)}"; exit 0 ;;
  'ip:route show default') echo 'default via 192.0.2.1 dev wlan0'; exit 0 ;;
  'nmcli:-g GENERAL.CONNECTION device show wlan0') echo Lab; exit 0 ;;
  'nmcli:-g GENERAL.CON-UUID device show wlan0'|'nmcli:-g connection.uuid connection show Lab')
    echo 11111111-2222-3333-4444-555555555555; exit 0 ;;
  'nmcli:-t -f DEVICE,TYPE device status') echo "wlan0:${TEST_DEVICE:-wifi}"; exit 0 ;;
  'nmcli:-g connection.type connection show Lab') echo 802-11-wireless; exit 0 ;;
esac
printf 'unexpected %s %s\n' "${0##*/}" "$*" >> "$TEST_CALLS"
exit 95
'''


def snapshot(root):
    state = {}
    for path in root.rglob("*"):
        meta = path.lstat()
        content = hashlib.sha256(path.read_bytes()).digest() if path.is_file() else None
        state[path.relative_to(root)] = (meta.st_mode, meta.st_mtime_ns, content)
    return state


with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    repo = base / "repo"
    shutil.copytree(ROOT, repo, ignore=shutil.ignore_patterns(
        ".git", "__pycache__", "*.local.tsv", "asus-router.conf"))
    mocks = base / "bin"
    mocks.mkdir()
    calls = base / "calls"
    calls.touch()
    home = base / "home"
    home.mkdir()
    system = base / "system"
    system.mkdir()
    runtime = base / "runtime"
    runtime.mkdir()
    credentials = {}
    # CI containers sometimes run as root. Exercise the actual EUID guard
    # with an unprivileged child, without adding a bypass to the installer.
    if os.geteuid() == 0:
        nobody = pwd.getpwnam("nobody")
        credentials = dict(user=nobody.pw_uid, group=nobody.pw_gid, extra_groups=[])
        base.chmod(0o755)
        for path in (home, runtime, system, calls):
            os.chown(path, nobody.pw_uid, nobody.pw_gid)
        for path in (repo, *repo.rglob("*")):
            if path.is_dir():
                path.chmod(0o755)
            else:
                path.chmod(0o644 | (path.stat().st_mode & 0o111))
    # Only the two read-only shell helpers may execute. Intercept every stage
    # at dispatch, including any future stage absent from our expected order.
    shell = mocks / "bash"
    shell.write_text('''#!/bin/bash
case "$1" in
  "$TEST_REPO/scripts/install-preflight.sh"|network/check-trusted-wifi.sh)
    exec /bin/bash "$@"
    ;;
  "$TEST_REPO/"*)
    printf 'stage %s\\n' "${1#"$TEST_REPO/"}" >> "$TEST_CALLS"
    ;;
  *)
    printf 'unexpected bash %s\\n' "$*" >> "$TEST_CALLS"
    exit 95
    ;;
esac
''')
    shell.chmod(0o755)
    for name in ("dirname", "awk", "grep"):
        (mocks / name).symlink_to(shutil.which(name))
    (mocks / "python3").symlink_to(sys.executable)
    commands = """
    cat rpm gnome-shell rpm-ostree systemd-detect-virt gdbus ip nmcli sudo dnf
    systemctl firewall-cmd gsettings dconf gnome-extensions glib-compile-schemas patch
    tar sha256sum install cmp gresource dracut lsinitrd restorecon udevadm sysctl curl gpg
    flatpak mkdir cp mv rm tee touch chmod chown systemd-analyze ss
    """.split()
    for name in commands:
        path = mocks / name
        path.write_text(MOCK)
        path.chmod(0o755)
    env = dict(PATH=str(mocks), HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
               DBUS_SESSION_BUS_ADDRESS="unix:path=/mock", TEST_CALLS=str(calls),
               LC_ALL="C", TEST_REPO=str(repo), SYSLOG_NG_COLLECTOR_CONF=str(system / "collector.conf"),
               TRUSTED_WIFI_UUID="11111111-2222-3333-4444-555555555555",
               TRUSTED_WIFI_PROFILE="Lab")

    def run(args, rc, message, *, dispatched=(), **overrides):
        calls.write_text("")
        before = [snapshot(tree) for tree in (repo, home, system, runtime)]
        result = subprocess.run(["/bin/bash", str(repo / "install.sh"), *args],
                                cwd=system, env={**env, **overrides}, **credentials,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if result.returncode != rc or message not in result.stdout:
            raise AssertionError(f"{args}: expected {rc}, {message!r}\n{result.stdout}")
        assert calls.read_text().splitlines() == [f"stage {stage}" for stage in dispatched], calls.read_text()
        assert before == [snapshot(tree) for tree in (repo, home, system, runtime)], "fixture state changed"
        return result.stdout

    run(["--help"], 0, "Usage:", DBUS_SESSION_BUS_ADDRESS="")
    for args in (["--invalid"], ["--apply", "--check"], ["--help", "extra"], [""]):
        run(args, 2, "Usage:")
    output = run(["--check"], 0, "PASS: mandatory preflight complete")
    assert "WARN: msgfmt is deferred" in output and "SKIP: private Weather" in output
    run(["--check"], 0, "SKIP: trusted Wi-Fi", TEST_VIRT="kvm",
        TRUSTED_WIFI_UUID="", TRUSTED_WIFI_PROFILE="")
    run(["--apply"], 0, "Setup stages finished", dispatched=STAGES)
    run([], 0, "Setup stages finished", dispatched=STAGES)
    for args in (["--check"], ["--apply"], []):
        run(args, 1, "active Wi-Fi profile is not trusted",
            TRUSTED_WIFI_UUID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    for overrides, reason in [
        (dict(TRUSTED_WIFI_UUID="", TRUSTED_WIFI_PROFILE=""), "TRUSTED_WIFI_UUID is required"),
        (dict(TEST_VIRT="kvm", TRUSTED_WIFI_UUID="bad"), "not a valid NetworkManager UUID"),
        (dict(TRUSTED_WIFI_PROFILE="Other"), "profile name mismatch"),
        (dict(TEST_DEVICE="ethernet"), "not Wi-Fi"),
        (dict(WIFI_PROFILE="Missing"), "WIFI_PROFILE must identify"),
        (dict(TEST_FEDORA="45"), "Fedora 44 Workstation is required"),
        (dict(TEST_GNOME="51"), "GNOME Shell 50 is required"),
        (dict(TEST_OSTREE_RC="0"), "rpm-ostree systems are unsupported"),
        (dict(DBUS_SESSION_BUS_ADDRESS=""), "graphical session bus"),
        (dict(TEST_BUS_REPLY="(false,)"), "must already own"),
        (dict(XDG_DATA_DIRS="/usr/share"), "managed DING requires"),
    ]:
        run(["--apply"], 1, reason, **overrides)

    for filename, data, reason in [
        ("packages/rpm.txt", "# empty\n", "empty manifest"),
        ("packages/rpm-absent.txt", "flatpak\n", "both required and absent"),
        ("packages/flatpak.txt", "--system\n", "invalid manifest entry"),
        ("gnome/extensions-lock.tsv", "broken\n", "invalid header"),
        ("gnome/extensions-tree-lock.tsv", "broken\n", "invalid header"),
        ("gnome/extensions-inventory.tsv", "broken\n", "invalid header"),
        ("gnome/managed-system-extensions.tsv", "broken\n", "invalid header"),
        ("security/repository-trust.json", "{}", "invalid external repository trust policy"),
        ("localization/ding/pl.po", "", "empty or unreadable stage input"),
        ("security/disable-wsdd.sh", "", "missing or unreadable stage"),
    ]:
        path = repo / filename
        original = path.read_bytes()
        path.write_text(data)
        run(["--apply"], 1, reason)
        path.write_bytes(original)
    # Missing deferred command without a provider must also stop apply.
    rpms = repo / "packages/rpm.txt"
    original = rpms.read_bytes()
    rpms.write_bytes(original.replace(b"gettext\n", b""))
    run(["--apply"], 1, "lacks its provider gettext")
    rpms.write_bytes(original)

    for name, reason in [
        ("gnome/weather-locations.local.tsv", "invalid private Weather"),
        ("desktop/launchers/asus-router.conf", "invalid private ASUS"),
    ]:
        path = repo / name
        path.write_text("invalid\n")
        run(["--apply"], 1, reason)
        path.unlink()
    (system / "collector.conf").touch()
    run(["--apply"], 1, "private collector requires the syslog-ng package")
    (mocks / "dnf").unlink()
    run(["--apply"], 1, "missing required host command: dnf")

print("PASS: check and rejected apply invoked no mutator or stage and preserved fixture state")
print("PASS: explicit and default apply dispatched only the expected ordered stage doubles")
print("=== INSTALLER PREFLIGHT TESTS: PASS ===")

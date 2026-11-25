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
  'nmcli:-g GENERAL.CON-UUID device show wlan0'|'nmcli:-g connection.uuid connection show uuid 11111111-2222-3333-4444-555555555555')
    echo 11111111-2222-3333-4444-555555555555; exit 0 ;;
  'nmcli:-t -f DEVICE,TYPE device status') echo "wlan0:${TEST_DEVICE:-wifi}"; exit 0 ;;
  'nmcli:-g connection.type connection show uuid 11111111-2222-3333-4444-555555555555') echo 802-11-wireless; exit 0 ;;
esac
printf 'unexpected %s %s\n' "${0##*/}" "$*" >> "$TEST_CALLS"
exit 95
'''


def snapshot(root):
    state = {}
    for path in (root, *root.rglob("*")):
        meta = path.lstat()
        try:
            content = hashlib.sha256(path.read_bytes()).digest() if path.is_file() else None
        except PermissionError:
            content = "unreadable"  # mode and mtime remain part of the snapshot
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
    tmpdir = base / "tmp"
    cache = base / "cache"
    tmpdir.mkdir(mode=0o700)
    cache.mkdir(mode=0o700)
    watched = (repo, home, system, runtime, tmpdir, cache)
    credentials = {}
    # CI containers sometimes run as root. Exercise the actual EUID guard
    # with an unprivileged child, without adding a bypass to the installer.
    if os.geteuid() == 0:
        nobody = pwd.getpwnam("nobody")
        credentials = dict(user=nobody.pw_uid, group=nobody.pw_gid, extra_groups=[])
        base.chmod(0o755)
        mocks.chmod(0o755)
        for path in (*watched, calls, *repo.rglob("*")):
            os.chown(path, nobody.pw_uid, nobody.pw_gid)
    for path in (repo, *repo.rglob("*")):
        # copytree preserves modes, including a checkout mounted read-only in CI.
        path.chmod(path.stat().st_mode | (0o700 if path.is_dir() else 0o600))

    # Only the two read-only shell helpers may execute. Intercept every stage
    # at dispatch, including any future stage absent from our expected order.
    shell = mocks / "bash"
    shell.write_text('''#!/bin/bash
case "$1" in
  "$TEST_REPO/scripts/install-preflight.sh")
    echo preflight >> "$TEST_CALLS"
    exec /bin/bash "$@"
    ;;
  network/check-trusted-wifi.sh)
    exec /bin/bash "$@"
    ;;
  "$TEST_REPO/"*)
    stage=${1#"$TEST_REPO/"}
    printf 'stage %s\\n' "$stage" >> "$TEST_CALLS"
    if [[ "$stage" == "${TEST_FAIL_STAGE:-}" ]]; then exit 73; fi
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
    flatpak mkdir mktemp cp mv rm tee touch chmod chown systemd-analyze ss
    basename cut date find head id readlink sed sort stat tail tr wc xargs
    """.split()
    for name in commands:
        path = mocks / name
        path.write_text(MOCK)
        path.chmod(0o755)
    env = dict(PATH=str(mocks), HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
               TMPDIR=str(tmpdir), XDG_CACHE_HOME=str(cache),
               DBUS_SESSION_BUS_ADDRESS="unix:path=/mock", TEST_CALLS=str(calls),
               LC_ALL="C", TEST_REPO=str(repo), SYSLOG_NG_COLLECTOR_CONF=str(system / "collector.conf"),
               TRUSTED_WIFI_UUID="11111111-2222-3333-4444-555555555555",
               TRUSTED_WIFI_PROFILE="Lab")

    # Positive control under exactly the identity that will run install.sh.
    # Prove a write would succeed before relying on unchanged snapshots.
    subprocess.run([sys.executable, "-I", "-B", "-c", """
import os
import sys
from pathlib import Path
assert os.geteuid() != 0
for root in map(Path, sys.argv[1:]):
    probe = root / ".write-probe"
    with probe.open("xb") as out:
        out.write(b"probe")
    probe.unlink()
with Path("packages/rpm.txt").open("r+b"):
    pass
""", *watched], cwd=repo, env=env, check=True, **credentials)

    def run(args, rc, message, *, dispatched=(), preflight=True, **overrides):
        calls.write_text("")
        before = [snapshot(tree) for tree in watched]
        result = subprocess.run(["/bin/bash", str(repo / "install.sh"), *args],
                                cwd=system, env={**env, **overrides}, **credentials,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if result.returncode != rc or message not in result.stdout:
            raise AssertionError(f"{args}: expected {rc}, {message!r}\n{result.stdout}")
        expected = ["preflight"] if preflight else []
        expected.extend(f"stage {stage}" for stage in dispatched)
        assert calls.read_text().splitlines() == expected, calls.read_text()
        for tree, previous in zip(watched, before):
            assert snapshot(tree) == previous, f"fixture state changed: {tree.name}"
        return result.stdout

    run(["--help"], 0, "Usage:", preflight=False, DBUS_SESSION_BUS_ADDRESS="")
    for args in (["--invalid"], ["--apply", "--check"], ["--help", "extra"], [""]):
        run(args, 2, "Usage:", preflight=False)
    output = run(["--check"], 0, "PASS: mandatory preflight complete")
    assert "WARN: msgfmt is deferred" in output and "SKIP: private Weather" in output
    run(["--check"], 0, "SKIP: trusted Wi-Fi", TEST_VIRT="kvm",
        TRUSTED_WIFI_UUID="", TRUSTED_WIFI_PROFILE="")
    run(["--apply"], 0, "Setup stages finished", dispatched=STAGES)
    run([], 0, "Setup stages finished", dispatched=STAGES)
    # Use the same checkout, home and cache across a failure and two retries.
    # A stale successful check or resuming after the failed stage would be observable.
    failed_stage = "scripts/install-flatpaks.sh"
    attempted = STAGES[:STAGES.index(failed_stage) + 1]
    output = run(["--apply"], 73, f"Running {failed_stage}", dispatched=attempted,
                 TEST_FAIL_STAGE=failed_stage)
    assert "Setup stages finished" not in output
    manifest = repo / "packages/flatpak.txt"
    previous_manifest = manifest.read_bytes()
    manifest.write_text("--system\n")
    run(["--apply"], 1, "invalid manifest entry")
    manifest.write_bytes(previous_manifest)
    run(["--apply"], 0, "Setup stages finished", dispatched=STAGES)
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
    manifest = repo / "packages/installer-inputs.txt"
    original = manifest.read_bytes()
    for data, reason in [
        (original.replace(b"localization/ding/pl.po\n", b""), "missing mandatory entries"),
        (original + b"localization/ding/pl.po\n", "duplicate installer input"),
        (original + b"../outside\n", "invalid repository input path"),
        (original + b"\xff\n", "cannot read repository input"),
    ]:
        manifest.write_bytes(data)
        run(["--apply"], 1, reason)
    manifest.write_bytes(original)
    manifest.chmod(0)
    try:
        output = run(["--apply"], 1, "cannot read repository input")
        assert "Traceback" not in output
    finally:
        manifest.chmod(0o644)

    weather = repo / "gnome/weather-locations.local.tsv"
    asus = repo / "desktop/launchers/asus-router.conf"
    key = home / "synthetic-key"
    key.write_text("synthetic fixture, not a key\n")
    weather.write_text("Synthetic City\t52.0\t21.0\n")
    asus.write_text(f'SSH_KEY="{key}"\nSSH_PORT=2222\nSSH_USER=fixture\nROUTER_HOST=192.0.2.1\n')
    output = run(["--check"], 0, "PASS: mandatory preflight complete")
    assert "PASS: private ASUS" in output and "PASS: private Weather" in output
    for path, reason in [(asus, "invalid private ASUS"), (weather, "invalid private Weather")]:
        original_private = path.read_bytes()
        path.write_bytes(b"private-sentinel\xff")
        if path == weather:
            command = [sys.executable, "-IB", str(repo / "scripts/manage-weather-locations.py"),
                       "--check-config", "--config", str(path)]
        else:
            command = [sys.executable, "-IB", str(repo / "scripts/render-asus-launcher.py"),
                       "--check", "--config", str(path), "--template",
                       str(repo / "desktop/launchers/asus-router.desktop.template"),
                       "--ddterm-bin", "/synthetic/ddterm"]
        direct = subprocess.run(command, capture_output=True, text=True, env=env, **credentials)
        assert direct.returncode != 0 and "UTF-8" in direct.stderr, direct.stderr
        assert "private-sentinel" not in direct.stderr and "Traceback" not in direct.stderr
        output = run(["--apply"], 1, reason)
        assert "private-sentinel" not in output and "Traceback" not in output
        path.write_bytes(original_private)
        path.chmod(0)
        try:
            run(["--apply"], 1, reason)
            direct = subprocess.run(command, capture_output=True, text=True, env=env, **credentials)
            assert direct.returncode != 0 and "unavailable" in direct.stderr, direct.stderr
            assert str(path) not in direct.stderr and "Traceback" not in direct.stderr
        finally:
            path.chmod(0o644)
    weather.unlink()
    asus.unlink()
    key.unlink()

    # The first stage bootstraps curl/GnuPG. A missing host-only tool must
    # still block before dispatch, even if its consumer is several stages later.
    (mocks / "curl").unlink()
    (mocks / "gpg").unlink()
    output = run(["--check"], 0, "PASS: mandatory preflight complete")
    for cmd in ("curl", "gpg"):
        assert f"WARN: {cmd} is supplied by setup-repositories.sh" in output
    for cmd, reason in [("mktemp", "missing required host command"),
                        ("patch", "missing later-stage command")]:
        path = mocks / cmd
        path.rename(mocks / "disabled")
        run(["--apply"], 1, f"{reason}: {cmd}")
        (mocks / "disabled").rename(path)

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
print("PASS: stage failure propagated its status and stopped subsequent dispatch")
print("PASS: retry revalidated changed inputs and restarted the plan after correction")
print("PASS: unprivileged checks preserved writable repo, home, system, runtime, tmp and cache")
print("=== INSTALLER PREFLIGHT TESTS: PASS ===")

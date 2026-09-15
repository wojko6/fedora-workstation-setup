#!/usr/bin/env bash
set -Eeuo pipefail

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

echo "==> Configuring external Fedora repositories"

# RPM Fusion: release packages are already part of packages/rpm.txt, but they
# must exist before packages from RPM Fusion can be installed.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  fedora_ver="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
else
  echo "OK: RPM Fusion release packages already installed"
fi

# The source workstation uses the Brave Browser repository. Keep the repository
# setup separate from the package manifest so a clean Fedora can bootstrap it.
if repo_enabled brave-browser; then
  echo "OK: Brave repository already enabled"
else
  echo "INFO: Brave repository is not enabled."
  echo "      Configure the Brave repository before installing brave-origin."
fi

# NordVPN is a third-party repository. Do not embed credentials or account data.
if repo_enabled repo.nordvpn.com_yum_nordvpn_centos_x86_64; then
  echo "OK: NordVPN repository already enabled"
else
  echo "INFO: NordVPN repository is not enabled."
  echo "      Configure NordVPN's official RPM repository before installing nordvpn-gui."
fi

# Other repositories observed on the source workstation are intentionally not
# bootstrapped here unless required by the reviewed restore manifest:
# google-chrome and COPR repositories for PyCharm/VPCS.

echo "==> Repository setup stage finished"

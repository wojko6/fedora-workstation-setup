#!/usr/bin/env bash
set -Eeuo pipefail

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

echo "==> Configuring external Fedora repositories"

# RPM Fusion must exist before packages such as akmod-nvidia, Steam and
# multimedia codecs from RPM Fusion can be installed.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  fedora_ver="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
else
  echo "OK: RPM Fusion release packages already installed"
fi

# Brave Origin uses Brave's official release repository. On Fedora 41+ the
# supported dnf5 syntax is config-manager addrepo --from-repofile=...
if repo_enabled brave-browser; then
  echo "OK: Brave repository already enabled"
else
  echo "==> Adding Brave official RPM repository"
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager addrepo \
    --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
fi

# NordVPN publishes a release RPM which installs its official repository.
# This contains no user credentials or Nord Account token.
if repo_enabled repo.nordvpn.com_yum_nordvpn_centos_x86_64; then
  echo "OK: NordVPN repository already enabled"
else
  echo "==> Adding NordVPN official RPM repository"
  sudo dnf install -y \
    https://repo.nordvpn.com/yum/nordvpn/centos/noarch/Packages/n/nordvpn-release-1.0.0-1.noarch.rpm
fi

# VPCS is part of the reviewed GNS3 restore manifest. The source workstation
# obtains it from the tgerov/vpcs COPR, so bootstrap the same source before
# packages/rpm.txt is installed.
if dnf repolist --enabled 2>/dev/null | grep -Fq 'tgerov:vpcs'; then
  echo "OK: VPCS COPR repository already enabled"
else
  echo "==> Enabling COPR repository for VPCS (tgerov/vpcs)"
  sudo dnf install -y dnf-plugins-core
  sudo dnf copr enable -y tgerov/vpcs
fi

# Repositories observed on the source workstation but intentionally not
# bootstrapped unless they become part of the reviewed restore manifest:
# google-chrome and the PyCharm COPR repository.

echo "==> Repository setup stage finished"

#!/usr/bin/env bash
set -Eeuo pipefail

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

HELIUM_REPO_ID="copr:copr.fedorainfracloud.org:imput:helium"
VPCS_REPO_ID="copr:copr.fedorainfracloud.org:tgerov:vpcs"

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

# Tailscale is available directly from Fedora 44 repositories, so no external
# Tailscale repository is required. Authentication remains private state and is
# deliberately not automated by this repository.

# Helium is part of workstation desired state and is installed from its
# reviewed COPR source.
if repo_enabled "$HELIUM_REPO_ID"; then
  echo "OK: Helium COPR repository already enabled"
else
  echo "==> Enabling COPR repository for Helium (imput/helium)"
  sudo dnf install -y dnf-plugins-core
  sudo dnf copr enable -y imput/helium
fi

# VPCS is part of the reviewed GNS3 restore manifest. The COPR is restricted
# to the single package that this workstation requires from it.
if repo_enabled "$VPCS_REPO_ID"; then
  echo "OK: VPCS COPR repository already enabled"
else
  echo "==> Enabling COPR repository for VPCS (tgerov/vpcs)"
  sudo dnf install -y dnf-plugins-core
  sudo dnf copr enable -y tgerov/vpcs
fi

sudo dnf config-manager setopt "${VPCS_REPO_ID}.includepkgs=vpcs"

# Repositories observed on the source workstation but intentionally not
# bootstrapped unless they become part of the reviewed restore manifest:
# google-chrome and the PyCharm COPR repository.

echo "==> Repository setup stage finished"

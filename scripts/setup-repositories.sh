#!/usr/bin/env bash
set -Eeuo pipefail

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

HELIUM_REPO_ID="copr:copr.fedorainfracloud.org:imput:helium"
VPCS_REPO_ID="copr:copr.fedorainfracloud.org:tgerov:vpcs"
FEDORA_VER="$(rpm -E %fedora)"

KEY_ROOT="/usr/share/distribution-gpg-keys"
RPMFUSION_FREE_KEY="$KEY_ROOT/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-${FEDORA_VER}"
RPMFUSION_NONFREE_KEY="$KEY_ROOT/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${FEDORA_VER}"
BRAVE_KEY="$KEY_ROOT/brave/brave-core.asc"
HELIUM_KEY="$KEY_ROOT/copr/copr-imput-helium.gpg"
VPCS_KEY="$KEY_ROOT/copr/copr-tgerov-vpcs.gpg"

echo "==> Configuring external Fedora repositories"

# Bootstrap all external-repository trust from Fedora-signed packages first.
sudo dnf install -y dnf-plugins-core distribution-gpg-keys distribution-gpg-keys-copr

for key in \
  "$RPMFUSION_FREE_KEY" \
  "$RPMFUSION_NONFREE_KEY" \
  "$BRAVE_KEY" \
  "$HELIUM_KEY" \
  "$VPCS_KEY"
do
  [[ -f "$key" ]] || {
    echo "ERROR: required Fedora-distributed repository key missing: $key" >&2
    exit 1
  }
done

# Import the reviewed RPM Fusion keys before installing the release RPMs so the
# bootstrap packages themselves are signature-checked against Fedora-distributed
# trust anchors rather than a key obtained from the same external repository.
sudo rpm --import "$RPMFUSION_FREE_KEY" "$RPMFUSION_NONFREE_KEY"

# RPM Fusion must exist before packages such as akmod-nvidia, Steam and
# multimedia codecs from RPM Fusion can be installed.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
else
  echo "OK: RPM Fusion release packages already installed"
fi

# Brave Origin uses Brave's official release repository. On Fedora 41+ the
# supported dnf5 syntax is config-manager addrepo --from-repofile=...
if repo_enabled brave-browser; then
  echo "OK: Brave repository already enabled"
else
  echo "==> Adding Brave official RPM repository"
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
  sudo dnf copr enable -y imput/helium
fi

# VPCS is part of the reviewed GNS3 restore manifest. The COPR is restricted
# to the single package that this workstation requires from it.
if repo_enabled "$VPCS_REPO_ID"; then
  echo "OK: VPCS COPR repository already enabled"
else
  echo "==> Enabling COPR repository for VPCS (tgerov/vpcs)"
  sudo dnf copr enable -y tgerov/vpcs
fi

# Converge the effective trust policy. All external repositories use local
# Fedora-distributed key files and package signature verification stays enabled.
sudo dnf config-manager setopt \
  "rpmfusion-free.gpgkey=file://${RPMFUSION_FREE_KEY}" \
  "rpmfusion-free.gpgcheck=1" \
  "rpmfusion-nonfree.gpgkey=file://${RPMFUSION_NONFREE_KEY}" \
  "rpmfusion-nonfree.gpgcheck=1" \
  "brave-browser.gpgkey=file://${BRAVE_KEY}" \
  "brave-browser.gpgcheck=1" \
  "${HELIUM_REPO_ID}.gpgkey=file://${HELIUM_KEY}" \
  "${HELIUM_REPO_ID}.gpgcheck=1" \
  "${HELIUM_REPO_ID}.includepkgs=helium-bin" \
  "${VPCS_REPO_ID}.gpgkey=file://${VPCS_KEY}" \
  "${VPCS_REPO_ID}.gpgcheck=1" \
  "${VPCS_REPO_ID}.includepkgs=vpcs"

# Repositories observed on the source workstation but intentionally not
# bootstrapped unless they become part of the reviewed restore manifest:
# google-chrome and the PyCharm COPR repository.

echo "==> Repository setup stage finished"

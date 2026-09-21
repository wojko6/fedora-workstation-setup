#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TRUST_VERIFY="$ROOT_DIR/scripts/verify-repository-trust.py"

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

HELIUM_REPO_ID="copr:copr.fedorainfracloud.org:imput:helium"
VPCS_REPO_ID="copr:copr.fedorainfracloud.org:tgerov:vpcs"
FEDORA_VER="$(rpm -E %fedora)"

KEY_ROOT="/usr/share/distribution-gpg-keys"
RPMFUSION_FREE_KEY="$KEY_ROOT/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-${FEDORA_VER}"
RPMFUSION_NONFREE_KEY="$KEY_ROOT/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${FEDORA_VER}"
HELIUM_KEY="$KEY_ROOT/copr/copr-imput-helium.gpg"
VPCS_KEY="$KEY_ROOT/copr/copr-tgerov-vpcs.gpg"
BRAVE_KEY_URL="https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"
BRAVE_KEY="/etc/pki/rpm-gpg/brave-core-reviewed.asc"

echo "==> Configuring external Fedora repositories"

# Bootstrap independent trust material from Fedora-signed repositories first.
sudo dnf install -y \
  dnf-plugins-core \
  distribution-gpg-keys \
  distribution-gpg-keys-copr \
  gnupg2 \
  curl

# Validate the actual trust-anchor files before any third-party package install.
python3 "$TRUST_VERIFY" --check-key rpmfusion-free "$RPMFUSION_FREE_KEY"
python3 "$TRUST_VERIFY" --check-key rpmfusion-nonfree "$RPMFUSION_NONFREE_KEY"
python3 "$TRUST_VERIFY" --check-key "$HELIUM_REPO_ID" "$HELIUM_KEY"
python3 "$TRUST_VERIFY" --check-key "$VPCS_REPO_ID" "$VPCS_KEY"

# Import reviewed RPM Fusion keys before installing the release RPMs, avoiding
# a same-origin bootstrap where the release RPM supplies its own trust anchor.
sudo rpm --import "$RPMFUSION_FREE_KEY" "$RPMFUSION_NONFREE_KEY"

if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
else
  echo "OK: RPM Fusion release packages already installed"
fi

# Fedora's bundled Brave key is historical. Fetch Brave's current official
# release-only bundle, verify its exact reviewed fingerprint set, then install
# that verified bundle locally before the repository can consume it.
brave_tmp="$(mktemp -d)"
trap 'rm -rf "$brave_tmp"' EXIT
curl -fsSLo "$brave_tmp/brave-core.asc" "$BRAVE_KEY_URL"
python3 "$TRUST_VERIFY" --check-key brave-browser "$brave_tmp/brave-core.asc"
sudo install -m 0644 "$brave_tmp/brave-core.asc" "$BRAVE_KEY"

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

if repo_enabled "$HELIUM_REPO_ID"; then
  echo "OK: Helium COPR repository already enabled"
else
  echo "==> Enabling COPR repository for Helium (imput/helium)"
  sudo dnf copr enable -y imput/helium
fi

if repo_enabled "$VPCS_REPO_ID"; then
  echo "OK: VPCS COPR repository already enabled"
else
  echo "==> Enabling COPR repository for VPCS (tgerov/vpcs)"
  sudo dnf copr enable -y tgerov/vpcs
fi

# Converge all external repositories to reviewed local trust anchors.
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

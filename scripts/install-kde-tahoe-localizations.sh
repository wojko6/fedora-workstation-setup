#!/usr/bin/env bash
# Restore tested Mac Tahoe Liquid KDE Polish catalogs without modifying Plasma config.
set -Eeuo pipefail

mode="$(printf '%s' "$*" | sed 's/^ *//;s/ *$//')"
case "$mode" in
    --verify|--install) ;;
    *)
        echo "Usage: bash scripts/install-kde-tahoe-localizations.sh --verify|--install"
        echo "--verify: read-only check of repository catalogs and optional local installation"
        echo "--install: verify hashes, back up changed catalogs, install for current user"
        exit 2 ;;
esac

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
data_home="$HOME/.local/share"
if [[ -v XDG_DATA_HOME && -n "$XDG_DATA_HOME" ]]; then
    data_home="$XDG_DATA_HOME"
fi
target_dir="$data_home/locale/pl/LC_MESSAGES"

for domain in \
    "plasma_applet_org.kde.mac.tahoe.liquid.globalmenu" \
    "plasma_applet_org.kde.mac-tahoe-liquid-kde.launcher"
do
    case "$domain" in
        plasma_applet_org.kde.mac.tahoe.liquid.globalmenu)
            po_sha="5447beaf22fb94ef8815b1a135e3971cb448ee32184fb3c3b88788dc03f945eb"
            mo_sha="984b2b021b28532d6ba6d8e5b357fe05698919481628f018e3e6f9dda81ce386"
            ;;
        plasma_applet_org.kde.mac-tahoe-liquid-kde.launcher)
            po_sha="2674d789bf311054c21f37f2f4fc20dc048009486259c0a9684114200f031386"
            mo_sha="d005d4fe34873dbdccc90af4527e5faa3d9df0db5f20fd5ef0c45e4bc5240f13"
            ;;
    esac

    po="$root/localization/kde-tahoe/$domain.po"
    mo="$root/localization/kde-tahoe/$domain.mo"
    dest="$target_dir/$domain.mo"

    echo "=== $domain ==="
    printf '%s  %s\n' "$po_sha" "$po" | sha256sum --check --status || {
        echo "FAIL: PO checksum mismatch" >&2
        exit 1
    }
    printf '%s  %s\n' "$mo_sha" "$mo" | sha256sum --check --status || {
        echo "FAIL: MO checksum mismatch" >&2
        exit 1
    }

    if command -v msgfmt >/dev/null 2>&1; then
        msgfmt --check -o /dev/null "$po"
    fi
    echo "REPOSITORY_CATALOGS=PASS"

    if [[ -L "$dest" ]]; then
        echo "FAIL: refusing symbolic-link destination: $dest" >&2
        exit 1
    fi

    if [[ "$mode" == "--install" ]]; then
        if [[ -f "$dest" ]] && ! cmp -s "$mo" "$dest"; then
            backup="$dest.backup.$(date +%Y%m%d-%H%M%S)"
            cp -a -- "$dest" "$backup"
            echo "BACKUP=$backup"
        fi
        install -Dm644 -- "$mo" "$dest"
        printf '%s  %s\n' "$mo_sha" "$dest" | sha256sum --check --status
        echo "USER_INSTALL=PASS"
    elif [[ -f "$dest" ]]; then
        if cmp -s "$mo" "$dest"; then
            echo "INSTALLED_CATALOG=PASS"
        else
            echo "INSTALLED_CATALOG=DIFFERENT"
        fi
    else
        echo "INSTALLED_CATALOG=ABSENT"
    fi
done

echo "SUDO=NO; PLASMA_CONFIG_WRITES=NO; PLASMA_RESTART=NO"
echo "Visual verification after logout/login is a separate check."

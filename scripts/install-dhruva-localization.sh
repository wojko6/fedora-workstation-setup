#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXT="$HOME/.local/share/gnome-shell/extensions/dhruva@narkagni"
PATCH_DIR="$ROOT_DIR/patches/gnome-extensions/dhruva"
PO="$ROOT_DIR/localization/dhruva/pl.po"
GENERATOR="$ROOT_DIR/scripts/generate-dhruva-emoji-pl.py"

DOMAIN="dhruva"
MO_REL="locale/pl/LC_MESSAGES/${DOMAIN}.mo"
EMOJI_REL="src/ui/folder-menu/emoji-pl.js"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

apply_exact_patch() {
    local root="$1"
    local patchfile="$2"
    local output

    if ! output="$(
        patch --batch --forward --fuzz=0 \
            --directory="$root" \
            -p1 < "$patchfile" 2>&1
    )"; then
        printf '%s\n' "$output" >&2
        return 1
    fi

    if grep -Eqi 'offset|fuzz' <<<"$output"; then
        printf '%s\n' "$output" >&2
        return 1
    fi

    return 0
}

echo "=== DHRUVA POLISH LOCALIZATION ==="

# ------------------------------------------------------------
# 1. Preconditions
# ------------------------------------------------------------

[[ -d "$EXT" ]] ||
    die "Dhruva extension is not installed: $EXT"

[[ -f "$EXT/metadata.json" ]] ||
    die "missing metadata.json"

[[ -d "$PATCH_DIR" ]] ||
    die "missing patch directory"

[[ -f "$PO" ]] ||
    die "missing Polish PO file"

[[ -x "$GENERATOR" ]] ||
    die "emoji generator is missing or not executable"

command -v patch >/dev/null ||
    die "patch command is missing"

command -v msgfmt >/dev/null ||
    die "msgfmt command is missing"

command -v python3 >/dev/null ||
    die "python3 is missing"

PATCH_COUNT="$(
    find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | wc -l
)"

[[ "$PATCH_COUNT" -eq 20 ]] ||
    die "expected 20 Dhruva patches, found $PATCH_COUNT"

pass "20 localization patches found"

# ------------------------------------------------------------
# 2. Translation validation
# ------------------------------------------------------------

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

msgfmt --check "$PO" -o "$TMP/dhruva.mo" ||
    die "pl.po validation failed"

pass "pl.po validated"

# ------------------------------------------------------------
# 3. Work on a temporary copy first
# ------------------------------------------------------------

cp -a "$EXT" "$TMP/dhruva"

PATCHED=0
ALREADY=0

while IFS= read -r patchfile; do
    name="$(basename "$patchfile")"

    # SweetTooth rewrites metadata.json and adds fields such as
    # _generated/version. Therefore reverse-patching metadata is not
    # a reliable way to detect an already installed gettext domain.
    if [[ "$name" == "metadata-gettext.patch" ]] &&
       grep -q '"gettext-domain"[[:space:]]*:[[:space:]]*"dhruva"' \
           "$TMP/dhruva/metadata.json"; then

        echo "PASS: already applied: $name"
        ALREADY=$((ALREADY + 1))
        continue
    fi

    if FORWARD_OUTPUT="$(
        patch \
            --dry-run \
            --batch \
            --forward \
            --fuzz=0 \
            --directory="$TMP/dhruva" \
            -p1 < "$patchfile" 2>&1
    )"; then
        FORWARD_RC=0
    else
        FORWARD_RC=$?
    fi

    if [[ "$FORWARD_RC" -eq 0 ]]; then
        if grep -Eqi 'offset|fuzz' <<<"$FORWARD_OUTPUT"; then
            printf '%s\n' "$FORWARD_OUTPUT" >&2
            die "forward dry-run requires offset/fuzz: $name"
        fi

        if apply_exact_patch "$TMP/dhruva" "$patchfile"; then
            echo "PASS: exact applicable: $name"
            PATCHED=$((PATCHED + 1))
        else
            die "exact patch application failed: $name"
        fi

        continue
    fi

    if REVERSE_OUTPUT="$(
        patch \
            --dry-run \
            --batch \
            --reverse \
            --fuzz=0 \
            --directory="$TMP/dhruva" \
            -p1 < "$patchfile" 2>&1
    )"; then
        REVERSE_RC=0
    else
        REVERSE_RC=$?
    fi

    if [[ "$REVERSE_RC" -eq 0 ]]; then
        if grep -Eqi 'offset|fuzz' <<<"$REVERSE_OUTPUT"; then
            printf '%s\n' "$REVERSE_OUTPUT" >&2
            die "reverse dry-run requires offset/fuzz: $name"
        fi

        echo "PASS: already applied: $name"
        ALREADY=$((ALREADY + 1))
        continue
    fi

    die "incompatible patch: $name"
done < <(
    find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | sort
)

TOTAL=$((PATCHED + ALREADY))

[[ "$TOTAL" -eq 20 ]] ||
    die "patch validation incomplete: $TOTAL/20"

pass "exact patch compatibility 20/20"

# ------------------------------------------------------------
# 4. Generate Polish CLDR emoji database on temporary copy
# ------------------------------------------------------------

python3 "$GENERATOR" \
    --source "$TMP/dhruva/src/ui/emojis.js" \
    --output "$TMP/dhruva/$EMOJI_REL"

EMOJI_COUNT="$(
    grep -c '^  "' "$TMP/dhruva/$EMOJI_REL"
)"

[[ "$EMOJI_COUNT" -eq 1907 ]] ||
    die "expected 1907 Polish emoji entries, found $EMOJI_COUNT"

grep -q '^export default emojiPl;$' \
    "$TMP/dhruva/$EMOJI_REL" ||
    die "invalid emoji-pl.js export"

pass "Polish CLDR emoji 1907/1907"

# ------------------------------------------------------------
# 5. Install MO into temporary copy
# ------------------------------------------------------------

mkdir -p "$(dirname "$TMP/dhruva/$MO_REL")"

install -m 0644 \
    "$TMP/dhruva.mo" \
    "$TMP/dhruva/$MO_REL"

cmp -s \
    "$TMP/dhruva.mo" \
    "$TMP/dhruva/$MO_REL" ||
    die "temporary MO verification failed"

pass "dhruva.mo prepared"

# ------------------------------------------------------------
# 6. Final validation before touching live extension
# ------------------------------------------------------------

grep -q '"gettext-domain": "dhruva"' \
    "$TMP/dhruva/metadata.json" ||
    die "gettext-domain validation failed"

grep -q "_('Window')" \
    "$TMP/dhruva/src/ui/context-menu/WindowThumbnailBuilder.js" ||
    die "Window gettext validation failed"

grep -q "_('Monitor %s')" \
    "$TMP/dhruva/src/prefs/LayoutPage.js" ||
    die "Monitor gettext validation failed"

grep -q 'emojiPl' \
    "$TMP/dhruva/src/ui/folder-menu/EmojiPicker.js" ||
    die "EmojiPicker integration validation failed"

pass "temporary localized Dhruva validated"

# ------------------------------------------------------------
# 7. Apply patches to live extension
# ------------------------------------------------------------

LIVE_PATCHED=0
LIVE_ALREADY=0

while IFS= read -r patchfile; do
    name="$(basename "$patchfile")"

    # SweetTooth may rewrite metadata.json and add/reorder its own
    # fields. Presence of our exact gettext domain is therefore the
    # reliable idempotency check for the metadata patch.
    if [[ "$name" == "metadata-gettext.patch" ]] &&
       grep -q '"gettext-domain"[[:space:]]*:[[:space:]]*"dhruva"' \
           "$EXT/metadata.json"; then

        echo "PASS: already installed: $name"
        LIVE_ALREADY=$((LIVE_ALREADY + 1))
        continue
    fi

    if FORWARD_OUTPUT="$(
        patch \
            --dry-run \
            --batch \
            --forward \
            --fuzz=0 \
            --directory="$EXT" \
            -p1 < "$patchfile" 2>&1
    )"; then
        FORWARD_RC=0
    else
        FORWARD_RC=$?
    fi

    if [[ "$FORWARD_RC" -eq 0 ]]; then
        if grep -Eqi 'offset|fuzz' <<<"$FORWARD_OUTPUT"; then
            printf '%s\n' "$FORWARD_OUTPUT" >&2
            die "live forward dry-run requires offset/fuzz: $name"
        fi

        if apply_exact_patch "$EXT" "$patchfile"; then
            echo "PASS: exact installed: $name"
            LIVE_PATCHED=$((LIVE_PATCHED + 1))
        else
            die "live exact patch application failed: $name"
        fi

        continue
    fi

    if REVERSE_OUTPUT="$(
        patch \
            --dry-run \
            --batch \
            --reverse \
            --fuzz=0 \
            --directory="$EXT" \
            -p1 < "$patchfile" 2>&1
    )"; then
        REVERSE_RC=0
    else
        REVERSE_RC=$?
    fi

    if [[ "$REVERSE_RC" -eq 0 ]]; then
        if grep -Eqi 'offset|fuzz' <<<"$REVERSE_OUTPUT"; then
            printf '%s\n' "$REVERSE_OUTPUT" >&2
            die "live reverse dry-run requires offset/fuzz: $name"
        fi

        echo "PASS: already installed: $name"
        LIVE_ALREADY=$((LIVE_ALREADY + 1))
        continue
    fi

    die "live extension became incompatible: $name"
done < <(
    find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | sort
)

LIVE_TOTAL=$((LIVE_PATCHED + LIVE_ALREADY))

[[ "$LIVE_TOTAL" -eq 20 ]] ||
    die "live patch installation incomplete: $LIVE_TOTAL/20"

pass "live patch state 20/20"

# ------------------------------------------------------------
# 8. Install generated artifacts
# ------------------------------------------------------------

mkdir -p "$(dirname "$EXT/$MO_REL")"

install -m 0644 \
    "$TMP/dhruva.mo" \
    "$EXT/$MO_REL"

install -m 0644 \
    "$TMP/dhruva/$EMOJI_REL" \
    "$EXT/$EMOJI_REL"

# ------------------------------------------------------------
# 9. Final live verification
# ------------------------------------------------------------

cmp -s "$TMP/dhruva.mo" "$EXT/$MO_REL" ||
    die "installed MO differs"

cmp -s \
    "$TMP/dhruva/$EMOJI_REL" \
    "$EXT/$EMOJI_REL" ||
    die "installed emoji database differs"

grep -q '"gettext-domain": "dhruva"' \
    "$EXT/metadata.json" ||
    die "live gettext-domain missing"

grep -q "_('Window')" \
    "$EXT/src/ui/context-menu/WindowThumbnailBuilder.js" ||
    die "live Window gettext missing"

LIVE_EMOJI="$(
    grep -c '^  "' "$EXT/$EMOJI_REL"
)"

[[ "$LIVE_EMOJI" -eq 1907 ]] ||
    die "live emoji database has $LIVE_EMOJI entries"

pass "Dhruva Polish localization installed"
pass "20/20 patches validated"
pass "393 gettext messages source validated"
pass "1907/1907 Polish CLDR emoji installed"

echo
echo "Sign out and sign back in if GNOME Shell is already running."

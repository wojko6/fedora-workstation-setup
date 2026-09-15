#!/usr/bin/env bash
set -Eeuo pipefail

OUT="${1:-gnome/extensions-inventory.tsv}"
mkdir -p "$(dirname "$OUT")"

printf 'uuid\tname\tversion\tshell_versions\turl\tlocation\n' > "$OUT"

for base in "$HOME/.local/share/gnome-shell/extensions" /usr/share/gnome-shell/extensions; do
  [[ -d "$base" ]] || continue
  for dir in "$base"/*; do
    [[ -f "$dir/metadata.json" ]] || continue
    python3 - "$dir/metadata.json" "$dir" >> "$OUT" <<'PY'
import json, sys
p, location = sys.argv[1:]
with open(p, encoding='utf-8') as f:
    m = json.load(f)
def clean(v):
    if isinstance(v, list):
        return ','.join(map(str, v))
    return '' if v is None else str(v)
vals = [m.get('uuid'), m.get('name'), m.get('version'), m.get('shell-version'), m.get('url'), location]
print('\t'.join(clean(v).replace('\t',' ').replace('\n',' ') for v in vals))
PY
  done
done

echo "Saved: $OUT"

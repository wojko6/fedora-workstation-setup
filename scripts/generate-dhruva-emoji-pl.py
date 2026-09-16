#!/usr/bin/env python3

from pathlib import Path
import argparse
import json
import re
import unicodedata
import xml.etree.ElementTree as ET


DEFAULT_EXT = (
    Path.home()
    / ".local/share/gnome-shell/extensions/dhruva@narkagni"
)

DEFAULT_EMOJI_FILE = DEFAULT_EXT / "src/ui/emojis.js"
DEFAULT_OUTPUT = Path("/tmp/emoji-pl.js")

CLDR_FILES = [
    Path("/usr/share/unicode/cldr/common/annotations/pl.xml"),
    Path("/usr/share/unicode/cldr/common/annotationsDerived/pl.xml"),
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate Polish CLDR emoji data for Dhruva."
    )

    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_EMOJI_FILE,
        help="Path to Dhruva src/ui/emojis.js",
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Destination emoji-pl.js",
    )

    return parser.parse_args()


def variants(text):
    result = []

    for value in (
        text,
        unicodedata.normalize("NFC", text),
        text.replace("\ufe0f", ""),
        unicodedata.normalize("NFC", text).replace("\ufe0f", ""),
    ):
        if value not in result:
            result.append(value)

    return result


def main():
    args = parse_args()

    emoji_file = args.source
    output_file = args.output

    if not emoji_file.is_file():
        raise SystemExit(
            f"ERROR: missing Dhruva emoji database: {emoji_file}"
        )

    # Dhruva emoji database
    source = emoji_file.read_text(encoding="utf-8")

    records = re.findall(
        r"emoji:\s*'([^']+)'.*?name:\s*'([^']+)'",
        source,
        re.S,
    )

    if not records:
        raise SystemExit("ERROR: no Dhruva emoji found")

    # Polish CLDR database
    cldr = {}

    for filename in CLDR_FILES:
        if not filename.exists():
            raise SystemExit(
                f"ERROR: missing CLDR file: {filename}"
            )

        root = ET.parse(filename).getroot()

        for node in root.iter("annotation"):
            cp = node.get("cp")
            value = (node.text or "").strip()

            if not cp or not value:
                continue

            entry = cldr.setdefault(
                cp,
                {
                    "name": None,
                    "keywords": [],
                },
            )

            if node.get("type") == "tts":
                entry["name"] = value
            else:
                for keyword in value.split("|"):
                    keyword = keyword.strip()

                    if (
                        keyword
                        and keyword not in entry["keywords"]
                    ):
                        entry["keywords"].append(keyword)

    # Build normalized lookup once
    lookup = {}

    for cp, data in cldr.items():
        for variant in variants(cp):
            lookup.setdefault(variant, data)

    output = {}
    missing = []

    for emoji, english_name in records:
        data = None

        for variant in variants(emoji):
            candidate = lookup.get(variant)

            if candidate and candidate["name"]:
                data = candidate
                break

        if not data:
            missing.append((emoji, english_name))
            continue

        output[emoji] = {
            "name": data["name"],
            "keywords": data["keywords"],
            "englishName": english_name,
        }

    if missing:
        print("ERROR: incomplete CLDR coverage")

        for emoji, name in missing[:50]:
            print(repr(emoji), "->", name)

        raise SystemExit(1)

    json_data = json.dumps(
        output,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )

    output_file.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    output_file.write_text(
        "// Generated from Unicode CLDR Polish emoji annotations.\n"
        "// Do not edit manually.\n\n"
        f"const emojiPl = {json_data};\n\n"
        "export default emojiPl;\n",
        encoding="utf-8",
    )

    print("PASS: Dhruva emoji:", len(records))
    print("PASS: Polish entries:", len(output))
    print("PASS: CLDR coverage: 100.00%")
    print("PASS: output:", output_file)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Checks the string catalogue is complete and its fallback is intact.

N85-14 AC5 asks that catalogued text uses the device's language and falls back
consistently to British English when a translation is unavailable. Today the
app ships one language, so the fallback is what actually carries the criterion:
every user-facing string must be in the catalogue with a real en-GB value, or a
device in any other locale gets a raw key on screen.

Three things are checked, each a way that fallback quietly breaks:

  1. The source language is still en-GB. If it changes, every unlocalised
     device falls back to something other than British English, which is the
     opposite of what the criterion asks for.
  2. Every entry has a non-empty value in a settled state. An entry marked
     "new" or "needs_review" is one somebody has not finished, and it reaches
     the screen looking finished.
  3. No user-facing text bypasses the catalogue with Text(verbatim:), which
     renders a literal and never localises. It is the one construct that looks
     identical on screen in development and cannot ever be translated.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "WootDesk" / "Resources" / "Localizable.xcstrings"
SOURCE = ROOT / "WootDesk"

EXPECTED_SOURCE_LANGUAGE = "en-GB"

# States Xcode uses for work that is not finished. "translated" is the settled
# one; anything else means a human still has to look at it.
UNSETTLED_STATES = {"new", "needs_review", "stale"}


def problems() -> list[str]:
    found: list[str] = []

    if not CATALOGUE.exists():
        return [f"The string catalogue is missing at {CATALOGUE.relative_to(ROOT)}."]

    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))

    source_language = catalogue.get("sourceLanguage")
    if source_language != EXPECTED_SOURCE_LANGUAGE:
        found.append(
            f"The catalogue's source language is {source_language!r}, not "
            f"{EXPECTED_SOURCE_LANGUAGE!r}. Every device without a translation "
            "would fall back to that language instead of British English."
        )

    strings = catalogue.get("strings", {})
    if not strings:
        found.append("The catalogue has no entries, so nothing is localised.")

    for key, entry in sorted(strings.items()):
        localisation = (entry.get("localizations") or {}).get(EXPECTED_SOURCE_LANGUAGE)
        shown = key if len(key) <= 60 else key[:57] + "..."

        if not localisation:
            found.append(f"{shown!r} has no {EXPECTED_SOURCE_LANGUAGE} entry, so it would render as its key.")
            continue

        unit = localisation.get("stringUnit") or {}
        value = (unit.get("value") or "").strip()
        state = unit.get("state")

        if not value:
            found.append(f"{shown!r} has an empty {EXPECTED_SOURCE_LANGUAGE} value.")
        if state in UNSETTLED_STATES:
            found.append(f"{shown!r} is marked {state!r}, which means it is not finished.")

    # Text(verbatim:) renders a literal and never localises. Grep rather than
    # parse: this is a single unambiguous construct, and a Swift parser here
    # would be more machinery than the rule deserves.
    verbatim = subprocess.run(
        ["grep", "-rn", "--include=*.swift", "verbatim:", str(SOURCE)],
        capture_output=True, text=True)
    for line in verbatim.stdout.splitlines():
        location, _, text = line.partition(":")
        found.append(f"{line.split(':')[0].replace(str(ROOT) + '/', '')} uses Text(verbatim:), which never localises.")

    return found


def main() -> int:
    found = problems()
    if found:
        print(f"Localisation: {len(found)} problem(s)\n")
        for problem in found:
            print(f"  - {problem}")
        return 1

    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    count = len(catalogue.get("strings", {}))
    print(
        f"Localisation: {count} entries, all settled, source language "
        f"{catalogue.get('sourceLanguage')}, nothing bypassing the catalogue."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

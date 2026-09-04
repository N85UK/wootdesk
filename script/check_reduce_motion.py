#!/usr/bin/env python3
"""Fails when a SwiftUI animation is not gated on Reduce Motion.

N85-14 AC4 requires that non-essential motion is removed when an agent turns
Reduce Motion on. The app satisfies that today by having almost no motion: the
only two explicit animations both read the accessibility environment and pass
nil when it is set. Motion the system owns (navigation pushes, sheets) is
already suppressed by iOS itself.

The risk is not those two lines, it is the third animation somebody adds later
without the gate. This check reads the source rather than the running app,
because an animation that ignores the setting is a property of the code and is
invisible to a UI test: the test passes whether or not the motion was removed.

A construct counts as gated when the reduce-motion state is consulted inside it,
either directly or through a helper whose name carries the term.
"""
import re
import sys
from pathlib import Path

SOURCE_ROOT = Path(__file__).resolve().parent.parent / "WootDesk"

# Constructs that put motion on screen. Implicit system animations are excluded
# deliberately: iOS suppresses those under Reduce Motion without the app asking.
MOTION = re.compile(r"\.animation\(|withAnimation|\.transition\(|repeatForever")

# The gate: the environment value, or any identifier naming it.
GATE = re.compile(r"(?i)reduce_?motion")

# A gate on the enclosing declaration counts, so a view may resolve the value
# once into a local and use it across several modifiers.
LOOKBACK_LINES = 6


def offences():
    for path in sorted(SOURCE_ROOT.rglob("*.swift")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, start=1):
            if not MOTION.search(line) or line.lstrip().startswith("//"):
                continue
            window = lines[max(0, number - 1 - LOOKBACK_LINES):number]
            if any(GATE.search(previous) for previous in window):
                continue
            yield path, number, line.strip()


def main():
    found = list(offences())
    if not found:
        print("reduce motion: every animation is gated on the accessibility setting")
        return 0

    print("Animation that ignores Reduce Motion (N85-14 AC4):\n")
    for path, number, line in found:
        relative = path.relative_to(SOURCE_ROOT.parent)
        print(f"  {relative}:{number}")
        print(f"    {line}")
    print(
        "\nPass nil for the animation when the setting is on, for example:\n"
        "  @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n"
        "  .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: x)"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())

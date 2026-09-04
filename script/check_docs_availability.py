#!/usr/bin/env python3
"""Checks that docs.n85.app is serving, for N85-47 AC11.

Three probes rather than one, because a documentation site fails in parts. The
home page can serve while search is broken, and search can work while a content
route 404s after a routing change. One request to the root would have reported
all three of those as healthy.

Deliberately records nothing but the URL, the status and the elapsed time. AC11
requires an actionable failure without storing visitor content or credentials,
so response bodies are matched and discarded, never logged. A monitor that
prints the page it fetched is a monitor that eventually prints something
private.

Exit status is 0 when every probe passes and 1 when any fails, so a scheduled
workflow can branch on it without parsing this output.
"""
import subprocess
import sys
import time

SITE = "https://docs.n85.app"

# Each probe names what breaks for a reader when it fails, because a failure
# reading "GET /pagefind/pagefind.js returned 404" needs that context at 3am.
PROBES = [
    ("/", "the documentation home page", "WootDesk"),
    ("/pagefind/pagefind.js", "the search index, without which search silently returns nothing", None),
    ("/help/support/", "the support page the App Store listing points at", None),
]

TIMEOUT_SECONDS = 20


def probe(path: str, marker: str | None) -> tuple[bool, str]:
    """Fetches one URL and reports the status, never the body."""
    url = f"{SITE}{path}"
    started = time.monotonic()
    result = subprocess.run(
        ["curl", "--silent", "--show-error", "--location", "--max-time", str(TIMEOUT_SECONDS),
         "--write-out", "\n%{http_code}", url],
        capture_output=True, text=True)
    elapsed = time.monotonic() - started

    if result.returncode != 0:
        # curl's own message names the transport failure, such as a TLS or DNS
        # error, which is the actionable part.
        return False, f"{path} did not respond: {result.stderr.strip()[:120]} ({elapsed:.1f}s)"

    body, _, status = result.stdout.rpartition("\n")
    if status != "200":
        return False, f"{path} returned {status} ({elapsed:.1f}s)"

    # The marker guards against a soft 404: a page that returns 200 while
    # serving the wrong content. Only whether it matched is reported.
    if marker is not None and marker not in body:
        return False, f"{path} returned 200 but did not contain the expected marker ({elapsed:.1f}s)"

    return True, f"{path} ok ({elapsed:.1f}s)"


def main() -> int:
    failures = []
    for path, consequence, marker in PROBES:
        ok, detail = probe(path, marker)
        print(("  ok    " if ok else "  FAIL  ") + detail)
        if not ok:
            failures.append(f"{detail}. This breaks {consequence}.")

    if failures:
        print(f"\ndocs.n85.app: {len(failures)} of {len(PROBES)} probes failed\n")
        for f in failures:
            print(f"  - {f}")
        return 1

    print(f"\ndocs.n85.app: all {len(PROBES)} probes passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Fails when tracked files carry material that does not belong in a public repository.

This repository is public. Nothing here has ever held a credential, but it did
accumulate the next tier down: an Apple team identifier, certificate subject
identifiers, the maintainer's address, the secret store's hostname and the
deployment host's paths. None of those grant access, and all of them describe
the account and infrastructure to anyone reading.

The rules below match shapes rather than the specific values, so this file does
not reintroduce what it exists to keep out.
"""
import re
import subprocess
import sys

RULES = [
    (
        "provider-token",
        re.compile(r"\b(?:ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})"),
        "A provider access token must never be committed.",
    ),
    (
        "credential-assignment",
        re.compile(
            r"(?i)\b(?:api[_-]?key|access[_-]?token|secret[_-]?key|auth[_-]?key|password)"
            r"\s*[:=]\s*[\"']?[A-Za-z0-9_\-]{20,}[\"']?"
        ),
        "A literal credential value. Read it from the secret store instead.",
    ),
    (
        "certificate-subject-identifier",
        re.compile(r"\bUID=[A-Z0-9]{10}\b"),
        "A certificate subject identifier names the signing account.",
    ),
    (
        "apple-signing-identity",
        re.compile(r"Apple (?:Development|Distribution): [A-Za-z][A-Za-z .'-]+ \([A-Z0-9]{10}\)"),
        "A signing identity names the account and its team. Use a placeholder.",
    ),
    (
        "deployment-host-path",
        re.compile(r"ssh [a-z0-9_-]+ ['\"]?cd /(?:opt|srv|home)/"),
        "A deployment host alias with an absolute path describes private infrastructure.",
    ),
]

# Lines that name a pattern in order to forbid or explain it.
ALLOW = re.compile(r"(?i)placeholder|example|invented|must-not-be|<[A-Z_]+>|forbid|redact")

PEM_HEADER = re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----")
PEM_BODY = re.compile(r"^[A-Za-z0-9+/=]{40,}$")


def private_key_findings(path, lines):
    """Reports a PEM header only when key material follows it.

    Documentation legitimately quotes the header to say what a valid key looks
    like. Matching the header alone flags that prose, which trains the reader to
    ignore the check, so the body has to be present too.
    """
    findings = []
    for number, line in enumerate(lines, start=1):
        if not PEM_HEADER.search(line):
            continue
        following = lines[number : number + 4]
        if any(PEM_BODY.match(item.strip()) for item in following):
            findings.append(
                (path, number, "private-key", "A private key must never be committed.")
            )
    return findings


def tracked_files():
    out = subprocess.run(
        ["git", "ls-files"], capture_output=True, text=True, check=True
    ).stdout.splitlines()
    skip = (".png", ".jpg", ".jpeg", ".webp", ".pdf", ".zip", ".ico", ".woff2")
    return [f for f in out if not f.endswith(skip) and "node_modules/" not in f]


def main() -> int:
    findings = []
    for path in tracked_files():
        if path == "script/check_public_repo.py":
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                lines = handle.readlines()
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        findings.extend(private_key_findings(path, lines))
        for number, line in enumerate(lines, start=1):
            if ALLOW.search(line):
                continue
            for name, pattern, explanation in RULES:
                if pattern.search(line):
                    findings.append((path, number, name, explanation))

    if not findings:
        print(f"Public repository check: clean. Scanned {len(tracked_files())} tracked files.")
        return 0

    print(f"Public repository check: {len(findings)} finding(s).\n")
    for path, number, name, explanation in findings:
        print(f"  {path}:{number}  [{name}]")
        print(f"    {explanation}\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Read-only strict-TLS retirement probes. Never print response bodies."""
import argparse
import datetime
import hashlib
import http.client
import json
from pathlib import Path
import re
import ssl
import sys
import time

HOST = 'docs.n85.app'
MAX_BODY = 64 * 1024
TIMEOUT_SECONDS = 20
RETIREMENT_BODY_SHA256 = 'e29ed5915eddc2df3588094d3b9bb5d0b3deba284f1902998983f3c6e3ea6db6'
CSP = "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
PROBES = [
    ('GET', '/', 410), ('HEAD', '/', 410),
    ('GET', '/help/support/', 410), ('GET', '/pagefind/pagefind.js', 410),
    ('GET', '/_astro/retired.js', 410), ('GET', '/downloads/WootDesk.dmg', 410),
    ('GET', '/retirement-negative-route/', 410), ('GET', '/build-info.json/', 410),
    ('OPTIONS', '/build-info.json', 410),
    ('GET', '/build-info.json', 200), ('HEAD', '/build-info.json', 200),
]


def valid_metadata(value):
    if type(value) is not dict or set(value) != {'commit', 'built', 'retired'}:
        return False
    if type(value['commit']) is not str or not re.fullmatch('[a-f0-9]{40}', value['commit']) or value['retired'] is not True:
        return False
    if type(value['built']) is not str or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z', value['built']):
        return False
    try:
        parsed = datetime.datetime.fromisoformat(value['built'].replace('Z', '+00:00'))
        return parsed.isoformat(timespec='milliseconds').replace('+00:00', 'Z') == value['built']
    except ValueError:
        return False


def fetch(path, method):
    # HTTPSConnection verifies the fixed hostname and never follows Location.
    connection = http.client.HTTPSConnection(HOST, timeout=TIMEOUT_SECONDS, context=ssl.create_default_context())
    try:
        connection.request(method, path, headers={'Connection': 'close', 'User-Agent': 'wootdesk-retirement-probe/1'})
        response = connection.getresponse()
        body = response.read(MAX_BODY + 1)
        headers = {key.lower(): value for key, value in response.getheaders()}
        return response.status, headers, body
    finally:
        connection.close()


def validate_response(method, path, expected_status, status, headers, body, expected_metadata=None):
    if status != expected_status or 'location' in headers:
        return False, 'unexpected_status_or_redirect'
    if len(body) > MAX_BODY:
        return False, 'response_oversized'
    required = {'cache-control': 'no-store', 'x-robots-tag': 'noindex, nofollow, noarchive',
                'x-content-type-options': 'nosniff', 'content-security-policy': CSP}
    if any(headers.get(key) != value for key, value in required.items()):
        return False, 'retirement_headers_missing'
    metadata_request = path == '/build-info.json' and method in ('GET', 'HEAD')
    content_type = 'application/json; charset=utf-8' if metadata_request else 'text/html; charset=utf-8'
    if headers.get('content-type') != content_type:
        return False, 'unexpected_content_type'
    if method == 'HEAD':
        return (False, 'head_body_present') if body else (True, 'ok')
    if not metadata_request:
        return (True, 'ok') if hashlib.sha256(body).hexdigest() == RETIREMENT_BODY_SHA256 else (False, 'retirement_body_mismatch')
    try:
        def unique(rows):
            value = {}
            for key, item in rows:
                if key in value:
                    raise ValueError('duplicate')
                value[key] = item
            return value
        value = json.loads(body, object_pairs_hook=unique)
    except (ValueError, UnicodeDecodeError):
        return False, 'invalid_metadata_json'
    if not valid_metadata(value):
        return False, 'invalid_retirement_metadata'
    if expected_metadata is not None and value != expected_metadata:
        return False, 'deployed_metadata_mismatch'
    return True, 'ok'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--expected-build-info', type=Path)
    args = parser.parse_args(argv)
    expected = None
    if args.expected_build_info:
        try:
            raw = args.expected_build_info.read_bytes()
            if len(raw) > 1024:
                raise ValueError('size')
            expected = json.loads(raw)
            if not valid_metadata(expected):
                raise ValueError('shape')
        except (OSError, ValueError, UnicodeDecodeError):
            print('FAIL expected_build_info_invalid')
            return 1
    failures = 0
    for method, path, status in PROBES:
        started = time.monotonic()
        try:
            result = fetch(path, method)
            ok, detail = validate_response(method, path, status, *result, expected_metadata=expected)
        except (OSError, http.client.HTTPException, ValueError):
            ok, detail = False, 'transport_or_tls_failure'
        elapsed = time.monotonic() - started
        print(f'{"ok" if ok else "FAIL"} {method} {path} {detail} ({elapsed:.1f}s)')
        failures += not ok
    print(f'docs retirement: {len(PROBES) - failures}/{len(PROBES)} probes passed')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())

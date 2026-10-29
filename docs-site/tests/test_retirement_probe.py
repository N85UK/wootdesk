"""Offline retirement monitor contract. Every connection is fake."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import ssl
import unittest
from unittest import mock

SOURCE = Path(__file__).resolve().parents[2] / 'script/check_docs_availability.py'
spec = importlib.util.spec_from_file_location('retirement_probe', SOURCE)
probe = importlib.util.module_from_spec(spec)
exec(compile(SOURCE.read_bytes(), str(SOURCE), 'exec'), probe.__dict__)
INFO = {'commit': 'a' * 40, 'built': '2026-10-29T08:00:00.000Z', 'retired': True}
HEADERS = {'cache-control': 'no-store', 'x-robots-tag': 'noindex, nofollow, noarchive',
           'x-content-type-options': 'nosniff', 'content-security-policy': probe.CSP,
           'content-type': 'application/json; charset=utf-8'}


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.no_network = mock.patch.object(probe.http.client, 'HTTPSConnection', side_effect=AssertionError('network forbidden'))
        self.no_network.start(); self.addCleanup(self.no_network.stop)

    def test_valid_and_exact_metadata(self):
        self.assertTrue(probe.valid_metadata(INFO))
        self.assertEqual(probe.validate_response('GET', '/build-info.json', 200, 200, HEADERS, json.dumps(INFO).encode(), INFO), (True, 'ok'))
        changed = {**INFO, 'commit': 'b' * 40}
        self.assertEqual(probe.validate_response('GET', '/build-info.json', 200, 200, HEADERS, json.dumps(changed).encode(), INFO), (False, 'deployed_metadata_mismatch'))

    def test_metadata_shape_type_dates_and_duplicate_key_refuse(self):
        for value in [{}, [], {**INFO, 'retired': False}, {**INFO, 'retired': 1}, {**INFO, 'commit': ['a' * 40]},
                      {**INFO, 'commit': 'bad'}, {**INFO, 'extra': True}, {**INFO, 'built': '2026-02-31T08:00:00.000Z'}]:
            with self.subTest(value_kind=type(value).__name__):self.assertFalse(probe.valid_metadata(value))
        duplicate = b'{"commit":"' + b'a' * 40 + b'","built":"2026-10-29T08:00:00.000Z","retired":false,"retired":true}'
        self.assertFalse(probe.validate_response('GET', '/build-info.json', 200, 200, HEADERS, duplicate)[0])

    def test_redirect_old_success_missing_headers_and_head_body_refuse(self):
        for status in [200, 301, 302, 307, 308, 404, 500]:
            self.assertFalse(probe.validate_response('GET', '/', 410, status, HEADERS, b'public fixture')[0])
        self.assertFalse(probe.validate_response('GET', '/build-info.json', 200, 200, {**HEADERS, 'location': 'https://example.invalid'}, json.dumps(INFO).encode())[0])
        for key in HEADERS:
            changed = copy.deepcopy(HEADERS); del changed[key]
            self.assertFalse(probe.validate_response('GET', '/build-info.json', 200, 200, changed, json.dumps(INFO).encode())[0])
        self.assertFalse(probe.validate_response('HEAD', '/build-info.json', 200, 200, HEADERS, b'not empty')[0])
        self.assertTrue(probe.validate_response('HEAD', '/build-info.json', 200, 200, HEADERS, b'')[0])

    def test_retirement_body_is_exact_and_size_bound_is_enforced(self):
        headers = {**HEADERS, 'content-type': 'text/html; charset=utf-8'}
        body = b'public synthetic retirement fixture'
        with mock.patch.object(probe, 'RETIREMENT_BODY_SHA256', hashlib.sha256(body).hexdigest()):
            self.assertTrue(probe.validate_response('GET', '/', 410, 410, headers, body)[0])
            self.assertFalse(probe.validate_response('GET', '/', 410, 410, headers, body + b'old docs')[0])
        self.assertFalse(probe.validate_response('GET', '/', 410, 410, headers, b'x' * (probe.MAX_BODY + 1))[0])

    def test_strict_tls_fixed_host_no_redirect_follow_and_bounded_read(self):
        context = ssl.create_default_context()
        self.assertTrue(context.check_hostname); self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        response = mock.Mock(status=301)
        response.read.return_value = b''; response.getheaders.return_value = [('Location', 'https://example.invalid')]
        connection = mock.Mock(); connection.getresponse.return_value = response
        with mock.patch.object(probe.ssl, 'create_default_context', return_value=context), \
             mock.patch.object(probe.http.client, 'HTTPSConnection', return_value=connection) as factory:
            status, headers, _ = probe.fetch('/', 'GET')
        factory.assert_called_once_with(probe.HOST, timeout=20, context=context)
        self.assertEqual(connection.request.call_count, 1)
        response.read.assert_called_once_with(probe.MAX_BODY + 1)
        connection.close.assert_called_once(); self.assertEqual(status, 301); self.assertIn('location', headers)

    def test_tls_and_probe_failure_are_false_without_body_or_exception_values(self):
        with mock.patch.object(probe, 'fetch', side_effect=ssl.SSLError('private-sentinel')), mock.patch('sys.stdout', new_callable=io.StringIO) as output:
            self.assertEqual(probe.main([]), 1)
        self.assertNotIn('private-sentinel', output.getvalue()); self.assertIn('transport_or_tls_failure', output.getvalue())

    def test_complete_probe_table_and_exact_ci_metadata_with_no_network(self):
        retired_body = b'public synthetic retirement fixture'
        for mismatch in (False, True):
            calls = []
            def fetched(path, method):
                calls.append((method, path))
                metadata = path == '/build-info.json' and method in ('GET', 'HEAD')
                headers = {**HEADERS, 'content-type': 'application/json; charset=utf-8' if metadata else 'text/html; charset=utf-8'}
                info = {**INFO, 'commit': 'b' * 40} if mismatch else INFO
                body = b'' if method == 'HEAD' else json.dumps(info).encode() if metadata else retired_body
                return (200 if metadata else 410), headers, body
            with mock.patch.object(probe, 'fetch', side_effect=fetched), \
                 mock.patch.object(probe, 'RETIREMENT_BODY_SHA256', hashlib.sha256(retired_body).hexdigest()), \
                 mock.patch.object(Path, 'read_bytes', return_value=json.dumps(INFO).encode()), \
                 mock.patch('sys.stdout', new_callable=io.StringIO) as output:
                self.assertEqual(probe.main(['--expected-build-info', 'public-build-info.json']), 1 if mismatch else 0)
            self.assertEqual(calls, [(method, path) for method, path, _ in probe.PROBES])
            self.assertNotIn(retired_body.decode(), output.getvalue())


if __name__ == '__main__':
    unittest.main()

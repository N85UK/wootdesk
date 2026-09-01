#!/usr/bin/env python3
"""Prints a short-lived App Store Connect API token.

Reads the key material from Infisical (WootDesk, prod, /apple) so no secret is
stored here or passed on a command line. The token lasts fifteen minutes.

Used because Python's certificate store on this machine does not trust the
Infisical host, so requests go through curl:

    TOKEN=$(python3 script/asc_token.py)
    curl -H "Authorization: Bearer $TOKEN" https://api.appstoreconnect.apple.com/v1/apps

This exists for release-time inspection and metadata fixes that the App Store
Connect web interface does not expose reliably to automation, such as setting
the privacy policy URL on an app info localisation.
"""
import base64, json, time, subprocess
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils
b64 = lambda d: base64.urlsafe_b64encode(d).rstrip(b"=")
def inf(k):
    return subprocess.run(["infisical","secrets","get",k,"--env=prod","--path=/apple","--plain","--silent"],
                          capture_output=True, text=True, check=True).stdout.strip()
KEY_ID, ISSUER = inf("ASC_KEY_ID"), inf("ASC_ISSUER_ID")
key = serialization.load_pem_private_key(base64.b64decode(inf("ASC_KEY_P8")), password=None)
now = int(time.time())
si = b64(json.dumps({"alg":"ES256","kid":KEY_ID,"typ":"JWT"},separators=(",",":")).encode()) + b"." + \
     b64(json.dumps({"iss":ISSUER,"iat":now,"exp":now+900,"aud":"appstoreconnect-v1"},separators=(",",":")).encode())
r,s = utils.decode_dss_signature(key.sign(si, ec.ECDSA(hashes.SHA256())))
print((si + b"." + b64(r.to_bytes(32,"big")+s.to_bytes(32,"big"))).decode(), end="")

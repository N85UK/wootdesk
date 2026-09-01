# TestFlight Delivery

Document ID: `WOOT-TF-001`

Status: Working end to end; every green push to main delivers to TestFlight

Owner: N85 Dev

Last reviewed: 1 September 2026, evening

## Purpose

Once its secrets are configured, every green build on `main` is delivered to
TestFlight automatically, so end-to-end testing happens against the current
source instead of against a stale foundation build. The workflow is committed
and correct; it is not yet armed. See the blocker section below.

This exists because TestFlight long offered only **build 2**, which predates the
Milestone 2 source changes and can neither send replies nor show message
history. Testing against it said nothing about the app being built that day.
**Build 24**, uploaded on 1 September 2026, now carries the current source, so
the immediate problem is solved. The pipeline is what keeps it solved without
a manual upload each time.

## Why this can run before the App Store blockers are cleared

TestFlight accepts binaries built with a beta Xcode. Only App Store review
requires a stable toolchain. The pipeline therefore passes
`--allow-beta-xcode`, which prints a warning and continues, while
`script/release_archive.sh` still refuses a beta toolchain for an App Store
submission build.

### A separate requirement: the SDK, not the toolchain channel

Beta versus stable is not the only toolchain constraint, and conflating the two
cost a build. Apple rejects **any** upload built against an SDK earlier than
iOS 26, TestFlight included:

```text
Validation failed (409) SDK version issue. This app was built with the iOS 18.5
SDK. All iOS and iPadOS apps must be built with the iOS 26 SDK or later,
included in Xcode 26 or later, in order to be uploaded to App Store Connect or
submitted for distribution.
```

This surfaced on run 33542933506. The `macos-15` runner image carries only the
iOS 18.5 SDK, so the archive built and exported cleanly and was then refused at
validation, several minutes in, as an opaque 409. Local delivery of build 24
succeeded because this machine runs Xcode 27 with the iOS 27 SDK.

The job now runs on `macos-26` and selects the newest installed Xcode, then
checks the iOS SDK is 26 or later and fails immediately with a readable message
if it is not. That converts a late, cryptic rejection into an early, obvious
one.

An App Store Connect API key also lets `xcodebuild` create and refresh
Xcode-managed provisioning profiles unattended. That sidesteps the stale
distribution profiles described in `docs/DELIVERY.md`, because the profile is
regenerated during the build rather than read from a cache.

## App Store Connect API access, granted

This was previously recorded as the blocking prerequisite. It is no longer.

Verified on 1 September 2026: a Team Key exists, and a token minted by
`script/asc_token.py` authenticates against `GET /v1/apps`, returning HTTP 200
and listing `dev.n85.wootdesk`. The key also refreshes Xcode-managed
provisioning profiles unattended during a build, which is what cleared the
signing blocker described in `docs/DELIVERY.md`.

## The actual remaining blocker: secrets are not in GitHub Actions

All six values exist in Infisical and are verified. **None of them are set as
GitHub Actions secrets.** `gh secret list --repo N85UK/wootdesk` returns
nothing, so the guard step in the workflow finds `TEAM_ID`, `CERT` and
`KEY_ID` empty and skips the job. Every push to `main` therefore logs

```text
##[notice]TestFlight delivery secrets are not configured yet. See docs/TESTFLIGHT_DELIVERY.md. Skipping.
```

and completes in about twelve seconds without building anything. The runs show
as green, which is easy to misread as a successful delivery.

Build 24 reached TestFlight through an authorised **local** run of
`script/release_archive.sh`, not through this workflow.

Closing this means copying the six values into GitHub Actions, or wiring the
Infisical GitHub integration. Note what that changes: once the secrets are
present, every subsequent green push to `main` archives and uploads a new
build to TestFlight automatically. That is an outward-facing distribution
change and needs the release owner's explicit decision, not just the
credentials.

## Resolved: the blocker was an MRDP compliance declaration

Run 33543635103 built, exported, and verified a distribution-signed package,
then failed at the upload:

```text
A required agreement is missing or has expired. (403)
This request requires an in-effect agreement that has not been signed or has expired.
code: FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED
```

The error text points at agreements, and that reading was wrong. Both
agreements were `Active` throughout: Free Apps from 21 August 2026 and Paid
Apps from 31 August 2026, each running to 24 July 2027. Nothing had expired.

The actual cause was an outstanding **compliance** item on the same App Store
Connect page. Model Reporting Rules for Digital Platforms showed
`Missing Info`, requiring an answer to whether any app on the account provides
personal services. Apple reports an unanswered compliance declaration through
the same `REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED` code it uses for a genuinely
lapsed agreement, so the message does not distinguish the two.

Worth remembering if this recurs: **check the Compliance section, not just
Agreements.** An account can show every agreement `Active` and still refuse
uploads.

Answering the declaration cleared it immediately, with no change to the
repository. Run 33544372320 uploaded build 34, which processed to `VALID` and
is `IN_BETA_TESTING`.

## Where the secrets live## Where the secrets live

The values are held in Infisical on the self-hosted instance at
`https://id.n85.dev`, in the **WootDesk** project under the **prod**
environment at path **`/apple`**. The repository is linked to that project
through `.infisical.json`, which contains only the project identifier and no
secret material.

All six hold real, verified values. None is a `REPLACE_ME` placeholder:

| Key | Current |
|---|---|
| `APPLE_TEAM_ID` | `Z85CK5CNS3`, set |
| `ASC_KEY_ID` | set |
| `ASC_ISSUER_ID` | set |
| `ASC_KEY_P8` | set, PEM verified, authenticates against App Store Connect |
| `APPLE_DISTRIBUTION_CERT_P12` | set, single identity, verified to import and sign |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | set, randomly generated at export time |

### Running locally against Infisical

`script/release_archive.sh` reads all of these from the environment, so
Infisical can inject them directly. `ASC_KEY_P8` is decoded into a private
temporary file automatically, which is removed when the script exits.

```bash
infisical run --env=prod --path=/apple -- ./script/release_archive.sh --team Z85CK5CNS3 --allow-beta-xcode --upload --authorised-build <commit>
```

### Getting them into GitHub Actions

Two options.

1. **Infisical GitHub integration**, preferred. Point it at this repository and
   the `/apple` path in `prod`, and it keeps the Actions secrets in sync, so a
   rotated key never has to be copied twice.
2. **Copy once by hand** into the repository secrets below. Simpler to start,
   but the values then exist in two places and can drift.

## Repository secrets

Add these under Settings, Secrets and variables, Actions.

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | `Z85CK5CNS3` |
| `ASC_KEY_ID` | Key ID from the API key page |
| `ASC_ISSUER_ID` | Issuer ID from the API key page |
| `ASC_KEY_P8` | The `.p8` file, base64 encoded |
| `APPLE_DISTRIBUTION_CERT_P12` | The Apple Distribution certificate and private key exported as `.p12`, base64 encoded |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | The password set when exporting the `.p12` |

### Producing the distribution `.p12`

`security export` writes **every** identity in the login keychain, which here
includes unrelated certificates and their private keys. Those must not reach CI,
so the export is filtered down to the single Apple Distribution identity before
it is stored.

```bash
security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 -P "$PASS" -o all.p12
```

Then split it, match the Apple Distribution certificate to its private key by
public key, and re-export only that pair with `openssl pkcs12 -export`. The
stored value contains one identity and one key, which is what the pipeline
imports.

Verify a candidate before trusting it:

```bash
security import candidate.p12 -k /tmp/verify.keychain-db -P "$PASS" -T /usr/bin/codesign
```

`security find-identity -v -p codesigning /tmp/verify.keychain-db` must list
exactly `Apple Distribution: Paul McCann (Z85CK5CNS3)`. A `.p12` exported
without its private key imports without error but signs nothing, so checking the
identity list rather than the exit code is what catches it.

### `ASC_KEY_P8` must be the PEM, not DER

Apple issues the `.p8` as PEM text beginning `-----BEGIN PRIVATE KEY-----`.
`xcodebuild` and `altool` reject a DER-encoded key, and the failure appears as
an authentication error rather than a format error, which is misleading.

Confirm a stored value decodes to PEM:

```bash
infisical secrets get ASC_KEY_P8 --env=prod --path=/apple --plain | base64 --decode | head -1
```

That must print `-----BEGIN PRIVATE KEY-----`. If it prints binary, the value
was encoded from DER and must be converted with
`openssl pkey -inform DER -outform PEM` before re-encoding.

End-to-end check that the three App Store Connect values work together:

```bash
API_PRIVATE_KEYS_DIR=<dir containing AuthKey_KEYID.p8> xcrun altool --list-apps --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

### macOS installer signing

The stored `.p12` carries the Apple Distribution identity only, which covers iOS
and the macOS app. Signing a macOS **installer package** additionally needs the
`3rd Party Mac Developer Installer` identity, which is not included. Add it as a
separate secret when macOS delivery is enabled; iOS TestFlight does not need it.

Encode the two files without newlines:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
```

```bash
base64 -i distribution.p12 | tr -d '\n' | pbcopy
```

Export the `.p12` from Keychain Access: find **Apple Distribution: Paul McCann
(Z85CK5CNS3)**, expand it to confirm the private key is present, select both
rows, then Export Items. A certificate exported without its private key cannot
sign.

Until `APPLE_TEAM_ID`, `APPLE_DISTRIBUTION_CERT_P12` and `ASC_KEY_ID` are all
present the job logs a notice and skips, so pushes are never failed by missing
setup.

## What the pipeline does

1. Runs `script/ci.sh` in full. A red suite never reaches testers.
2. Imports the distribution certificate into a temporary keychain that is
   deleted afterwards, on success or failure.
3. Writes the API key to `~/.appstoreconnect/private_keys/` and removes it in
   the same cleanup step.
4. Archives with `CURRENT_PROJECT_VERSION` set to the workflow run number, which
   is monotonic, so every upload carries a unique increasing build number
   without editing `project.yml`.
5. Verifies the archive is distribution signed, failing if it carries
   `get-task-allow` or a development push environment.
6. Exports the App Store package and uploads it with `altool`.

Uploads are serialised by a concurrency group. Two runs must not race, because
they would otherwise claim the same build number.

## Running it

Automatic on every push to `main` that can change the binary. Pushes touching
only `docs/**`, markdown or `LICENSE` are skipped, because they cannot alter
the build and would otherwise spend a build number, six minutes of runner time
and a slot in every tester's update list. Builds 35 and 36 were spent that way
before the rule existed. `paths-ignore` is evaluated against the whole push, so
a commit touching documentation alongside code still delivers.

CI still runs on documentation-only pushes. It is cheap, and keeping the suite
green on every commit is worth the three minutes. To deliver on demand, or to deliver macOS,
use the Actions tab, TestFlight, Run workflow, and choose the platform. The
default is iOS.

## What this does not do

It does not submit for App Review. TestFlight distribution and App Store
submission are separate, and submission remains gated on the approvals in
N85-18 AC7 and on a stable Xcode.

It does not add testers. Adding the first internal testers is a one-time action
in App Store Connect under TestFlight, Internal Testing.

## Local equivalent

The same script drives a local delivery once the signing account is available:

```bash
./script/release_archive.sh --team Z85CK5CNS3 --build-number 5 --allow-beta-xcode --upload --authorised-build <commit>
```

Locally the credentials come from `ASC_KEY_ID`, `ASC_ISSUER_ID` and
`ASC_KEY_PATH`, or from `ASC_USERNAME` and `ASC_APP_PASSWORD`, read from the
environment so no secret appears in the process list or shell history.

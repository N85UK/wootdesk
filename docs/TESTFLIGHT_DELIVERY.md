# TestFlight Delivery

Document ID: `WOOT-TF-001`

Status: Pipeline implemented, secrets configured and verified

Owner: N85 Dev

Last reviewed: 1 September 2026

## Purpose

Every green build on `main` is delivered to TestFlight automatically, so
end-to-end testing happens against the current source instead of against a
stale foundation build.

This exists because TestFlight currently offers only **build 2**, which predates
the Milestone 2 source changes and cannot send replies or show message history.
Testing against it does not tell you anything about the app being built today.

## Why this can run before the App Store blockers are cleared

TestFlight accepts binaries built with a beta Xcode. Only App Store review
requires a stable toolchain. The pipeline therefore passes
`--allow-beta-xcode`, which prints a warning and continues, while
`script/release_archive.sh` still refuses a beta toolchain for an App Store
submission build.

An App Store Connect API key also lets `xcodebuild` create and refresh
Xcode-managed provisioning profiles unattended. That sidesteps the stale
distribution profiles described in `docs/DELIVERY.md`, because the profile is
regenerated during the build rather than read from a cache.

## Prerequisite: request App Store Connect API access

**This is the current blocker and nothing else can be configured before it.**

App Store Connect reports "Permission is required to access the App Store
Connect API" for this account, so no API key can be created yet.

1. Sign in to App Store Connect as the Account Holder.
2. Go to Users and Access, then Integrations, then App Store Connect API.
3. Choose **Request Access** and complete the prompt.
4. Create a **Team Key** with the **App Manager** role.
5. Download the `.p8` immediately. Apple allows exactly one download.
6. Note the **Key ID** and the **Issuer ID** from that page.

## Where the secrets live

The values are held in Infisical on the self-hosted instance at
`https://id.n85.dev`, in the **WootDesk** project under the **prod**
environment at path **`/apple`**. The repository is linked to that project
through `.infisical.json`, which contains only the project identifier and no
secret material.

The keys are already created with guidance in each secret's comment. Fill in
the values in place of `REPLACE_ME`:

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

Automatic on every push to `main`. To deliver on demand, or to deliver macOS,
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

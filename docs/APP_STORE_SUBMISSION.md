# App Store Submission Guide

Status: TestFlight submission guide and verified build ledger

Last verified against Apple documentation: 30 August 2026

## Release position

WootDesk has a registered App ID, an App Store Connect record, local Apple
Distribution signing, validated iOS and macOS build 2 archives, and an uploaded
iOS TestFlight candidate. It is not ready for public App Store submission
because message history and replies are deliberately outside the foundation
milestone. The recommended sequence is:

1. Keep iOS build 2 unassigned while release documentation is reviewed.
2. Complete conversation detail, message history, and replies.
3. Create a dedicated review-only Chatwoot environment with invented data.
4. Export and upload the macOS build, then verify platform association.
5. Add approved internal testers and complete the physical-device matrix.
6. Approve privacy, metadata, screenshots, and release-readiness gates.
7. Submit the iOS and macOS versions for App Review only after an explicit Go.

Apple account credentials, team identifiers, signing identities, and private
review access are never stored in this repository.

## Current repository configuration

| Item | Current value | Release meaning |
|---|---|---|
| Product | WootDesk | Shared product name |
| Bundle ID | `dev.n85.wootdesk` | Registered explicit App ID and App Store Connect bundle ID |
| Version | `1.0.0` | Marketing version, change only through reviewed release work |
| Build | `2` | Increment for every uploaded build |
| Platforms | iOS, iPadOS, macOS | One native SwiftUI multiplatform target |
| Minimum versions | iOS 18, iPadOS 18, macOS 15 | Must match App Store metadata and testing |
| Signing style | Automatic | A team is selected locally, not committed |
| macOS sandbox | Enabled | Outbound network client only |
| App icon | Complete | Separate iOS and macOS platform treatments |
| Privacy manifest | Present | Declares no tracking, collection, or required-reason API use in this build |

## Current verified submission state

| Item | State |
|---|---|
| Explicit App ID | Registered for `dev.n85.wootdesk` |
| App Store Connect record | Present for iOS, iPadOS, and macOS |
| Apple Distribution identity | Installed locally with an accessible private key |
| iOS build 1 | Superseded, Missing Compliance |
| iOS build 2 | Uploaded, processed, Ready to Submit |
| Build 2 export compliance | `ITSAppUsesNonExemptEncryption = false` |
| macOS build 2 | Signed universal archive validated locally, not exported or uploaded |
| TestFlight testers | None added |
| App Review | Not submitted |

Build 2 uses only Apple operating-system HTTPS, TLS, and Keychain cryptography.
The export-compliance declaration must be reviewed again if that implementation
changes.

## Apple account prerequisites

1. Confirm the release organisation has an active
   [Apple Developer Program membership](https://developer.apple.com/programs/).
2. Confirm the Account Holder has signed the latest agreement in App Store
   Connect. Apple will not allow a new app record until this is complete.
3. If WootDesk will be free with no in-app purchase, the Paid Apps Agreement,
   tax, and banking setup are not required for free distribution. Complete them
   before any paid app or in-app purchase is offered.
4. Give only the minimum App Store Connect roles needed for release work.

Apple documents agreement management in
[App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).

## Register the app identifier

An explicit App ID for `dev.n85.wootdesk` is registered in Certificates,
Identifiers and Profiles. Apple supports a single App ID across iOS and macOS.
Enable only the capabilities the release build uses.

The foundation build needs no CloudKit, push notification, associated domain,
in-app purchase, Sign in with Apple, camera, microphone, or location capability.
Do not enable capabilities speculatively.

Reference:
[Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/).

## Configure signing locally

`project.yml` enables automatic signing but intentionally contains no
`DEVELOPMENT_TEAM` value. This keeps personal and organisation team identifiers
out of the public repository. One Apple Distribution identity with an accessible
private key is installed on the release Mac; no certificate material is stored
in Git.

On the release Mac:

1. Open `WootDesk.xcodeproj` in Xcode.
2. Select the WootDesk target and open Signing & Capabilities.
3. Select the organisation's Apple Developer team.
4. Confirm Automatically manage signing is enabled for iOS and macOS.
5. Confirm the macOS build contains only the App Sandbox and outgoing network
   client entitlements.
6. Confirm the iOS build uses the default app Keychain access group created by
   its provisioning profile.
7. Do not commit the resulting personal team selection if Xcode writes it into
   project settings.

Apple's preparation guide explains team selection and supported destinations:
[Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution).

## Create the App Store Connect record

One App Store Connect app record now covers the iOS, iPadOS, and macOS versions.
Apple says a multiple-platform app offered together should use one record, one
bundle ID, and platform-specific information.

Suggested non-secret values:

| Field | Value |
|---|---|
| Platforms | iOS and macOS |
| Name | WootDesk |
| Primary language | English (U.K.) |
| Bundle ID | `dev.n85.wootdesk` |
| SKU | A stable internal value chosen by the Account Holder |
| User access | Limit if release responsibility is restricted |

References:

- [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)

### Current Apple documentation ambiguity

Apple's Xcode documentation explicitly supports iOS, iPadOS, and macOS in one
multiplatform app target. The App Store Connect universal-purchase page also
states that a macOS build should be uploaded from a separate Xcode target.

WootDesk retains the single target because it is the documented Xcode model and
the shared SwiftUI configuration is working. Before release, create and validate
both platform archives. If App Store Connect refuses to associate the macOS
archive from this target, create thin platform-specific distribution targets
that share the existing sources and services. Do not duplicate implementation
code merely to resolve this documentation mismatch.

References:

- [Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)

## Publish privacy information

Before public App Review submission:

1. Confirm `PRIVACY.md` remains on the public default branch.
2. Confirm its public URL works without authentication.
3. Review `PrivacyInfo.xcprivacy` against the exact release binary.
4. Complete App Store Connect's app privacy questions across all platforms.
5. Confirm whether N85 Dev or any third-party partner receives data from the
   app. The current source contains no analytics, advertising, or telemetry.
6. Reassess the answer if push, crash reporting, hosted AI, or another SDK is
   added.

Apple requires a privacy policy URL and accurate privacy answers:
[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

Privacy manifests are documented at
[Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

## Prepare listing metadata

Use `docs/APP_STORE_METADATA.md` as the non-secret draft. The release owner must
complete and verify:

- Name, subtitle, description, keywords, categories, and copyright.
- Support, marketing, and privacy-policy URLs.
- Platform-specific screenshots containing invented demo data only.
- App age-rating questionnaire.
- App Review contact details.
- Export-compliance questions.
- Release method, territories, price, and availability.

Apple currently permits one to ten screenshots per supported device size. App
previews are optional. Follow the current specifications shown in App Store
Connect rather than hardcoding device dimensions in the repository.

References:

- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)

## Prepare App Review access

WootDesk cannot be reviewed meaningfully without a Chatwoot server. Create a
dedicated review environment that:

- Contains invented people, accounts, inboxes, and messages only.
- Is isolated from production and customer environments.
- Uses HTTPS with a certificate trusted by Apple devices.
- Has a dedicated least-privilege agent account.
- Has a token that remains valid for the full review window.
- Supports the exact account-selection and conversation-list flows in the
  submitted build.
- Can be disabled after review without affecting customers.

Enter the server address and token only in private App Review information. Do
not commit them, put them in screenshots, or send them in public issue text.

Apple documents the sign-in and Notes fields in
[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

## Build and validate locally

Start from a clean checkout of the reviewed release commit:

```bash
xcodegen generate
./script/ci.sh --with-ui-tests
```

Then inspect the release configuration:

```bash
xcodebuild -showBuildSettings \
  -project WootDesk.xcodeproj \
  -scheme WootDesk \
  -configuration Release \
  -destination 'generic/platform=macOS'

xcodebuild -showBuildSettings \
  -project WootDesk.xcodeproj \
  -scheme WootDesk \
  -configuration Release \
  -destination 'generic/platform=iOS'
```

Review the output without publishing personal team identifiers. Confirm the
bundle ID, version, build number, minimum OS, app icon name, signing style,
entitlement path, and absence of debug-only transport exceptions.

## Create archives

Build 2 has signed iOS and macOS archives. The iOS archive was exported with
Apple Distribution signing and App Store provisioning. Its release package has
debug entitlement disabled, an arm64 executable, iOS 18 minimum deployment,
launch and orientation metadata, app-icon assets, and `PrivacyInfo.xcprivacy`.

The macOS archive contains arm64 and x86_64 executables, a macOS 15 minimum
deployment, hardened runtime, App Sandbox with outbound network access only,
app-icon assets, and `PrivacyInfo.xcprivacy`. It remains a local archive until
the Mac App Store export and upload path is completed.

For later builds, Xcode Organizer can manage distribution certificates,
profiles, validation, and upload diagnostics:

1. Select the WootDesk scheme and a generic iOS device destination.
2. Choose Product, then Archive.
3. Validate the iOS archive and resolve every error.
4. Select My Mac as the destination and archive again.
5. Validate the macOS archive and inspect its entitlements.
6. Confirm each archive contains the expected icon and `PrivacyInfo.xcprivacy`.

Useful local inspection for the exported macOS app:

```bash
codesign -dvvv --entitlements :- /path/to/WootDesk.app
spctl -a -vv /path/to/WootDesk.app
```

The expected App Store archive uses Apple distribution signing, not the ad-hoc
signature used by `script/build_and_run.sh`.

## Upload and TestFlight

iOS build 2 has been uploaded and processing completed. App Store Connect marks
it Ready to Submit. Build 1 remains visible as superseded with Missing
Compliance. The build 2 package contains
`ITSAppUsesNonExemptEncryption = false`, so no separate Missing Compliance state
is shown for it.

No TestFlight group or tester has been added. The macOS build has not been
exported or uploaded. For each future archive, choose Distribute App, App Store
Connect, and Upload, then wait for processing to complete before assigning the
build.

Release through TestFlight first:

1. Add internal testers with the minimum App Store Connect access needed.
2. Test connection creation, account selection, restore, conversation loading,
   profile switching, revalidation, and deletion on physical devices.
3. Test an Intel or Apple silicon Mac where available.
4. Add external testers only after the beta information and any required Beta
   App Review are complete.
5. Record defects and repeat with a higher build number.

References:

- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Submit for App Review

When `docs/RELEASE_READINESS.md` records an approved Go decision:

1. Select the processed build for each platform version.
2. Resolve any Missing Compliance state.
3. Verify all metadata and screenshots against that build.
4. Add the dedicated demo access privately.
5. Add each platform version to the review submission.
6. Submit for review.
7. Monitor App Store Connect and respond without exposing secrets publicly.

References:

- [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)

## Mac App Store and notarisation

WootDesk's Mac App Store build must remain sandboxed. Apple states that Mac App
Store submission does not require separate notarisation because App Store review
performs equivalent security checks.

Hardened Runtime and notarisation become a separate release path only if N85 Dev
later distributes a Developer ID-signed app outside the Mac App Store.

References:

- [App Sandbox information](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information/)
- [Notarising macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Remaining account-owner actions

The following release actions remain pending and require an authorised account
owner:

- Confirm current legal agreements, roles, and EU trader status.
- Approve price, territories, age rating, and App Store privacy answers.
- Approve platform metadata and screenshots containing invented data only.
- Create or approve the Mac Installer Distribution signing asset if required by
  the macOS App Store export.
- Provide private review contact and dedicated demo credentials.
- Approve TestFlight tester access.
- Submit either platform for App Review.

No public submission should occur until the release gate is complete against an
approved release commit.

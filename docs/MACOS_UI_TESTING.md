# macOS UI Test Host Preparation

Status: Host configured, macOS UI suite passing

Last reviewed: 31 August 2026

## Diagnosed failure

Before the one-time host configuration, the WootDesk macOS UI test target built
but this Mac reported:

```text
Automation Mode is disabled.
This device requires user authentication to enable Automation Mode.
```

The system test log then recorded that the Automation Mode writer required
authentication. Xcode waits for that authorisation for 60 seconds and reports
`Timed out while enabling automation mode` before any WootDesk test method
starts. The iOS Simulator UI suite is unaffected and passes.

This is an operating-system security gate, not a WootDesk assertion, app launch,
signing, or accessibility failure.

## One-time setup for a dedicated development or CI Mac

Apple provides `automationmodetool` specifically for machines used for UI test
automation. On a dedicated development or CI Mac, an administrator may run:

```bash
sudo automationmodetool enable-automationmode-without-authentication
```

This changes a local macOS security preference so entitled XCTest processes can
enable Automation Mode without a password prompt. Review the security impact
before enabling it, especially on a shared Mac. Do not put an administrator
password in a script, shell history, CI variable, or repository file.

Verify the result without exposing any credentials:

```bash
automationmodetool
./script/ci.sh --with-ui-tests
```

The WootDesk CI script now checks this state first and fails immediately with a
clear instruction instead of waiting for the 60-second XCTest timeout.

On 31 August 2026 this controlled Mac was configured with the documented
administrator command. `automationmodetool` now reports that user
authentication is not required. Automation Mode remains disabled while idle
and XCTest enables it only for an authorised test session. The full command
`./script/ci.sh --with-ui-tests` then passed all three macOS UI tests, including
the invented-data conversation history and reply journey.

## Reverting the setting

An administrator can restore authentication-required behaviour with:

```bash
sudo automationmodetool disable-automationmode-without-authentication
```

After reverting, macOS UI test runs may require interactive authorisation again.

## Security boundary

- Enable no-authentication Automation Mode only on a controlled development or
  CI machine.
- Keep the login session locked down and do not expose the runner to untrusted
  build inputs.
- Continue running the iOS Simulator UI suite in normal CI.
- Do not modify the TCC database, disable System Integrity Protection, or grant
  broad Accessibility access as a workaround.
- Re-run `automationmodetool` and the UI suite after macOS or Xcode upgrades.

## Physical iOS device preparation

The same class of one-time setup applies to a real iPhone or iPad, and the
project could not build for one at all until 2 September 2026.

### Project settings, fixed in `project.yml`

Two settings blocked every device run, and neither surfaces until you try:

| Setting | Problem |
|---|---|
| `TEST_HOST` | Defined for `macosx*` and `iphonesimulator*` only. A device build fell back to the macOS path and failed with `Could not find test host` |
| `CODE_SIGN_IDENTITY` | Empty, with signing disabled. Correct for macOS and the simulator, where CI runs unsigned on purpose, but a device rejects an unsigned test bundle |

Both are now scoped to `sdk=iphoneos*` so the unsigned macOS and simulator
paths CI depends on are unchanged.

### Device settings, one time per handset

1. **Developer Mode.** Settings, Privacy and Security, Developer Mode. The
   device restarts.
2. **Enable UI Automation.** Settings, Developer, Enable UI Automation. Without
   it the runner fails with

   ```text
   The test runner failed to initialize for UI testing.
   (Underlying Error: Timed out while enabling automation mode.)
   ```

   Developer Mode alone is not sufficient, and the error does not name the
   setting it needs.
3. **Auto-Lock set to Never.** Settings, Display and Brightness, Auto-Lock. The
   suite launches the app several times and every launch requires the device to
   be unlocked at that instant, so a 30 second auto-lock defeats the run part
   way through with

   ```text
   Xcode cannot launch WootDesk on G75 because the device is locked.
   ```

   This cost three separate attempts before the cause was identified. Restore
   the previous value afterwards.

### Running it

```bash
xcodebuild test -project WootDesk.xcodeproj -scheme WootDesk \
  -destination 'platform=iOS,id=<UDID>' \
  -only-testing:WootDeskUITests -configuration Debug \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=<TEAM_ID>
```

`xcrun devicectl list devices` gives the UDID and should report the handset as
`connected`. A device shown as `unavailable` with `transport: None` is paired
but not attached, and the run fails with an unhelpful
`Unable to find a destination matching the provided destination specifier`.

### A note on certificates

`-allowProvisioningUpdates` creates a development certificate when the machine
has none. That is fine on a developer Mac, which already has one and reuses it,
and destructive on an ephemeral CI runner, which creates a fresh one every
build until the account hits Apple's cap. See `docs/TESTFLIGHT_DELIVERY.md`.

This applies to test and device builds, which is where it is still worth
watching. The release archive no longer behaves this way: it signs manually
against an explicit distribution profile, so it never provisions for
development.

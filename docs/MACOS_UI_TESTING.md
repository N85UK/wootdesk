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

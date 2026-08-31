# WootDesk TestFlight Acceptance Plan

Document ID: `WOOT-TF-001`

Status: Ready for build 3 tester execution, no tester assignment approved

Last reviewed: 30 August 2026

## Purpose

This plan records physical-device and Mac acceptance for WootDesk 1.0.0 (3).
It does not authorise a build upload, tester invitation, App Review submission,
or use of production Chatwoot data.

Use only the dedicated HTTPS Chatwoot environment described in
`docs/CHATWOOT_COMPATIBILITY.md`. Every person, message, note, attachment, inbox,
and account must be invented. Never paste a token into a test record, screenshot,
issue, or repository file.

## Entry criteria

- The tested build number is visible in TestFlight and matches the reviewed source.
- The build is assigned only to approved internal testers.
- Export compliance has no unresolved state.
- The dedicated invented-data server passes the opt-in compatibility checks.
- The tester has the server address and token through an approved private channel.
- No production integrations, webhooks, email, social channels, or customer data
  are connected to the review server.

## Required physical-device matrix

| Platform | Minimum coverage | Required result | Status |
|---|---|---|---|
| iPhone | One physical iPhone on iOS 18 or later | All shared and iPhone cases pass | Not started |
| iPad | One physical iPad on iPadOS 18 or later | All shared and iPad cases pass | Not started |
| Mac, Apple silicon | One Mac on macOS 15 or later | All shared and Mac cases pass | Local source build passes, TestFlight not started |
| Mac, Intel | One Intel Mac on macOS 15 or later, if supported hardware is available | All shared and Mac cases pass | Not started |

A universal arm64 and x86_64 archive proves both slices compile. It does not
replace runtime testing on Intel hardware.

## Shared acceptance cases

Record Pass, Fail, or Blocked for every case:

1. Install the fresh TestFlight build and launch without an existing profile.
2. Add the invented-data Chatwoot server and validate its personal access token.
3. Select an account when the profile exposes several invented accounts.
4. Quit and relaunch, then confirm the active profile and conversation list restore.
5. Load a conversation and page backwards through older message history.
6. Confirm processed HTML is readable and inline Markdown does not activate a link.
7. Send a public reply and verify it appears once after the server confirms it.
8. Send a private note and verify its private presentation is unmistakable.
9. Select an invented file attachment, send it, and verify returned metadata.
10. Cancel the file picker and confirm no error is shown.
11. Trigger a recoverable send failure, then confirm draft text and selected files remain.
12. Confirm received remote attachments do not download automatically.
13. Choose Open for an attachment, review the destination-host warning, then cancel.
14. Switch server profiles and confirm prior conversations and messages disappear immediately.
15. Revalidate a profile, delete it, and confirm its credential no longer restores.
16. Exercise loading, empty, authentication, offline, rate-limit, and malformed-response states.
17. Check light and dark appearance, increased text sizes, VoiceOver labels, and reduced motion.

## iPhone and iPad cases

- Pull to refresh the conversation list and message timeline.
- Use compact and regular size classes on iPad, including split view where available.
- Rotate between portrait and landscape without losing the draft.
- Attach a file from Files and cancel the picker once.
- Move the app to the background and foreground without showing another server's data.
- Confirm the composer remains usable above the software keyboard.

## Mac cases

- Use Command and Return to send, Command and R to refresh, and Command, Shift,
  and N to add a server.
- Resize and restore the main window, then check all three split-view columns.
- Use keyboard focus to reach the profile list, conversation list, composer, and attachment button.
- Confirm the Settings scene opens independently.
- Quit and relaunch, then confirm the Keychain-backed profile restores.

## Evidence record

Do not attach screenshots containing a token, server address, personal data, or
message copied from a real system. Record only invented-data screenshots and
non-secret derived facts.

| Tester | Platform and device | OS | Build | Result | Defect links | Date |
|---|---|---|---|---|---|---|
| To confirm | Physical iPhone | | 1.0.0 (3) | Pending | | |
| To confirm | Physical iPad | | 1.0.0 (3) | Pending | | |
| To confirm | Apple silicon Mac | | 1.0.0 (3) | Pending | | |
| To confirm | Intel Mac | | 1.0.0 (3) | Pending | | |

## Exit criteria

- Every required device row has a named result.
- No critical or high-severity defect remains open.
- Cross-server data isolation, Keychain deletion, and send-failure recovery pass.
- The release owner confirms that the tested build is the build selected for review.
- Product, technical, security, and release owners record separate explicit
  decisions in `docs/RELEASE_READINESS.md`.

Passing this plan is evidence for a release decision. It is not itself permission
to upload a build or submit it to App Review.

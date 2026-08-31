# Security Policy

Security and user privacy are foundational to WootDesk. We welcome responsible security reports and vulnerability disclosures.

---

## Supported Versions

WootDesk has not published a production release. Security fixes currently target
the latest commit on the default branch. This policy will gain a version support
table when the project starts publishing releases.

---

## Security Architecture & Design Rules

1. **Credential Storage:**
   Personal access tokens are stored in Apple Keychain as generic password items, keyed by the server profile's UUID. iOS and release builds use the `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` protection class. An ad-hoc macOS Debug build without an authorised application identifier uses the default local Keychain because Apple does not permit that signature to access the data-protection Keychain.

   The device-only class was chosen for distributed builds because it keeps the token on one device: it is excluded from iCloud Keychain synchronisation and from encrypted backups restored to a different device. The token becomes available after the device has been unlocked once following a restart. WootDesk never marks a Keychain item as synchronisable, including in the macOS Debug compatibility path.

   Tokens are never placed in `UserDefaults`, a property list, an environment file, source code, or the saved server-profile JSON. Deleting a server profile deletes its Keychain item.

2. **Network Security:**
   - HTTPS is enforced in release builds. A plain `http://` address is rejected before any request is made.
   - Plain HTTP is permitted only for `localhost`, `127.0.0.1`, and `::1`, and only in debug builds.
   - The debug property list permits local networking only. The release property list has no App Transport Security exception, and neither configuration disables certificate validation.
   - System certificate trust evaluation is used unmodified. There is no `URLSessionDelegate` that overrides trust evaluation, so a self-hosted server needs a certificate the system already trusts, which may be one the user has installed and trusted themselves.

3. **macOS App Sandbox:**
   The project entitlement file requests `com.apple.security.app-sandbox`,
   `com.apple.security.network.client`, and
   `com.apple.security.files.user-selected.read-only`. The file entitlement
   permits only read access to files a user deliberately chooses through the
   system picker. WootDesk requests no broad file, camera, microphone, location,
   or inbound network access. Xcode adds its standard
   `com.apple.security.get-task-allow` entitlement to a locally signed Debug
   build so the debugger can attach; WootDesk does not request that entitlement
   in its source file.

4. **Logging:**
   Logs are written with `OSLog`. Request headers, access tokens, and message bodies are never logged. Error descriptions shown to the user never embed the token.

5. **Privacy by Design:**
   - WootDesk contains no analytics SDKs or remote telemetry.
   - AI features require an authenticated, user-controlled gateway. Internal notes, contact emails, and phone numbers are excluded from AI contexts by default.
   - The current user-facing data-processing disclosure is maintained in [PRIVACY.md](PRIVACY.md), and the release privacy manifest must be reviewed against every distribution binary.

6. **Attachment Safety:**
   Selected files are copied into bounded in-memory values, with a maximum of 15
   files and 25 MB per message. Upload filenames and MIME types are sanitised.
   Received attachment URLs must use HTTPS outside a debug-only localhost path.
   Remote content is never fetched automatically, and the user confirms the
   destination host before WootDesk opens it without the Chatwoot token.

7. **Push Notification Boundary:**
   Notification permission is requested only after a user action. APNs device
   tokens remain in app process memory and are never logged or persisted by the
   Apple client. WootDesk does not submit an APNs token to Chatwoot's
   incompatible FCM endpoint. After deliberate configuration, the token and
   opaque profile routing identifiers are sent to the selected authenticated
   WootDesk Push Gateway. Its address, device API token, and stable device ID
   are stored in a separate device-only Apple Keychain item.

   The gateway source under `Gateway/` requires authenticated mutations and a
   high-entropy webhook route secret, encrypts APNs tokens at rest, filters for
   public incoming messages, deduplicates delivery, and sends generic alerts.
   Chatwoot personal access tokens are never accepted. Timestamped webhook HMAC
   verification is optional because current account-webhook signature behaviour
   varies. A deployment must still protect the secret route in proxy logs,
   store Apple keys in an approved secret manager, define deletion and incident
   procedures, and pass physical-device acceptance. The first account-wide
   recipient policy must not be deployed where per-agent authorisation is
   required.

---

## Reporting a Vulnerability

If you discover a security vulnerability in WootDesk, please report it privately using GitHub's **Report a vulnerability** button under the repository's Security tab, which opens a private security advisory visible only to the maintainers.

Please include the affected version or commit, reproduction steps, and the impact you observed. Please do not open a public issue and do not disclose the issue publicly until a fix has been released.

Never include a real access token, server address, or customer data in a report. A redacted description is enough.

# ADR 0002: Apple Keychain & Local Profile Storage Separation

## Context
WootDesk needs to persist connection configurations (server URL, display name, selected account) and sensitive authentication tokens (Chatwoot personal access tokens). Storing tokens in plain text (UserDefaults, plists, or JSON files) creates severe security risks.

## Decision
We separated storage into two distinct layers:
1. **Credentials (Secrets):** Persisted exclusively in **Apple Keychain** via `KeychainCredentialStore`. iOS and release builds use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. An ad-hoc macOS Debug build without an authorised application identifier uses the default local Keychain.
2. **Profile Metadata (Non-Secret):** Persisted as an atomically written JSON file in `Application Support/WootDesk/` via `FileServerProfileRepository`.

## Consequences & Rationale
- **Protection at Rest:** Tokens are held by Keychain Services rather than in application storage, so they are never written to a plain-text file, property list, or `UserDefaults`. This is Keychain protection, not Secure Enclave protection. WootDesk makes no Secure Enclave or biometric claim.
- **Device-Only Isolation:** Distributed iOS and release builds use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which keeps the token on one device. It is excluded from iCloud Keychain synchronisation and from backups restored onto a different device, while remaining readable after a reboot once the device has been unlocked. WootDesk never marks items as synchronisable. A clean-clone macOS Debug build may be ad-hoc signed and therefore lacks the authorised application identifier required by the data-protection Keychain. That development-only case uses the default local macOS Keychain instead of failing to save the connection.
- **Safe Profile Deletion:** Removing a server profile automatically and irreversibly deletes the corresponding Keychain entry.
- **Resilience:** The JSON profile repository handles missing files and recovers gracefully from file corruption by creating a uniquely named recovery copy without crashing.

import Foundation
import SwiftUI
import os

/// Root application model managing active profiles, credentials, and top-level navigation.
@Observable
@MainActor
public final class AppModel {
    public var profiles: [ServerProfile] = []
    public var activeProfile: ServerProfile?
    public var activeToken: String?
    public var isInitializing: Bool = true
    public var showAddConnectionSheet: Bool = false
    public var isSwitchingProfile: Bool = false
    public var selectedNavigationItem: NavigationItem? = .conversations(status: .open)
    public var lastError: String?

    public enum NavigationItem: Hashable, Sendable {
        case conversations(status: ConversationStatus?)
        case settings
        case connections
    }

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Initialises state on application launch, restoring saved profiles and credentials.
    public func initialize() async {
        isInitializing = true
        defer { isInitializing = false }

        do {
            profiles = try await environment.profileRepository.loadProfiles()
            activeProfile = nil
            activeToken = nil
            lastError = nil
            let savedActiveID = try await environment.profileRepository.loadActiveProfileID()

            if let savedActiveID, let matched = profiles.first(where: { $0.id == savedActiveID }) {
                await selectProfile(matched)
            } else if let first = profiles.first {
                await selectProfile(first)
            } else {
                activeProfile = nil
                activeToken = nil
            }
        } catch {
            AppLogger.app.error("WootDesk could not restore its saved profile state.")
            lastError = Self.userMessage(for: error)
        }
    }

    /// Switches the active profile, restoring its Keychain token and saving the selection.
    public func selectProfile(_ profile: ServerProfile) async {
        guard !isSwitchingProfile else { return }
        isSwitchingProfile = true
        defer { isSwitchingProfile = false }

        do {
            let allowedBaseURL = try APIRequest.normaliseBaseURL(
                profile.baseURL.absoluteString,
                isDebug: environment.isDebug
            )
            let token = try environment.credentialStore.loadToken(for: profile.id)
            guard let token, !token.isEmpty else {
                AppLogger.auth.error("A saved server profile has no corresponding Keychain credential.")
                lastError = "The saved credential for \"\(profile.displayName)\" could not be found in the Keychain. Remove the profile and add it again."
                return
            }

            let previousProfiles = profiles
            let previousActiveID = try await environment.profileRepository.loadActiveProfileID()
            var updatedProfile = profile
            updatedProfile.baseURL = allowedBaseURL
            updatedProfile.lastUsedAt = Date()
            var updatedProfiles = profiles
            if let index = updatedProfiles.firstIndex(where: { $0.id == profile.id }) {
                updatedProfiles[index] = updatedProfile
            }

            try await persistProfileState(
                profiles: updatedProfiles,
                activeID: updatedProfile.id,
                rollbackProfiles: previousProfiles,
                rollbackActiveID: previousActiveID
            )

            profiles = updatedProfiles
            activeProfile = updatedProfile
            activeToken = token
            lastError = nil
        } catch {
            AppLogger.auth.error("Failed to select a server profile.")
            lastError = Self.userMessage(for: error)
        }
    }

    /// Saves a newly validated connection profile and securely stores its access token in Keychain.
    public func addConnection(
        displayName: String,
        baseURL: URL,
        token: String,
        account: ChatwootAccount
    ) async throws {
        let allowedBaseURL = try APIRequest.normaliseBaseURL(
            baseURL.absoluteString,
            isDebug: environment.isDebug
        )
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw AppModelError.invalidCredential
        }
        let normalisedDisplayName = Self.displayName(
            from: displayName,
            baseURL: allowedBaseURL,
            fallback: account.name
        )
        let profile = ServerProfile(
            id: UUID(),
            displayName: normalisedDisplayName,
            baseURL: allowedBaseURL,
            selectedAccountID: account.id,
            selectedAccountName: account.name,
            createdAt: Date(),
            lastUsedAt: Date()
        )

        let previousProfiles = profiles
        let previousActiveID = try await environment.profileRepository.loadActiveProfileID()

        try environment.credentialStore.saveToken(trimmedToken, for: profile.id)

        var newProfiles = profiles
        newProfiles.append(profile)
        do {
            try await persistProfileState(
                profiles: newProfiles,
                activeID: profile.id,
                rollbackProfiles: previousProfiles,
                rollbackActiveID: previousActiveID
            )
        } catch {
            do {
                try environment.credentialStore.deleteToken(for: profile.id)
            } catch {
                AppLogger.auth.error("A newly stored credential could not be removed after profile persistence failed.")
                throw AppModelError.recoveryRequired
            }
            throw error
        }

        profiles = newProfiles
        activeProfile = profile
        activeToken = trimmedToken
        lastError = nil
        showAddConnectionSheet = false
    }

    /// Updates an existing profile only after its server, token, and account have
    /// been revalidated by the connection editor.
    public func updateConnection(
        profileID: UUID,
        displayName: String,
        baseURL: URL,
        token: String,
        account: ChatwootAccount
    ) async throws {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw AppModelError.profileNotFound
        }
        guard let previousToken = try environment.credentialStore.loadToken(for: profileID),
              !previousToken.isEmpty else {
            throw AppModelError.credentialMissing
        }
        let allowedBaseURL = try APIRequest.normaliseBaseURL(
            baseURL.absoluteString,
            isDebug: environment.isDebug
        )
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw AppModelError.invalidCredential
        }

        var updatedProfile = profiles[index]
        updatedProfile.displayName = Self.displayName(from: displayName, baseURL: allowedBaseURL, fallback: account.name)
        updatedProfile.baseURL = allowedBaseURL
        updatedProfile.selectedAccountID = account.id
        updatedProfile.selectedAccountName = account.name
        updatedProfile.lastUsedAt = Date()

        var updatedProfiles = profiles
        updatedProfiles[index] = updatedProfile

        try environment.credentialStore.saveToken(trimmedToken, for: profileID)
        do {
            try await environment.profileRepository.saveProfiles(updatedProfiles)
        } catch {
            AppLogger.persistence.error("Failed to save an updated server profile.")
            do {
                try environment.credentialStore.saveToken(previousToken, for: profileID)
            } catch {
                AppLogger.auth.error("The previous credential could not be restored after an update failed.")
                throw AppModelError.recoveryRequired
            }
            throw AppModelError.persistenceFailed
        }

        profiles = updatedProfiles
        if activeProfile?.id == profileID {
            activeProfile = updatedProfile
            activeToken = trimmedToken
        }
        lastError = nil
    }

    /// Loads a credential into the edit form without exposing it outside the
    /// current process. Returns nil and presents a recoverable error if missing.
    public func credentialForEditing(_ profile: ServerProfile) -> String? {
        do {
            guard let token = try environment.credentialStore.loadToken(for: profile.id),
                  !token.isEmpty else {
                lastError = "The saved credential for \"\(profile.displayName)\" could not be found in the Keychain. Remove the profile and add it again."
                return nil
            }
            return token
        } catch {
            lastError = Self.userMessage(for: error)
            return nil
        }
    }

    /// Safely deletes a server profile and eliminates its Keychain secret.
    public func deleteProfile(id: UUID) async {
        guard profiles.contains(where: { $0.id == id }) else { return }

        do {
            let previousProfiles = profiles
            let previousActiveID = try await environment.profileRepository.loadActiveProfileID()
            var remainingProfiles = profiles.filter { $0.id != id }

            let nextState: (profile: ServerProfile?, token: String?)
            if activeProfile?.id == id {
                var usableProfile: ServerProfile?
                var usableToken: String?
                for index in remainingProfiles.indices {
                    var candidate = remainingProfiles[index]
                    guard let allowedBaseURL = try? APIRequest.normaliseBaseURL(
                        candidate.baseURL.absoluteString,
                        isDebug: environment.isDebug
                    ) else {
                        continue
                    }
                    if let token = try environment.credentialStore.loadToken(for: candidate.id), !token.isEmpty {
                        candidate.baseURL = allowedBaseURL
                        candidate.lastUsedAt = Date()
                        remainingProfiles[index] = candidate
                        usableProfile = candidate
                        usableToken = token
                        break
                    }
                }
                nextState = (usableProfile, usableToken)
            } else {
                nextState = (activeProfile, activeToken)
            }

            try await persistProfileState(
                profiles: remainingProfiles,
                activeID: nextState.profile?.id,
                rollbackProfiles: previousProfiles,
                rollbackActiveID: previousActiveID
            )

            do {
                try environment.credentialStore.deleteToken(for: id)
            } catch {
                AppLogger.auth.error("The credential could not be deleted, so the profile removal is being rolled back.")
                do {
                    try await environment.profileRepository.saveProfiles(previousProfiles)
                    try await environment.profileRepository.saveActiveProfileID(previousActiveID)
                } catch {
                    AppLogger.persistence.error("Profile metadata could not be restored after credential deletion failed.")
                    lastError = AppModelError.recoveryRequired.errorDescription
                    return
                }
                lastError = Self.userMessage(for: error)
                return
            }

            profiles = remainingProfiles
            activeProfile = nextState.profile
            activeToken = nextState.token
            lastError = nil
        } catch {
            AppLogger.persistence.error("Failed to remove a saved server profile.")
            lastError = Self.userMessage(for: error)
        }
    }

    /// Seeds already-restored state directly, without touching the repository or
    /// credential store.
    ///
    /// Intended for SwiftUI previews and tests, which cannot await `initialize()`.
    /// The live app always restores state through `initialize()` instead.
    public func applyPreviewState(
        profiles: [ServerProfile],
        activeProfile: ServerProfile?,
        token: String?
    ) {
        self.profiles = profiles
        self.activeProfile = activeProfile
        self.activeToken = token
        self.isInitializing = false
    }

    private func persistProfileState(
        profiles updatedProfiles: [ServerProfile],
        activeID updatedActiveID: UUID?,
        rollbackProfiles: [ServerProfile],
        rollbackActiveID: UUID?
    ) async throws {
        do {
            try await environment.profileRepository.saveProfiles(updatedProfiles)
            try await environment.profileRepository.saveActiveProfileID(updatedActiveID)
        } catch {
            AppLogger.persistence.error("A profile metadata transaction failed. Restoring the previous state.")
            do {
                try await environment.profileRepository.saveProfiles(rollbackProfiles)
                try await environment.profileRepository.saveActiveProfileID(rollbackActiveID)
            } catch {
                AppLogger.persistence.error("The previous profile metadata state could not be restored.")
                throw AppModelError.recoveryRequired
            }
            throw AppModelError.persistenceFailed
        }
    }

    private static func displayName(from rawName: String, baseURL: URL, fallback: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return baseURL.host ?? fallback
    }

    private static func userMessage(for error: Error) -> String {
        if let localised = error as? LocalizedError, let description = localised.errorDescription {
            return description
        }
        return "WootDesk could not complete the profile operation. Please try again."
    }
}

public enum AppModelError: LocalizedError, Sendable, Equatable {
    case profileNotFound
    case credentialMissing
    case invalidCredential
    case persistenceFailed
    case recoveryRequired

    public var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "The saved server profile could not be found."
        case .credentialMissing:
            return "The saved Chatwoot credential could not be found in Apple Keychain."
        case .invalidCredential:
            return "Please enter a valid Chatwoot personal access token."
        case .persistenceFailed:
            return "WootDesk could not save the server profile. The previous saved state was restored."
        case .recoveryRequired:
            return "WootDesk could not restore the previous saved state. Keep the app open and review the local profile and Keychain data before trying again."
        }
    }
}

import Foundation

/// Protocol abstraction separating WootDesk from any direct OpenAI SDK or model dependencies.
///
/// All live AI capabilities are intended to communicate with an authenticated server-side
/// WootDesk AI Gateway rather than calling OpenAI API directly from client apps.
public protocol AIProvider: Sendable {
    /// Submits a deep research request to the gateway.
    func startResearch(request: ResearchRequest) async throws -> ResearchJob

    /// Fetches the latest status and results of a research job.
    func fetchJobStatus(jobID: String) async throws -> ResearchJob

    /// Cancels an in-flight research job.
    func cancelJob(jobID: String) async throws

    /// Generates a summary for the given conversation.
    func summariseConversation(request: AISummaryRequest) async throws -> String

    /// Drafts a proposed reply for a customer message.
    func draftReply(request: AIDraftReplyRequest) async throws -> String
}

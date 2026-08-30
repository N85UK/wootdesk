import Foundation

/// Mock provider for testing and SwiftUI previews.
public actor MockAIProvider: AIProvider {
    private var jobs: [String: ResearchJob] = [:]

    public init() {}

    public func startResearch(request: ResearchRequest) async throws -> ResearchJob {
        let jobID = "job_\(UUID().uuidString.prefix(8))"
        let job = ResearchJob(
            id: jobID,
            request: request,
            status: .running,
            startedAt: Date()
        )
        jobs[jobID] = job
        return job
    }

    public func fetchJobStatus(jobID: String) async throws -> ResearchJob {
        if let existing = jobs[jobID] {
            // Transition running -> completed in mock
            let result = ResearchResult(
                reportMarkdown: "### Research Summary\n\nBased on your brief: *\(existing.request.researchBrief)*.\n\nKey finding: Self-hosted Chatwoot instances should configure proper WebSocket Redis adapters for reliable pubsub notifications.",
                citations: [
                    ResearchCitation(
                        id: "cite-1",
                        title: "Chatwoot ActionCable Architecture",
                        url: URL(string: "https://developers.chatwoot.com"),
                        snippet: "Chatwoot uses ActionCable with Redis for real-time dispatch.",
                        dataSource: "Chatwoot Documentation"
                    )
                ]
            )
            let completedJob = ResearchJob(
                id: jobID,
                request: existing.request,
                status: .completed,
                result: result,
                startedAt: existing.startedAt,
                updatedAt: Date()
            )
            jobs[jobID] = completedJob
            return completedJob
        }

        throw APIError.notFound
    }

    public func cancelJob(jobID: String) async throws {
        if let existing = jobs[jobID] {
            jobs[jobID] = ResearchJob(
                id: jobID,
                request: existing.request,
                status: .cancelled,
                startedAt: existing.startedAt,
                updatedAt: Date()
            )
        }
    }

    public func summariseConversation(request: AISummaryRequest) async throws -> String {
        return "Customer asked about server setup. Agent resolved query with documentation link."
    }

    public func draftReply(request: AIDraftReplyRequest) async throws -> String {
        return "Hello, thank you for contacting support. We have checked your account configuration and everything looks in order."
    }
}

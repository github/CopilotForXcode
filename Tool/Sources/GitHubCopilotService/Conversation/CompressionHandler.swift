import Combine
import Foundation

public protocol CompressionHandler {
    var onCompressionStarted: PassthroughSubject<String, Never> { get }  // conversationId
    var onCompressionCompleted: PassthroughSubject<GitHubCopilotNotification.CompressionCompletedNotification, Never> { get }
}

public final class CompressionHandlerImpl: CompressionHandler {
    public static let shared = CompressionHandlerImpl()

    public var onCompressionStarted = PassthroughSubject<String, Never>()
    public var onCompressionCompleted = PassthroughSubject<GitHubCopilotNotification.CompressionCompletedNotification, Never>()
}

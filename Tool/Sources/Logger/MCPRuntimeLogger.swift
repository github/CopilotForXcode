import Foundation
import System

public final class MCPRuntimeFileLogger {
    private lazy var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let implementation = MCPRuntimeFileLoggerImplementation()

    /// Converts a timestamp in milliseconds since the Unix epoch to a formatted date string.
    private func timestamp(timeStamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timeStamp/1000)
        return dateFormatter.string(from: date)
    }
    
    public func log(
        logFileName: String,
        level: String,
        message: String,
        server: String,
        tool: String? = nil,
        time: Double
    ) {
        guard time.isFinite, time >= 0 else {
            return
        }
        
        let toolSuffix = tool.map { "-\($0)" } ?? ""
        let timestampStr = timestamp(timeStamp: time)
        let log = "[\(timestampStr)] [\(level)] [\(server)\(toolSuffix)] \(message)\(message.hasSuffix("\n") ? "" : "\n")"
        
        Task { [implementation] in
            await implementation.logToFile(logFileName: logFileName, log: log)
        }
    }
}

actor MCPRuntimeFileLoggerImplementation {
    private let logDir: FilePath
    private var workspaceLoggers: [String: BaseFileLoggerImplementation] = [:]
    
    public init() {
        logDir = FileLoggingLocation.mcpRuntimeLogsPath
    }
    
    public func logToFile(logFileName: String, log: String) async {
        if workspaceLoggers[logFileName] == nil {
            workspaceLoggers[logFileName] = BaseFileLoggerImplementation(
                logDir: logDir,
                logFileName: logFileName
            )
        }
        
        if let logger = workspaceLoggers[logFileName] {
            await logger.logToFile(log)
        }
    }
}

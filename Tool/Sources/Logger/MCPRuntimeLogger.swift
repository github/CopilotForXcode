import Foundation
import System

public final class MCPRuntimeFileLogger {
    private let timestampFormat = Date.ISO8601FormatStyle.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted).time(includingFractionalSeconds: true)
    private let implementation = MCPRuntimeFileLoggerImplementation()
    
    /// Converts a timestamp in milliseconds since the Unix epoch to a formatted date string.
    private func timestamp(timeStamp: Double) -> String {
        return Date(timeIntervalSince1970: timeStamp/1000).formatted(timestampFormat)
    }
    
    public func log(
        logFileName: String,
        level: String,
        message: String,
        server: String,
        tool: String? = nil,
        time: Double
    ) {
        let toolSuffix = tool.map { "-\($0)" } ?? ""
        let log = "[\(timestamp(timeStamp: time))] [\(level)] [\(server)\(toolSuffix)] \(message)\(message.hasSuffix("\n") ? "" : "\n")"
        
        Task {
            await self.implementation.logToFile(logFileName: logFileName, log: log)
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

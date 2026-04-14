import Foundation

enum ProcessExecutorError: LocalizedError {
    case failedToLaunch(String)

    var errorDescription: String? {
        switch self {
        case let .failedToLaunch(message):
            return message
        }
    }
}

final class ProcessBox: @unchecked Sendable {
    let process: Process

    init(process: Process) {
        self.process = process
    }
}

enum ProcessExecutor {
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        outputHandler: @escaping @Sendable (String) -> Void,
        onStart: (@Sendable (ProcessBox) -> Void)? = nil
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                guard let chunk = String(data: data, encoding: .utf8) else { return }
                outputHandler(chunk)
            }

            process.terminationHandler = { terminatedProcess in
                handle.readabilityHandler = nil

                let remainder = handle.readDataToEndOfFile()
                if !remainder.isEmpty, let chunk = String(data: remainder, encoding: .utf8) {
                    outputHandler(chunk)
                }

                continuation.resume(returning: terminatedProcess.terminationStatus)
            }

            do {
                try process.run()
                onStart?(ProcessBox(process: process))
            } catch {
                handle.readabilityHandler = nil
                continuation.resume(throwing: ProcessExecutorError.failedToLaunch(error.localizedDescription))
            }
        }
    }
}

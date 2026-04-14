import Foundation

struct ToolLocator {
    private static let preferredPaths: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/opt/homebrew/opt/yt-dlp/bin",
        "/opt/homebrew/opt/ffmpeg/bin"
    ]

    static func find(tool name: String) -> String? {
        let fileManager = FileManager.default
        for directory in pathEntries() {
            let candidate = NSString.path(withComponents: [directory, name])
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    static func makeEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let merged = pathEntries().joined(separator: ":")
        environment["PATH"] = merged
        return environment
    }

    private static func pathEntries() -> [String] {
        let existing = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        var all: [String] = []

        for path in preferredPaths + existing {
            if !all.contains(path) {
                all.append(path)
            }
        }

        return all
    }
}

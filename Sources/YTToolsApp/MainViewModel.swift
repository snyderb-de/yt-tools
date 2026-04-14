import AppKit
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var themeMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: Self.themePreferenceKey)
        }
    }

    @Published var inputMode: InputMode = .singleURL
    @Published var videoURL: String = ""
    @Published var urlListFilePath: String = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/raelynn-list.text", isDirectory: false).path

    @Published var mode: DownloadMode = .audioConvert
    @Published var audioFormat: AudioFormat = .mp3
    @Published var videoFormat: VideoFormat = .mp4
    @Published var outputDirectory: String = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/YTTools", isDirectory: true).path
    @Published var outputTemplate: String = "%(title)s.%(ext)s"

    @Published var authMethod: AuthMethod = .none
    @Published var browserSource: BrowserCookieSource = .safari
    @Published var cookieFilePath: String = ""

    @Published var ytDlpPath: String = ""
    @Published var ffmpegPath: String = ""
    @Published var nodePath: String = ""
    @Published var downloadSpeedSamples: [Double] = []
    @Published var currentDownloadSpeedMbps: Double = 0
    @Published var status: String = "Idle"
    @Published var logText: String = "Ready. Detecting tools...\n"
    @Published var lastCommand: String = ""
    @Published var isRunning: Bool = false

    private var activeProcess: Process?
    private var isCancellationRequested: Bool = false
    private static let themePreferenceKey = "yttools.themeMode"
    private static let speedRegex = try! NSRegularExpression(
        pattern: #"at\s+([0-9]+(?:\.[0-9]+)?)([KMG]?i?B/s|[KMG]?B/s)"#,
        options: []
    )

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.themePreferenceKey),
           let parsed = ThemeMode(rawValue: stored) {
            themeMode = parsed
        }
        refreshToolPaths()
    }

    var canStart: Bool {
        !isRunning && !ytDlpPath.isEmpty && hasValidInput
    }

    var peakDownloadSpeedMbps: Double {
        downloadSpeedSamples.max() ?? 0
    }

    private var hasValidInput: Bool {
        switch inputMode {
        case .singleURL:
            return !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .urlListFile:
            return !urlListFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func refreshToolPaths() {
        ytDlpPath = ToolLocator.find(tool: "yt-dlp") ?? ""
        ffmpegPath = ToolLocator.find(tool: "ffmpeg") ?? ""
        nodePath = ToolLocator.find(tool: "node") ?? ""

        if ytDlpPath.isEmpty {
            status = "yt-dlp not found"
            appendLog("ERROR: Could not find yt-dlp on PATH.\n")
        } else if ffmpegPath.isEmpty {
            status = "ffmpeg not found"
            appendLog("WARNING: ffmpeg not found. Format conversion may fail.\n")
        } else {
            status = "Ready"
            appendLog("Detected yt-dlp at \(ytDlpPath)\nDetected ffmpeg at \(ffmpegPath)\n")
            if !nodePath.isEmpty {
                appendLog("Detected node at \(nodePath)\n")
            } else {
                appendLog("WARNING: node not found. Some YouTube URLs may fail without --js-runtimes node.\n")
            }
        }
    }

    func runDownload() {
        guard canStart else { return }

        do {
            let urls = try resolveInputURLs()
            let requestTemplate = DownloadRequest(
                url: "",
                mode: mode,
                audioFormat: audioFormat,
                videoFormat: videoFormat,
                outputDirectory: outputDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
                outputTemplate: outputTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
                authMethod: authMethod,
                browserSource: browserSource,
                cookieFilePath: cookieFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            Task {
                await executeBatch(template: requestTemplate, urls: urls)
            }
        } catch {
            status = "Invalid Input"
            appendLog("ERROR: \(error.localizedDescription)\n")
        }
    }

    func cancelDownload() {
        isCancellationRequested = true
        guard let process = activeProcess else {
            appendLog("Cancellation requested.\n")
            return
        }
        process.terminate()
        appendLog("Cancellation requested.\n")
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let selected = panel.url {
            outputDirectory = selected.path
        }
    }

    func chooseCookieFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selected = panel.url {
            cookieFilePath = selected.path
        }
    }

    func chooseURLListFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selected = panel.url {
            urlListFilePath = selected.path
        }
    }

    private func executeBatch(template: DownloadRequest, urls: [String]) async {
        isRunning = true
        status = "Running"
        isCancellationRequested = false
        downloadSpeedSamples = []
        currentDownloadSpeedMbps = 0

        var successCount = 0
        var failureCount = 0

        appendLog("\n---\nStarting batch with \(urls.count) URL(s)\n")

        defer {
            activeProcess = nil
            isRunning = false
        }

        for (index, url) in urls.enumerated() {
            if isCancellationRequested {
                status = "Cancelled"
                appendLog("Batch cancelled. Success: \(successCount), Failed: \(failureCount), Remaining: \(urls.count - successCount - failureCount)\n")
                return
            }

            let request = DownloadRequest(
                url: url,
                mode: template.mode,
                audioFormat: template.audioFormat,
                videoFormat: template.videoFormat,
                outputDirectory: template.outputDirectory,
                outputTemplate: template.outputTemplate,
                authMethod: template.authMethod,
                browserSource: template.browserSource,
                cookieFilePath: template.cookieFilePath
            )

            appendLog("\n[\(index + 1)/\(urls.count)] Processing: \(url)\n")
            let succeeded = await executeSingle(request)
            if succeeded {
                successCount += 1
            } else {
                failureCount += 1
            }
        }

        if failureCount == 0 {
            status = "Success"
            appendLog("Batch completed successfully. Success: \(successCount), Failed: \(failureCount)\n")
        } else {
            status = "Completed with errors"
            appendLog("Batch completed with errors. Success: \(successCount), Failed: \(failureCount)\n")
        }
    }

    private func executeSingle(_ request: DownloadRequest) async -> Bool {
        do {
            try ensureOutputDirectoryExists(request.outputDirectory)
            let arguments = try buildArguments(for: request)
            lastCommand = commandPreview(arguments: arguments)
            appendLog("\(lastCommand)\n")

            let exitCode = try await ProcessExecutor.run(
                executableURL: URL(fileURLWithPath: ytDlpPath),
                arguments: arguments,
                environment: ToolLocator.makeEnvironment(),
                outputHandler: { [weak self] chunk in
                    Task { @MainActor in
                        self?.appendLog(chunk)
                    }
                },
                onStart: { [weak self] processBox in
                    Task { @MainActor in
                        self?.activeProcess = processBox.process
                    }
                }
            )

            activeProcess = nil

            if isCancellationRequested {
                return false
            }

            if exitCode == 0 {
                appendLog("Done.\n")
                return true
            }

            appendLog("ERROR: yt-dlp exited with code \(exitCode).\n")
            return false
        } catch {
            activeProcess = nil
            appendLog("ERROR: \(error.localizedDescription)\n")
            return false
        }
    }

    private func resolveInputURLs() throws -> [String] {
        switch inputMode {
        case .singleURL:
            let url = videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidURL(url) else {
                throw ProcessExecutorError.failedToLaunch("Please provide a valid URL.")
            }
            return [url]
        case .urlListFile:
            let path = urlListFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                throw ProcessExecutorError.failedToLaunch("URL list file path is required.")
            }
            return try loadURLs(from: path)
        }
    }

    private func loadURLs(from path: String) throws -> [String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let urls = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        guard !urls.isEmpty else {
            throw ProcessExecutorError.failedToLaunch("No URLs found in list file.")
        }

        for url in urls where !isValidURL(url) {
            throw ProcessExecutorError.failedToLaunch("Invalid URL in list file: \(url)")
        }

        return urls
    }

    private func buildArguments(for request: DownloadRequest) throws -> [String] {
        var args: [String] = [
            "--newline",
            "--progress",
            "-P", request.outputDirectory,
            "-o", request.outputTemplate,
            "--no-mtime"
        ]

        if !ffmpegPath.isEmpty {
            args += ["--ffmpeg-location", ffmpegPath]
        }
        if !nodePath.isEmpty {
            args += ["--js-runtimes", "node"]
        }

        switch request.authMethod {
        case .none:
            break
        case .cookiesFromBrowser:
            args += ["--cookies-from-browser", request.browserSource.rawValue]
        case .cookiesFile:
            guard !request.cookieFilePath.isEmpty else {
                throw ProcessExecutorError.failedToLaunch("cookies.txt path is required when auth mode is cookies file.")
            }
            args += ["--cookies", request.cookieFilePath]
        }

        switch request.mode {
        case .audioExtract:
            args += ["-f", "bestaudio/best"]
        case .audioConvert:
            args += ["-x", "--audio-format", request.audioFormat.rawValue, "--audio-quality", "0", "-f", "bestaudio/best"]
        case .videoConvert:
            args += ["--recode-video", request.videoFormat.rawValue, "-f", "bv*+ba/b"]
        }

        args.append(request.url)
        return args
    }

    private func commandPreview(arguments: [String]) -> String {
        let escaped = arguments.map(escapeShellArgument(_:)).joined(separator: " ")
        return "\(escapeShellArgument(ytDlpPath)) \(escaped)"
    }

    private func ensureOutputDirectoryExists(_ path: String) throws {
        guard !path.isEmpty else {
            throw ProcessExecutorError.failedToLaunch("Output directory is required.")
        }

        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    private func isValidURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return ["https", "http"].contains(url.scheme?.lowercased() ?? "")
    }

    private func escapeShellArgument(_ arg: String) -> String {
        if arg.rangeOfCharacter(from: .whitespacesAndNewlines) == nil && !arg.contains("\"") {
            return arg
        }

        let escaped = arg.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func appendLog(_ text: String) {
        logText += text
        parseSpeedSamples(in: text)

        if logText.count > 75_000 {
            logText = String(logText.suffix(50_000))
        }
    }

    private func parseSpeedSamples(in text: String) {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = Self.speedRegex.matches(in: text, options: [], range: fullRange)
        for match in matches {
            guard
                let valueRange = Range(match.range(at: 1), in: text),
                let unitRange = Range(match.range(at: 2), in: text)
            else { continue }

            let valueString = String(text[valueRange])
            let unitString = String(text[unitRange]).uppercased()
            guard let value = Double(valueString), let multiplier = speedUnitMultiplier(unitString) else {
                continue
            }

            let bytesPerSecond = value * multiplier
            let mbps = (bytesPerSecond * 8.0) / 1_000_000.0
            appendSpeedSample(mbps)
        }
    }

    private func appendSpeedSample(_ mbps: Double) {
        guard mbps > 0 else { return }

        let smoothed: Double
        if let last = downloadSpeedSamples.last {
            let alpha = 0.28
            smoothed = (alpha * mbps) + ((1 - alpha) * last)
        } else {
            smoothed = mbps
        }

        currentDownloadSpeedMbps = smoothed
        downloadSpeedSamples.append(smoothed)
        if downloadSpeedSamples.count > 180 {
            downloadSpeedSamples = Array(downloadSpeedSamples.suffix(180))
        }
    }

    private func speedUnitMultiplier(_ unit: String) -> Double? {
        switch unit {
        case "B/S":
            return 1
        case "KB/S", "KIB/S":
            return 1024
        case "MB/S", "MIB/S":
            return 1024 * 1024
        case "GB/S", "GIB/S":
            return 1024 * 1024 * 1024
        default:
            return nil
        }
    }
}

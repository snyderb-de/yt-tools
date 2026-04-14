import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            urlSection
            settingsSection
            authSection
            controlsSection
            networkSection
            logsSection
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 680)
        .preferredColorScheme(viewModel.themeMode.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YT Tools")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("MVP downloader + converter for yt-dlp and ffmpeg")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Picker("Appearance", selection: $viewModel.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isRunning)

                statusBadge(title: viewModel.status)
                Text(viewModel.ytDlpPath.isEmpty ? "yt-dlp: missing" : "yt-dlp: found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.ffmpegPath.isEmpty ? "ffmpeg: missing" : "ffmpeg: found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var urlSection: some View {
        GroupBox("Source") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Input mode", selection: $viewModel.inputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isRunning)

                if viewModel.inputMode == .singleURL {
                    HStack {
                        TextField("https://www.youtube.com/watch?v=...", text: $viewModel.videoURL)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isRunning)

                        Button("Paste") {
                            if let text = NSPasteboard.general.string(forType: .string) {
                                viewModel.videoURL = text
                            }
                        }
                        .disabled(viewModel.isRunning)
                    }
                } else {
                    HStack {
                        TextField("/Users/.../Desktop/raelynn-list.text", text: $viewModel.urlListFilePath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isRunning)
                        Button("Browse") {
                            viewModel.chooseURLListFile()
                        }
                        .disabled(viewModel.isRunning)
                    }
                }

                Text("Use URL list files with one URL per line (empty lines and #comments are ignored).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var settingsSection: some View {
        GroupBox("Download + Conversion") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(DownloadMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isRunning)

                    if viewModel.mode == .audioConvert {
                        Picker("Audio", selection: $viewModel.audioFormat) {
                            ForEach(AudioFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(viewModel.isRunning)
                    }

                    if viewModel.mode == .videoConvert {
                        Picker("Video", selection: $viewModel.videoFormat) {
                            ForEach(VideoFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(viewModel.isRunning)
                    }
                }

                HStack {
                    Text("Output directory")
                        .frame(width: 120, alignment: .leading)
                    TextField("/path/to/output", text: $viewModel.outputDirectory)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isRunning)
                    Button("Browse") {
                        viewModel.chooseOutputDirectory()
                    }
                    .disabled(viewModel.isRunning)
                }

                HStack {
                    Text("Filename template")
                        .frame(width: 120, alignment: .leading)
                    TextField("%(title)s.%(ext)s", text: $viewModel.outputTemplate)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isRunning)
                }
            }
            .padding(.top, 4)
        }
    }

    private var authSection: some View {
        GroupBox("YouTube Authentication") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Picker("Auth", selection: $viewModel.authMethod) {
                        ForEach(AuthMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isRunning)

                    if viewModel.authMethod == .cookiesFromBrowser {
                        Picker("Browser", selection: $viewModel.browserSource) {
                            ForEach(BrowserCookieSource.allCases) { browser in
                                Text(browser.title).tag(browser)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isRunning)
                    }
                }

                if viewModel.authMethod == .cookiesFile {
                    HStack {
                        Text("cookies.txt")
                            .frame(width: 120, alignment: .leading)
                        TextField("/path/to/cookies.txt", text: $viewModel.cookieFilePath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isRunning)
                        Button("Browse") {
                            viewModel.chooseCookieFile()
                        }
                        .disabled(viewModel.isRunning)
                    }
                }

                Text("If a video is restricted, switch to browser cookies or a cookies file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: viewModel.runDownload) {
                    Text(viewModel.isRunning ? "Running..." : "Start Download")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStart)

                Button("Cancel") {
                    viewModel.cancelDownload()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isRunning)

                Button("Refresh Tool Paths") {
                    viewModel.refreshToolPaths()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRunning)
            }

            if !viewModel.lastCommand.isEmpty {
                Text("Last command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.lastCommand)
                    .textSelection(.enabled)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
        }
    }

    private var logsSection: some View {
        GroupBox("Job Logs") {
            ScrollView {
                Text(viewModel.logText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(6)
            }
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(minHeight: 200)
        }
    }

    private var networkSection: some View {
        GroupBox("Network Throughput") {
            NetworkGraphView(
                samples: viewModel.downloadSpeedSamples,
                currentMbps: viewModel.currentDownloadSpeedMbps,
                peakMbps: viewModel.peakDownloadSpeedMbps
            )
            .padding(.top, 4)
        }
    }

    private func statusBadge(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(viewModel.isRunning ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            )
    }
}

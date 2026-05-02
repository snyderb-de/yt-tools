import Foundation

struct AppSettings: Codable {
    var inputMode: InputMode
    var videoURL: String
    var urlListFilePath: String
    var mode: DownloadMode
    var audioFormat: AudioFormat
    var videoFormat: VideoFormat
    var outputDirectory: String
    var outputTemplate: String
    var authMethod: AuthMethod
    var browserSource: BrowserCookieSource
    var cookieFilePath: String
    var presetName: String
}

struct UserPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var settings: AppSettings

    init(id: UUID = UUID(), name: String, settings: AppSettings) {
        self.id = id
        self.name = name
        self.settings = settings
    }
}

import Foundation

enum InputMode: String, CaseIterable, Identifiable, Codable {
    case singleURL
    case urlListFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleURL:
            return "Single URL"
        case .urlListFile:
            return "URL List File"
        }
    }
}

enum DownloadMode: String, CaseIterable, Identifiable, Codable {
    case audioExtract
    case audioConvert
    case videoConvert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audioExtract:
            return "Extract Audio Track"
        case .audioConvert:
            return "Convert to Audio"
        case .videoConvert:
            return "Convert Video Format"
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case mp3
    case m4a
    case wav
    case flac
    case opus

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }
}

enum VideoFormat: String, CaseIterable, Identifiable, Codable {
    case mp4
    case mkv
    case webm
    case mov

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }
}

enum AuthMethod: String, CaseIterable, Identifiable, Codable {
    case none
    case cookiesFromBrowser
    case cookiesFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "No Auth"
        case .cookiesFromBrowser:
            return "Use Browser Cookies"
        case .cookiesFile:
            return "Use cookies.txt"
        }
    }
}

enum BrowserCookieSource: String, CaseIterable, Identifiable, Codable {
    case safari
    case chrome
    case firefox
    case edge
    case brave

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct DownloadRequest {
    let url: String
    let mode: DownloadMode
    let audioFormat: AudioFormat
    let videoFormat: VideoFormat
    let outputDirectory: String
    let outputTemplate: String
    let authMethod: AuthMethod
    let browserSource: BrowserCookieSource
    let cookieFilePath: String
}

import Foundation
import Combine

enum AlertPosition: String, CaseIterable {
    case bottomRight = "Bottom Right"
    case bottomLeft  = "Bottom Left"
    case topRight    = "Top Right"
    case topLeft     = "Top Left"
    case center      = "Center"
}

enum LogFormat: String, CaseIterable {
    case singleFile = "Single log file"
    case perEntry   = "One file per entry"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    // MARK: — Timer
    @Published var intervalMinutes: Int       { didSet { d.set(intervalMinutes,       forKey: "intervalMinutes") } }
    @Published var skipRetryMinutes: Int      { didSet { d.set(skipRetryMinutes,      forKey: "skipRetryMinutes") } }
    @Published var autoDismissEnabled: Bool   { didSet { d.set(autoDismissEnabled,    forKey: "autoDismissEnabled") } }
    @Published var autoDismissSeconds: Int    { didSet { d.set(autoDismissSeconds,    forKey: "autoDismissSeconds") } }

    // MARK: — General
    @Published var showSettingsOnStartup: Bool { didSet { d.set(showSettingsOnStartup, forKey: "showSettingsOnStartup") } }

    // MARK: — Presets
    @Published var presetTags: [String]       { didSet { d.set(presetTags,            forKey: "presetTags") } }

    // MARK: — Storage
    @Published var logFormat: LogFormat       { didSet { d.set(logFormat.rawValue,    forKey: "logFormat") } }
    @Published var logPath: String            { didSet { d.set(logPath,               forKey: "logPath") } }

    // MARK: - Appearance
    @Published var alertPosition: AlertPosition { didSet { d.set(alertPosition.rawValue, forKey: "alertPosition") } }
    @Published var alertWidth: Double           { didSet { d.set(alertWidth,             forKey: "alertWidth") } }
    @Published var alertHeight: Double          { didSet { d.set(alertHeight,            forKey: "alertHeight") } }
    @Published var alertEdgePadding: Double     { didSet { d.set(alertEdgePadding,       forKey: "alertEdgePadding") } }
    @Published var alertBackgroundOpacity: Double { didSet { d.set(alertBackgroundOpacity, forKey: "alertBackgroundOpacity") } }
    @Published var alertCornerRadius: Double    { didSet { d.set(alertCornerRadius,      forKey: "alertCornerRadius") } }
    @Published var alertBorderWidth: Double     { didSet { d.set(alertBorderWidth,       forKey: "alertBorderWidth") } }

    static let defaultLogPath: String =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".timesheet-alert-comments")
            .path

    init() {
        intervalMinutes    = d.integer(forKey: "intervalMinutes").nonZero   ?? 30
        skipRetryMinutes   = d.integer(forKey: "skipRetryMinutes").nonZero  ?? 15
        autoDismissEnabled = d.object(forKey: "autoDismissEnabled") as? Bool ?? true
        autoDismissSeconds = d.integer(forKey: "autoDismissSeconds").nonZero ?? 120
        showSettingsOnStartup = d.object(forKey: "showSettingsOnStartup") as? Bool ?? true

        var savedTags = (d.array(forKey: "presetTags") as? [String]) ?? [
            "In a meeting", "Coding / Dev", "Debugging", "Reviewing PR", "Planning / Break", "Admin Work"
        ]
        if !savedTags.contains("Admin Work") {
            savedTags.append("Admin Work")
        }
        presetTags = savedTags

        logFormat = LogFormat(rawValue: d.string(forKey: "logFormat") ?? "") ?? .perEntry
        logPath   = d.string(forKey: "logPath") ?? AppSettings.defaultLogPath

        alertPosition    = AlertPosition(rawValue: d.string(forKey: "alertPosition") ?? "") ?? .bottomRight
        alertWidth       = d.double(forKey: "alertWidth").nonZero   ?? 350
        alertHeight      = d.double(forKey: "alertHeight").nonZero  ?? 280
        alertEdgePadding = d.double(forKey: "alertEdgePadding").nonZero ?? 20
        alertBackgroundOpacity = d.object(forKey: "alertBackgroundOpacity") as? Double ?? 1.0
        alertCornerRadius = d.object(forKey: "alertCornerRadius") as? Double ?? 12.0
        alertBorderWidth  = d.object(forKey: "alertBorderWidth") as? Double ?? 1.5
    }

    func resetToDefaults() {
        intervalMinutes    = 30
        skipRetryMinutes   = 15
        autoDismissEnabled = true
        autoDismissSeconds = 120
        showSettingsOnStartup = true
        presetTags         = ["In a meeting", "Coding / Dev", "Debugging", "Reviewing PR", "Planning / Break", "Admin Work"]
        logFormat          = .perEntry
        logPath            = AppSettings.defaultLogPath
        alertPosition      = .bottomRight
        alertWidth         = 350
        alertHeight        = 280
        alertEdgePadding   = 20
        alertBackgroundOpacity = 1.0
        alertCornerRadius  = 12.0
        alertBorderWidth   = 1.5
    }
}

private extension Int    { var nonZero: Int?    { self == 0 ? nil : self } }
private extension Double { var nonZero: Double? { self == 0.0 ? nil : self } }

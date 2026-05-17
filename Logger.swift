import Foundation
import os.log

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.studiomemo"

    private static let general   = Logger(subsystem: subsystem, category: "General")
    private static let audio     = Logger(subsystem: subsystem, category: "Audio")
    private static let persist   = Logger(subsystem: subsystem, category: "Persistence")
    private static let ai        = Logger(subsystem: subsystem, category: "AI")
    private static let ui        = Logger(subsystem: subsystem, category: "UI")

    static func info(_ msg: String,  category: LogCategory = .general) { logger(category).info("\(msg, privacy: .public)") }
    static func debug(_ msg: String, category: LogCategory = .general) { logger(category).debug("\(msg, privacy: .public)") }
    static func error(_ msg: String, category: LogCategory = .general) { logger(category).error("\(msg, privacy: .public)") }
    static func fault(_ msg: String, category: LogCategory = .general) { logger(category).fault("\(msg, privacy: .public)") }

    private static func logger(_ cat: LogCategory) -> Logger {
        switch cat {
        case .general:     return general
        case .audio:       return audio
        case .persistence: return persist
        case .ai:          return ai
        case .ui:          return ui
        }
    }

    enum LogCategory {
        case general, audio, persistence, ai, ui
    }
}

import Foundation
import os

/// Centralized logger for WootDesk with strict privacy controls.
///
/// Under no circumstances should authentication tokens, raw customer messages,
/// or credentials be logged through these loggers.
public enum AppLogger {
    private static let subsystem = "dev.n85.wootdesk"

    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}

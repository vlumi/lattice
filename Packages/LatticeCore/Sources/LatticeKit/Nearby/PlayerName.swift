import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// The player's display name — used ONLY as the label other devices see in the
/// Nearby browser (AGENTS.md "Two-player identity"). Not an identity, never
/// persisted into a game/record or synced. Defaults to the device name.
enum PlayerName {
    static let defaultsKey = "lattice.playerName"

    static func current(in defaults: UserDefaults = .standard) -> String {
        let stored = defaults.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty { return stored }
        return deviceName
    }

    static func set(_ name: String, in defaults: UserDefaults = .standard) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(String(trimmed.prefix(60)), forKey: defaultsKey)
        }
    }

    private static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Lattice player"
        #endif
    }
}

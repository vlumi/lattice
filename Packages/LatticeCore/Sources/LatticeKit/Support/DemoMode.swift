import Foundation
import LatticeCore

/// Demo mode for App Store screenshots: seeded, believable player data so
/// captures show a played-in app rather than empty state, identical on every
/// device and in every language.
///
/// Two launch arguments, deliberately separate:
/// - `-demo-clean` routes persistence to a wiped temp directory and forces sync
///   off. This is the **isolation gate** — the debug build shares the shipped
///   app's bundle id and container, so without it a demo run would overwrite the
///   real player's bests and replays. (This already happened once on the dev Mac
///   before the gate existed.)
/// - `-demo-seed` fills that clean store with the fixture data below.
///
/// Ships inert: neither argument is ever present in a normal launch.
public enum DemoMode {
    public static var isClean: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-clean")
    }

    public static var isSeeded: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-seed")
    }

    /// The store this launch should use. Isolated under `-demo-clean`, so demo
    /// data can never reach the real container.
    public static func store() -> LatticeStore {
        isClean ? .ephemeral() : .appSupport()
    }

    /// Defaults suite for settings, isolated the same way — otherwise a demo run
    /// would flip the real player's sound/haptics/sync switches.
    public static var defaults: UserDefaults {
        guard isClean else { return .standard }
        let suite = UserDefaults(suiteName: "fi.misaki.lattice.demo")!
        suite.removePersistentDomain(forName: "fi.misaki.lattice.demo")
        return suite
    }
}

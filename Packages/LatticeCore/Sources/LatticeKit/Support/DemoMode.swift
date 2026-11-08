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

    /// `-demo-tab <free|daily|versus|history|settings>`: the tab a screenshot
    /// starts on, so `make shots` can stage it without a tap. Clean runs only.
    static var tab: String? {
        let args = ProcessInfo.processInfo.arguments
        guard isClean, let i = args.firstIndex(of: "-demo-tab"), i + 1 < args.count else {
            return nil
        }
        return args[i + 1]
    }

    /// `-demo-pending`: a dot already pending on the opening board, its
    /// candidate lines fanned out. Clean runs only.
    static var stagesPendingDot: Bool {
        isClean && ProcessInfo.processInfo.arguments.contains("-demo-pending")
    }

    /// A placeable point that shows the choice well: one offering at least
    /// three lines, the farthest from the board's centre, so its lines fan out
    /// at the edge rather than tangle with the played ones. Ties go to the
    /// topmost, then leftmost, so the pick is the same every run.
    static func showcasePoint(in session: GameSession) -> Point? {
        let bounds = Bounds(of: session.game.dots)
        let centreX = Double(bounds.minX + bounds.maxX) / 2
        let centreY = Double(bounds.minY + bounds.maxY) / 2
        let rich = session.movesByDot.filter { $0.value.count >= 3 }
        let pool = rich.isEmpty ? session.movesByDot : rich
        func distance(_ p: Point) -> Double {
            let dx = Double(p.x) - centreX
            let dy = Double(p.y) - centreY
            return dx * dx + dy * dy
        }
        return pool.keys.max { a, b in
            distance(a) != distance(b) ? distance(a) < distance(b) : (a.y, -a.x) < (b.y, -b.x)
        }
    }

    /// The store this launch should use. Isolated under `-demo-clean`, so demo
    /// data can never reach the real container.
    public static func store() -> LatticeStore {
        isClean ? .ephemeral() : .appSupport()
    }

    /// Defaults suite for settings, isolated the same way — otherwise a demo run
    /// would flip the real player's sound/haptics/sync switches.
    ///
    /// Resolved ONCE: the wipe has to happen at launch, not per access. This is
    /// also read from a view body (`defaultAppStorage`), which re-runs on every
    /// update — wiping there would erase a setting the moment it was changed.
    public static let defaults: UserDefaults = {
        guard isClean else { return .standard }
        let suite = UserDefaults(suiteName: "fi.misaki.lattice.demo")!
        suite.removePersistentDomain(forName: "fi.misaki.lattice.demo")
        return suite
    }()
}

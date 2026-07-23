import Foundation
import LatticeCore
import SwiftUI

/// App-level owner of iCloud sync: the opt-in toggle, the coordinator, and
/// the bridge to the shared store. Kept out of GameSession so sync never
/// tangles into game logic — the session just calls `localDidChange()` when
/// it writes a best or daily result.
@MainActor
public final class SyncController: ObservableObject {
    private static let enabledKey = "lattice.sync.enabled"

    @Published public var isOn: Bool {
        didSet {
            guard isOn != oldValue else { return }
            defaults.set(isOn, forKey: Self.enabledKey)
            coordinator.setEnabled(isOn)
        }
    }

    /// True once a cloud is actually reachable (drives whether the toggle can
    /// do anything).
    public let isAvailable: Bool

    /// Bumped whenever a merge changed local state, so views re-read the store.
    @Published public private(set) var revision = 0

    private let coordinator: SyncCoordinator
    private let defaults: UserDefaults

    public init(store: LatticeStore, cloud: CloudStore, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isAvailable = cloud.isAvailable
        let bridge = StoreBridge(store: store)
        coordinator = SyncCoordinator(local: bridge, cloud: cloud, enabled: enabled)
        isOn = enabled
        coordinator.onStateChanged = { [weak self] _ in
            self?.revision += 1
        }
        if coordinator.isActive { coordinator.localDidChange() }
    }

    /// The session calls this after persisting a best / daily result.
    public func localDidChange() {
        coordinator.localDidChange()
    }

    /// Adapts LatticeStore to the coordinator's LocalState.
    private final class StoreBridge: SyncCoordinator.LocalState {
        let store: LatticeStore
        init(store: LatticeStore) { self.store = store }
        func load() -> SyncedState { store.loadSyncedState() }
        func save(_ state: SyncedState) { store.saveSyncedState(state) }
    }
}

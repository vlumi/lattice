import Foundation

/// Keeps the local synced state (bests + daily log) in step with the cloud.
///
/// The whole model is read-merge-write over one shared blob: any local change
/// or any external cloud change triggers a merge of local+cloud, which is
/// written back both locally and to the cloud. Because `SyncedState.merged`
/// is commutative and idempotent, concurrent writers converge and a lost
/// write self-heals on the next change — no clock, no DeviceID, no conflict
/// resolution (see AGENTS.md "iCloud sync model").
///
/// Sync is opt-in: with it off (or iCloud unavailable) the coordinator is
/// inert and the app runs purely local.
public final class SyncCoordinator {
    /// Reads and writes the device-local synced state.
    public protocol LocalState: AnyObject {
        func load() -> SyncedState
        func save(_ state: SyncedState)
    }

    private let local: LocalState
    private let cloud: CloudStore
    public private(set) var isEnabled: Bool

    /// Called after a merge changes the local state, so the UI can refresh.
    public var onStateChanged: ((SyncedState) -> Void)?

    public init(local: LocalState, cloud: CloudStore, enabled: Bool) {
        self.local = local
        self.cloud = cloud
        isEnabled = enabled
        cloud.onExternalChange = { [weak self] in
            self?.reconcile()
        }
    }

    public var isActive: Bool { isEnabled && cloud.isAvailable }

    /// Turn sync on/off. Turning on immediately reconciles (pull down + push
    /// up the union); turning off leaves local data untouched.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if isActive { reconcile() }
    }

    /// A local change happened (finished game, daily result) — fold it into
    /// the cloud. No-op when inactive.
    public func localDidChange() {
        guard isActive else { return }
        reconcile()
    }

    /// Merge local + cloud, write the result to both. Idempotent: if nothing
    /// changed, no callback and no redundant cloud write.
    private func reconcile() {
        guard isActive else { return }
        let localState = local.load()
        let cloudState = cloud.read().flatMap(SyncedState.decoded(from:))
        let merged = cloudState.map { localState.merged(with: $0) } ?? localState

        if merged != localState {
            local.save(merged)
            onStateChanged?(merged)
        }
        // Push up unless the cloud already equals the merge (avoids a write
        // loop when two devices converge).
        if cloudState != merged, let data = merged.encoded() {
            cloud.write(data)
        }
    }
}

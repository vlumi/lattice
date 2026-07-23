import Foundation

/// The cloud side of sync, behind a protocol so the coordinator is testable
/// with a fake (the real store needs a signed-in iCloud device). A SINGLE
/// shared blob under one key — not per-device — because `SyncedState` merges
/// commutatively (see AGENTS.md "iCloud sync model").
public protocol CloudStore: AnyObject {
    var isAvailable: Bool { get }
    func read() -> Data?
    func write(_ data: Data)
    /// Fired when another device changed the blob (KVS external change).
    var onExternalChange: (() -> Void)? { get set }
}

#if canImport(Foundation) && !os(Linux)
/// `NSUbiquitousKeyValueStore`-backed store — one key, the whole blob.
public final class UbiquitousCloudStore: CloudStore {
    private static let key = "lattice.sync.state"

    private let kvs = NSUbiquitousKeyValueStore.default
    public var onExternalChange: (() -> Void)?
    private var observer: NSObjectProtocol?

    public init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] _ in
            self?.onExternalChange?()
        }
        kvs.synchronize()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    public var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    public func read() -> Data? { kvs.data(forKey: Self.key) }

    public func write(_ data: Data) {
        kvs.set(data, forKey: Self.key)
        kvs.synchronize()
    }
}
#endif

/// In-memory fake for tests — model a shared cloud slot two coordinators can
/// point at to exercise cross-device merge.
public final class FakeCloudStore: CloudStore {
    public var isAvailable: Bool
    private var stored: Data?
    public var onExternalChange: (() -> Void)?

    public init(isAvailable: Bool = true, stored: Data? = nil) {
        self.isAvailable = isAvailable
        self.stored = stored
    }

    public func read() -> Data? { stored }

    public func write(_ data: Data) { stored = data }

    /// Simulate another device having written the slot, notifying observers.
    public func inject(_ data: Data) {
        stored = data
        onExternalChange?()
    }
}

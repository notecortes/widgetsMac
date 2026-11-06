import Foundation

public final class SharedSnapshotStore: @unchecked Sendable {
    public static let shared = SharedSnapshotStore()

    public static let appGroupID = "group.app.pulse"
    public static let fileName = "snapshot.json"

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    private init() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    /// Resolves the storage URL: prefers App Group container if accessible/creatable, falls back to Application Support
    public var preferredDirectoryURL: URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: groupURL.path, isDirectory: &isDir), isDir.boolValue {
                return groupURL
            }
            do {
                try fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true)
                return groupURL
            } catch {
                // Group container cannot be created (e.g. ad-hoc / un-entitled process / SIP restriction)
            }
        }

        // Direct Group Containers directory path fallback if already existing
        let groupContainers = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(Self.appGroupID, isDirectory: true)
        var isGroupDir: ObjCBool = false
        if fileManager.fileExists(atPath: groupContainers.path, isDirectory: &isGroupDir), isGroupDir.boolValue {
            return groupContainers
        }

        // Fallback to Application Support/PulseMonitor
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PulseMonitor", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var storageFileURL: URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID),
           fileManager.isWritableFile(atPath: groupURL.path) {
            return groupURL.appendingPathComponent(Self.fileName)
        }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PulseMonitor", isDirectory: true)
        return dir.appendingPathComponent(Self.fileName)
    }

    /// Writes a snapshot to disk atomically
    public func save(_ snapshot: SystemSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? encoder.encode(snapshot) else { return }

        // 1. Always save to Application Support (guaranteed writable)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("PulseMonitor", isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let fallbackURL = dir.appendingPathComponent(Self.fileName)
            try? data.write(to: fallbackURL, options: .atomic)
        }

        // 2. Try saving to App Group container if accessible
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            let fileURL = groupURL.appendingPathComponent(Self.fileName)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // In ad-hoc mode without Apple Developer profile, macOS restricts Group Container writes
                PulseLog.monitor.debug("App Group not directly writable in ad-hoc: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Reads snapshot from disk, returning nil if no snapshot exists yet
    public func loadOptional() -> SystemSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        // 1. Try App Group container
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            let file = groupURL.appendingPathComponent(Self.fileName)
            if let data = try? Data(contentsOf: file),
               let snapshot = try? decoder.decode(SystemSnapshot.self, from: data) {
                return snapshot
            }
        }

        // 2. Try Application Support fallback
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let file = appSupport.appendingPathComponent("PulseMonitor/\(Self.fileName)")
            if let data = try? Data(contentsOf: file),
               let snapshot = try? decoder.decode(SystemSnapshot.self, from: data) {
                return snapshot
            }
        }

        return nil
    }

    /// Reads snapshot from disk, returning preview fallback if not yet available
    public func load() -> SystemSnapshot {
        return loadOptional() ?? .preview
    }
}

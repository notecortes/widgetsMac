import Foundation

public final class SharedSnapshotStore: @unchecked Sendable {
    public static let shared = SharedSnapshotStore()

    public static var appGroupID: String {
        if let custom = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String, !custom.isEmpty {
            return custom
        }
        return "SA7RK66C85.group.app.pulse"
    }
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

    /// Discovers all potential Group Container directories across entitlements and filesystem
    public var candidateGroupContainers: [URL] {
        var urls: [URL] = []

        // 1. App group from Info.plist / configuration
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            urls.append(groupURL)
        }

        // 2. Direct team prefixed group
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "SA7RK66C85.group.app.pulse"), !urls.contains(group) {
            urls.append(group)
        }

        return urls
    }

    /// Resolves the storage URL: prefers App Group container if accessible/creatable, falls back to Application Support
    public var preferredDirectoryURL: URL {
        if let primary = candidateGroupContainers.first {
            if fileManager.fileExists(atPath: primary.path) {
                return primary
            }
            if (try? fileManager.createDirectory(at: primary, withIntermediateDirectories: true)) != nil {
                return primary
            }
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
        return preferredDirectoryURL.appendingPathComponent(Self.fileName)
    }

    private func writeSafely(data: Data, to fileURL: URL) {
        do {
            try data.write(to: fileURL, options: .atomic)
            PulseLog.monitor.info("✅ Guardado snapshot.json (atómico) en: \(fileURL.path, privacy: .public)")
        } catch {
            do {
                try data.write(to: fileURL)
                PulseLog.monitor.info("✅ Guardado snapshot.json (directo) en: \(fileURL.path, privacy: .public)")
            } catch {
                PulseLog.monitor.error("❌ Fallo al escribir snapshot en \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Writes a snapshot to disk across all valid destinations
    public func save(_ snapshot: SystemSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        PulseLog.monitor.info("[SNAPSHOT] candidateGroupContainers: \(self.candidateGroupContainers.map { $0.path }, privacy: .public)")

        guard let data = try? encoder.encode(snapshot) else {
            PulseLog.monitor.error("Fallo al codificar SystemSnapshot a JSON")
            return
        }

        // 1. Always save to Application Support (guaranteed writable by main app)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("PulseMonitor", isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let fallbackURL = dir.appendingPathComponent(Self.fileName)
            writeSafely(data: data, to: fallbackURL)
        }

        // 2. Save to all discovered candidate App Group containers
        for dir in candidateGroupContainers {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let fileURL = dir.appendingPathComponent(Self.fileName)
            writeSafely(data: data, to: fileURL)
        }
    }

    /// Reads snapshot from disk, returning nil if no snapshot exists yet
    public func loadOptional() -> SystemSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        // 1. Try candidate App Group containers
        for dir in candidateGroupContainers {
            let file = dir.appendingPathComponent(Self.fileName)
            if fileManager.fileExists(atPath: file.path),
               let data = try? Data(contentsOf: file) {
                do {
                    let snapshot = try decoder.decode(SystemSnapshot.self, from: data)
                    PulseLog.monitor.debug("Snapshot decodificado desde App Group: \(file.path, privacy: .public)")
                    return snapshot
                } catch {
                    PulseLog.monitor.error("Error al decodificar snapshot en \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // 2. Try Application Support fallback
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let file = appSupport.appendingPathComponent("PulseMonitor/\(Self.fileName)")
            if fileManager.fileExists(atPath: file.path),
               let data = try? Data(contentsOf: file) {
                do {
                    let snapshot = try decoder.decode(SystemSnapshot.self, from: data)
                    PulseLog.monitor.debug("Snapshot decodificado desde Application Support: \(file.path, privacy: .public)")
                    return snapshot
                } catch {
                    PulseLog.monitor.error("Error al decodificar snapshot en Application Support: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        return nil
    }

    /// Reads snapshot from disk, returning nil if not available (never returns demo data)
    public func load() -> SystemSnapshot? {
        return loadOptional()
    }
}

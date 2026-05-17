import Foundation

final class FileStore {
    private let fm = FileManager.default
    private let root: URL

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("StudioMemo", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: - Directory layout
    func sessionDirectory(for id: UUID) -> URL {
        let url = root.appendingPathComponent("Sessions/\(id.uuidString)", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func audioDirectory(for sessionId: UUID) -> URL {
        let url = sessionDirectory(for: sessionId).appendingPathComponent("Audio", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func exportDirectory(for sessionId: UUID) -> URL {
        let url = sessionDirectory(for: sessionId).appendingPathComponent("Exports", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func stemDirectory(for sessionId: UUID) -> URL {
        let url = sessionDirectory(for: sessionId).appendingPathComponent("Stems", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func metadataURL(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("session.json")
    }

    func clipsMetadataURL(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("clips.json")
    }

    func markersMetadataURL(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("markers.json")
    }

    func transcriptURL(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("transcript.json")
    }

    // MARK: - Root listing
    var allSessionDirectories: [URL] {
        let sessionsRoot = root.appendingPathComponent("Sessions")
        guard let contents = try? fm.contentsOfDirectory(at: sessionsRoot,
                                                          includingPropertiesForKeys: [.isDirectoryKey],
                                                          options: .skipsHiddenFiles) else { return [] }
        return contents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }

    // MARK: - Temp
    func tempURL(suffix: String = ".caf") -> URL {
        let tmp = fm.temporaryDirectory.appendingPathComponent("sm_\(UUID().uuidString)\(suffix)")
        return tmp
    }

    // MARK: - Write / Read helpers
    func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw AppError.persistence(.writeFailure(url, error))
        }
    }

    func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        guard fm.fileExists(atPath: url.path) else {
            throw AppError.persistence(.readFailure(url, URLError(.fileDoesNotExist)))
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch let e as DecodingError {
            throw AppError.persistence(.decodingFailed(e))
        } catch {
            throw AppError.persistence(.readFailure(url, error))
        }
    }

    // MARK: - Delete session
    func deleteSession(_ id: UUID) throws {
        let dir = sessionDirectory(for: id)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }

    // MARK: - Disk usage
    func diskUsage(for sessionId: UUID) -> Int64 {
        let dir = sessionDirectory(for: sessionId)
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

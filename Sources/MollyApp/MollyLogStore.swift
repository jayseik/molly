import AppKit
import Foundation
import UniformTypeIdentifiers

enum MollyLogLevel: String, Codable { case debug, info, warn, error }

protocol MollyLogging: AnyObject {
    func append(level: MollyLogLevel, message: String, meta: [String: String])
}

struct MollyLogLine: Codable, Identifiable, Hashable {
    var id: String
    var unixSeconds: Double
    var iso8601UTC: String
    var level: MollyLogLevel
    var message: String
    var metaJSON: String
}

@MainActor
final class MollyLogStore: ObservableObject, MollyLogging {

    @Published private(set) var entries: [MollyLogLine] = []

    private let fm = FileManager.default
    private let retentionDays: Double = 7
    private let maxInMemoryLines = 500

    private var logFileURL: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Molly", isDirectory: true)
        if fm.fileExists(atPath: dir.path) == false {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("molly.jsonl", isDirectory: false)
    }

    init() {
        loadFromDisk()
        pruneOldEntries()
    }

    func append(level: MollyLogLevel, message: String, meta: [String: String]) {
        let now = Date()
        let unix = now.timeIntervalSince1970

        struct MetaEnvelope: Codable {
            let values: [String: String]
        }

        let metaData = try? JSONEncoder().encode(MetaEnvelope(values: meta))
        let metaString = metaData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let line = MollyLogLine(
            id: "\(unix)-\(UUID().uuidString)",
            unixSeconds: unix,
            iso8601UTC: ISO8601DateFormatter().string(from: now),
            level: level,
            message: message,
            metaJSON: metaString
        )

        entries.insert(line, at: 0)

        while entries.count > maxInMemoryLines {
            entries.removeLast()
        }

        persist(line: line)
    }

    /// Export plaintext JSON Lines via save panel invoked from UI layer.
    func exportPlaintextJSONLines() {
        guard let data = encodeAllLinesUTF8Data() else { return }
        presentSavePanel(with: data, suggestedName: "molly-export.jsonl")
    }

    func clearInMemoryMirror() {
        entries.removeAll()
    }

    // MARK: - Disk persistence (JSON Lines append)

    private func persist(line: MollyLogLine) {
        pruneOldEntriesPersisted()
        guard let row = try? JSONEncoder().encode(line),
              var text = String(data: row, encoding: .utf8) else {
            return
        }
        text.append("\n")
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            try? text.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: logFileURL),
              let raw = String(data: data, encoding: .utf8) else { return }

        var parsed: [MollyLogLine] = []
        for split in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            if let rowData = String(split).data(using: .utf8),
               let line = try? JSONDecoder().decode(MollyLogLine.self, from: rowData) {
                parsed.append(line)
            }
        }
        parsed.sort { $0.unixSeconds > $1.unixSeconds }
        entries = Array(parsed.prefix(maxInMemoryLines))
    }

    private func pruneOldEntries() {
        let cutoff = Date().addingTimeInterval(-retentionDays * 24 * 3600).timeIntervalSince1970
        entries.removeAll { $0.unixSeconds < cutoff }
    }

    private func pruneOldEntriesPersisted() {
        guard let data = try? Data(contentsOf: logFileURL),
              let raw = String(data: data, encoding: .utf8) else { return }

        let cutoff = Date().addingTimeInterval(-retentionDays * 24 * 3600).timeIntervalSince1970
        var kept: [MollyLogLine] = []
        for split in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let rowData = String(split).data(using: .utf8),
                  let line = try? JSONDecoder().decode(MollyLogLine.self, from: rowData) else {
                continue
            }
            if line.unixSeconds >= cutoff {
                kept.append(line)
            }
        }
        let encoded = kept.compactMap { line -> String? in
            guard let data = try? JSONEncoder().encode(line) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        let joined = encoded.joined(separator: "\n")
        try? joined.write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    private func encodeAllLinesUTF8Data() -> Data? {
        let reversed = entries.sorted { $0.unixSeconds > $1.unixSeconds }
        let lines = reversed.compactMap { line -> String? in
            guard let row = try? JSONEncoder().encode(line) else { return nil }
            return String(data: row, encoding: .utf8)
        }
        let joined = lines.joined(separator: "\n")
        return joined.data(using: .utf8)
    }

    private func presentSavePanel(with data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK,
              let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            append(level: .error, message: "Export failed: \(error.localizedDescription)", meta: [:])
        }
    }
}

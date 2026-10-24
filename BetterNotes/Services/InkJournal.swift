import Foundation

/// A small on-device log of changes to a page's ink: which code path changed
/// it and how many strokes it held afterwards. It exists because some bugs --
/// strokes that move, resize or come back after a big erase -- happen too
/// rarely to catch live. After one, the log shows the sequence that led to it.
///
/// It records event names and counts only, never stroke data or note text, and
/// stays in the app's own Application Support folder. It keeps roughly the
/// last 256 KB.
enum InkJournal {
    private static let queue = DispatchQueue(label: "betternotes.ink-journal", qos: .utility)
    private static let maxBytes = 256 * 1024
    private static let url: URL = {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return (base ?? FileManager.default.temporaryDirectory).appendingPathComponent("InkJournal.log")
    }()
    private static let stamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func record(_ event: String, strokes: Int? = nil, _ detail: String = "") {
        let line = "\(stamp.string(from: Date())) \(event) strokes=\(strokes.map(String.init) ?? "-") \(detail)\n"
        queue.async {
            let manager = FileManager.default
            if !manager.fileExists(atPath: url.path) {
                manager.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            trimIfNeeded()
        }
    }

    /// Drops the older half once the file passes its limit.
    private static func trimIfNeeded() {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int,
              size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        var tail = data.suffix(maxBytes / 2)
        if let newline = tail.firstIndex(of: UInt8(ascii: "\n")) {
            tail = tail[tail.index(after: newline)...]
        }
        try? Data(tail).write(to: url, options: .atomic)
    }
}

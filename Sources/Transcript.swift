import Foundation

struct ReplySnapshot {
    var text = ""
    var timestamp = ""
    var working = false
}

// Read-only adapter for local Codex JSONL transcripts; no credentials or database writes.
// The file format is not a stable public API. Keep this adapter isolated.
final class TranscriptReader {
    private(set) var snapshot = ReplySnapshot()
    private var pending = Data()
    private var offset: UInt64 = 0
    private var file: URL?
    private var threadID = ""
    private let root: URL
    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")) { self.root = root }

    func reset() {
        snapshot = ReplySnapshot(); pending = Data(); offset = 0; file = nil
    }
    func consume(_ data: Data) {
        pending.append(data)
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline)
            pending.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = object["payload"] as? [String: Any] else { continue }
            let stamp = object["timestamp"] as? String ?? ""
            if object["type"] as? String == "event_msg" {
                switch payload["type"] as? String {
                case "task_started": snapshot.working = true
                case "task_complete":
                    snapshot.working = false
                    if let text = payload["last_agent_message"] as? String, !text.isEmpty {
                        snapshot.text = text; snapshot.timestamp = stamp
                    }
                case "turn_aborted": snapshot.working = false
                default: break
                }
            }
            if object["type"] as? String == "response_item",
               payload["type"] as? String == "message",
               payload["role"] as? String == "assistant",
               payload["phase"] as? String == "final_answer" {
                let content = payload["content"] as? [[String: Any]] ?? []
                let text = content.filter { $0["type"] as? String == "output_text" }.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if !text.isEmpty { snapshot.text = text; snapshot.timestamp = stamp }
            }
        }
    }
    func poll(thread: String) throws -> ReplySnapshot? {
        guard UUID(uuidString: thread) != nil else { reset(); return nil }
        if thread != threadID { reset(); threadID = thread }
        if file == nil {
            guard let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
            for case let url as URL in items {
                if url.lastPathComponent.hasSuffix("-\(thread).jsonl") { file = url; break }
            }
        }
        guard let file = file else { return nil }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        if end < offset { offset = 0; pending = Data(); snapshot = ReplySnapshot() }
        // Stream bounded chunks, retaining an incomplete final line until the next poll.
        try handle.seek(toOffset: offset)
        var remaining = end - offset
        while remaining > 0 {
            let data = try handle.read(upToCount: Int(min(remaining, 65536))) ?? Data()
            if data.isEmpty { break }
            offset += UInt64(data.count); remaining -= UInt64(data.count)
            consume(data)
        }
        return snapshot
    }
}

import Cocoa
import SwiftUI

struct ThreadTurn: Identifiable, Equatable {
    let id: Int
    var time: Date?
    var screenshot: URL?
    var note = ""
    var reply = ""
    var isDeck = false
    var isPick = false
    /// "P1P3" when the pick's 17Lands data was included in the message.
    var position = ""
}

func claudeSessionFile(_ session: String,
                       root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")) -> URL? {
    let projects = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
    return projects.map { $0.appendingPathComponent("\(session).jsonl") }
        .first { FileManager.default.fileExists(atPath: $0.path) }
}

/// Rebuilds the coaching conversation from a Claude Code session transcript (read-only).
/// Each Draft Coach request starts a turn; the last assistant text before the next
/// request is its coaching. Tool calls, thinking and sidechains are skipped.
func parseClaudeThread(_ data: Data) -> [ThreadTurn] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var turns: [ThreadTurn] = []
    for line in data.split(separator: 10) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["isSidechain"] as? Bool != true, object["isMeta"] as? Bool != true,
              let message = object["message"] as? [String: Any] else { continue }
        let type = object["type"] as? String
        if type == "user", let prompt = message["content"] as? String {
            var turn = ThreadTurn(id: turns.count, time: (object["timestamp"] as? String).flatMap(formatter.date(from:)))
            for row in prompt.components(separatedBy: .newlines) {
                if let range = row.range(of: "image-viewing tool: ") {
                    turn.screenshot = URL(fileURLWithPath: String(row[range.upperBound...]))
                } else if let range = row.range(of: "My context / actual previous pick: ") ?? row.range(of: "My thinking: ") {
                    turn.note = String(row[range.upperBound...])
                }
            }
            turn.isDeck = prompt.hasPrefix("Deck building") || prompt.hasPrefix("Deck review")
            turn.isPick = prompt.hasPrefix("Draft coaching")
            if let match = prompt.range(of: #""position":\{"pack":(\d+),"pick":(\d+)\}"#, options: .regularExpression) {
                let numbers = prompt[match].split(whereSeparator: { !$0.isNumber })
                if numbers.count == 2 { turn.position = "P\(numbers[0])P\(numbers[1])" }
            }
            // Free-form follow-ups typed in Terminal show up as notes.
            if !turn.isPick && !turn.isDeck { turn.note = prompt }
            turns.append(turn)
        } else if type == "assistant", !turns.isEmpty, let content = message["content"] as? [[String: Any]] {
            let text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
                .joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { turns[turns.count - 1].reply = text }
        }
    }
    return turns
}

struct ThreadView: View {
    @ObservedObject var coach: Coach
    @State private var turns: [ThreadTurn] = []

    func reload() {
        let session = coach.draft.lowercased()
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = claudeSessionFile(session).flatMap { try? Data(contentsOf: $0) }.map(parseClaudeThread) ?? []
            DispatchQueue.main.async { turns = loaded }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Draft thread").font(.system(size: 16, weight: .semibold))
                Text("\(turns.count) message\(turns.count == 1 ? "" : "s")").foregroundColor(.secondary)
                Spacer()
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("Reload")
                Button("Open in Terminal", action: coach.openClaudeInTerminal).controlSize(.small)
            }.padding(.horizontal, 18).padding(.vertical, 12)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if turns.isEmpty {
                            Text("No Claude coaching yet for this draft. Capture a pick in Claude mode and it will appear here.")
                                .foregroundColor(.secondary).padding(.top, 30).frame(maxWidth: .infinity)
                        }
                        ForEach(turns) { turn in
                            TurnCard(turn: turn, number: turn.id + 1).id(turn.id)
                        }
                    }.padding(18)
                }
                .onChange(of: turns) { _, value in
                    if let last = value.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(.regularMaterial)
        .onAppear(perform: reload)
        .onChange(of: coach.reply) { _, _ in reload() }
        .onChange(of: coach.draft) { _, _ in reload() }
    }
}

private struct TurnCard: View {
    let turn: ThreadTurn
    let number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if let url = turn.screenshot, let image = NSImage(contentsOf: url) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: 120, height: 78).cornerRadius(5)
                    }.buttonStyle(.plain).help("Open screenshot")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(turn.isDeck ? "Deck" : turn.isPick || turn.screenshot != nil ? (turn.position.isEmpty ? "Pick \(number)" : turn.position) : "You").font(.system(size: 13, weight: .semibold))
                    if let time = turn.time {
                        Text(time.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundColor(.secondary)
                    }
                    if !turn.note.isEmpty {
                        Text(turn.note).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(4).textSelection(.enabled)
                    }
                }
            }
            if turn.reply.isEmpty {
                Text("Waiting for Claude…").font(.system(size: 13)).foregroundColor(.secondary)
            } else {
                MarkdownText(text: turn.reply)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}

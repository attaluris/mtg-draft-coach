import SwiftUI

/// Small block-level Markdown renderer for coaching replies: headings, bullet and
/// numbered lists, rules and paragraphs. Inline styling (bold, italic, code, links)
/// comes from Foundation's Markdown parser.
struct MarkdownText: View {
    let text: String
    var size: CGFloat = 13

    enum Block: Equatable {
        case heading(Int, String), bullet(String), numbered(String, String), rule, paragraph(String)
    }

    static func blocks(_ text: String) -> [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.range(of: "^(-{3,}|\\*{3,}|_{3,})$", options: .regularExpression) != nil { flush(); result.append(.rule); continue }
            if let match = line.range(of: "^#{1,6} ", options: .regularExpression) {
                flush(); result.append(.heading(line.distance(from: match.lowerBound, to: match.upperBound) - 1, String(line[match.upperBound...]))); continue
            }
            if let match = line.range(of: "^[-*•] ", options: .regularExpression) {
                flush(); result.append(.bullet(String(line[match.upperBound...]))); continue
            }
            if let match = line.range(of: "^\\d{1,3}[.)] ", options: .regularExpression) {
                flush(); result.append(.numbered(String(line[..<match.upperBound]).trimmingCharacters(in: .whitespaces), String(line[match.upperBound...]))); continue
            }
            paragraph.append(line)
        }
        flush()
        return result
    }

    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(Self.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(Self.inline(content)).font(.system(size: size + CGFloat(max(0, 4 - level)), weight: .semibold))
                        .padding(.top, 2)
                case .bullet(let content):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundColor(.teal)
                        Text(Self.inline(content))
                    }
                case .numbered(let marker, let content):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(marker).foregroundColor(.teal).monospacedDigit()
                        Text(Self.inline(content))
                    }
                case .rule:
                    Divider()
                case .paragraph(let content):
                    Text(Self.inline(content))
                }
            }
        }
        .font(.system(size: size))
        .lineSpacing(2)
        .textSelection(.enabled)
        .tint(.teal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

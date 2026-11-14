import Combine
import Foundation

struct HelloSpellingCorrection: Codable, Equatable, Identifiable, Sendable {
    let heard: String
    let spelling: String
    var id: String { heard.lowercased() }
}

enum HelloSpellingPolicy {
    private static let wordPattern = "[\\p{L}\\p{M}]+(?:['’\\-][\\p{L}\\p{M}]+)*"

    static func isValid(_ correction: HelloSpellingCorrection) -> Bool {
        guard correction.heard != correction.spelling else { return false }
        return [correction.heard, correction.spelling].allSatisfy { value in
            guard !value.isEmpty, value.utf16.count <= 80 else { return false }
            return value.range(of: "^" + wordPattern + "(?: " + wordPattern + "){0,2}$",
                               options: .regularExpression) != nil
        }
    }

    /// Suggest only one short, contiguous word/phrase edit. Approval is still
    /// required: an ordinary word substitution can be a change in meaning.
    static func suggestion(inserted: String, corrected: String) -> HelloSpellingCorrection? {
        guard inserted != corrected, inserted.utf16.count <= 4_000, corrected.utf16.count <= 4_000 else { return nil }
        let regex = try! NSRegularExpression(pattern: wordPattern)
        let old = inserted as NSString, new = corrected as NSString
        let a = regex.matches(in: inserted, range: NSRange(location: 0, length: old.length))
        let b = regex.matches(in: corrected, range: NSRange(location: 0, length: new.length))
        var head = 0
        while head < min(a.count, b.count), old.substring(with: a[head].range) == new.substring(with: b[head].range) { head += 1 }
        var tail = 0
        while tail < min(a.count, b.count) - head,
              old.substring(with: a[a.count - tail - 1].range) == new.substring(with: b[b.count - tail - 1].range) { tail += 1 }
        let oldCount = a.count - head - tail, newCount = b.count - head - tail
        guard (1...3).contains(oldCount), (1...3).contains(newCount) else { return nil }
        let ar = NSRange(location: a[head].range.location,
                         length: NSMaxRange(a[a.count - tail - 1].range) - a[head].range.location)
        let br = NSRange(location: b[head].range.location,
                         length: NSMaxRange(b[b.count - tail - 1].range) - b[head].range.location)
        guard old.substring(to: ar.location) == new.substring(to: br.location),
              old.substring(from: NSMaxRange(ar)) == new.substring(from: NSMaxRange(br)) else { return nil }
        let result = HelloSpellingCorrection(heard: old.substring(with: ar), spelling: new.substring(with: br))
        return isValid(result) ? result : nil
    }

    /// Literal whole-word/phrase replacements in one pass; no cascades or model.
    static func apply(_ entries: [HelloSpellingCorrection], to text: String) -> String {
        let valid = entries.filter(isValid).sorted { $0.heard.utf16.count > $1.heard.utf16.count }
        guard !valid.isEmpty else { return text }
        let alternatives = valid.map { NSRegularExpression.escapedPattern(for: $0.heard) }.joined(separator: "|")
        let regex = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{M}\\p{N}_])(?:" + alternatives + ")(?![\\p{L}\\p{M}\\p{N}_])", options: .caseInsensitive)
        let original = text as NSString
        let result = NSMutableString(string: text)
        for match in regex.matches(in: text, range: NSRange(location: 0, length: original.length)).reversed() {
            let heard = original.substring(with: match.range)
            if let entry = valid.first(where: { $0.heard.caseInsensitiveCompare(heard) == .orderedSame }) {
                result.replaceCharacters(in: match.range, with: entry.spelling)
            }
        }
        return result as String
    }
}

@MainActor
final class HelloSpellingMemory: ObservableObject {
    @Published private(set) var entries: [HelloSpellingCorrection] = []
    @Published private(set) var message = ""
    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hello", isDirectory: true).appendingPathComponent("spellings.json")
        guard FileManager.default.fileExists(atPath: self.url.path) else { return }
        do {
            let size = try self.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 100_000 else { throw CocoaError(.fileReadCorruptFile) }
            let loaded = try JSONDecoder().decode([HelloSpellingCorrection].self, from: Data(contentsOf: self.url))
            guard loaded.count <= 100, loaded.allSatisfy(HelloSpellingPolicy.isValid),
                  Set(loaded.map(\.id)).count == loaded.count else { throw CocoaError(.fileReadCorruptFile) }
            entries = loaded
        } catch { message = "Saved spellings could not be read. You can clear them and start again." }
    }

    @discardableResult func remember(_ correction: HelloSpellingCorrection) -> Bool {
        guard HelloSpellingPolicy.isValid(correction) else { return false }
        var updated = entries.filter { $0.id != correction.id }
        guard updated.count < 100 else { message = "Remove a saved spelling before adding another (limit 100)."; return false }
        updated.append(correction)
        return save(updated)
    }

    func remove(_ correction: HelloSpellingCorrection) { _ = save(entries.filter { $0.id != correction.id }) }
    func clear() {
        do {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            entries = []; message = "Saved spellings cleared."
        } catch { message = "Could not clear saved spellings." }
    }

    private func save(_ updated: [HelloSpellingCorrection]) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(updated)
            // Write through a restricted temporary file so the dictionary is
            // never briefly created with broader permissions.
            let temporary = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard FileManager.default.createFile(atPath: temporary.path, contents: data,
                                                 attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
            } else { try FileManager.default.moveItem(at: temporary, to: url) }
            entries = updated; message = "Spelling saved on this Mac."
            return true
        } catch { message = "Could not save this spelling. No change was made."; return false }
    }
}

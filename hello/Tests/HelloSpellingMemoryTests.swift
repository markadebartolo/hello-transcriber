import Foundation

@main
struct HelloSpellingMemoryTests {
    @MainActor static func main() throws {
        func suggestion(_ a: String, _ b: String, _ expected: HelloSpellingCorrection?) {
            precondition(HelloSpellingPolicy.suggestion(inserted: a, corrected: b) == expected, "Unexpected suggestion for test fixture: \(a) → \(b)")
        }
        let name = HelloSpellingCorrection(heard: "Maya", spelling: "Maia")
        suggestion("Hello Maya, welcome.", "Hello Maia, welcome.", name)
        suggestion("Hello Maya 😊", "Hello Maia 😊", name)
        suggestion("Meet De Bartolo today", "Meet DeBartolo today", .init(heard: "De Bartolo", spelling: "DeBartolo"))
        suggestion("Meet José today", "Meet José today", nil) // Canonically equivalent, not a spelling change.
        suggestion("Meet Jose today", "Meet José today", .init(heard: "Jose", spelling: "José"))
        suggestion("Hello Mark", "Hello mark", .init(heard: "Mark", spelling: "mark"))
        for pair in [("pay 15 dollars", "pay 50 dollars"), ("hello", ""), ("hello", "hello there"),
                     ("Hello Maya, welcome.", "Hello Maia! welcome."),
                     ("Maya owes 15", "Maia owes 50"), ("hello world", "hello world"),
                     ("one two three four", "five six seven eight")] {
            suggestion(pair.0, pair.1, nil)
        }
        precondition(!HelloSpellingPolicy.isValid(.init(heard: "abc", spelling: "123")))
        precondition(!HelloSpellingPolicy.isValid(.init(heard: "abc", spelling: "a\nb")))
        precondition(!HelloSpellingPolicy.isValid(.init(heard: "abc", spelling: String(repeating: "a", count: 81))))
        precondition(HelloSpellingPolicy.apply([name], to: "Maya MAYA mayan xMaya Maya2 _Maya 😊Maya.") == "Maia Maia mayan xMaya Maya2 _Maya 😊Maia.")
        let chain = [HelloSpellingCorrection(heard: "one", spelling: "two"), .init(heard: "two", spelling: "three")]
        precondition(HelloSpellingPolicy.apply(chain, to: "one two") == "two three", "Replacements cascaded")
        let longest = [HelloSpellingCorrection(heard: "De", spelling: "The"), .init(heard: "De Bartolo", spelling: "DeBartolo")]
        precondition(HelloSpellingPolicy.apply(longest, to: "De Bartolo and De") == "DeBartolo and The")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("spellings.json")
        let memory = HelloSpellingMemory(url: url)
        precondition(memory.entries.isEmpty && memory.remember(name))
        precondition(HelloSpellingMemory(url: url).entries == [name])
        let changed = HelloSpellingCorrection(heard: "maya", spelling: "Mayah")
        precondition(memory.remember(changed) && memory.entries == [changed])
        precondition(HelloSpellingMemory(url: url).entries == [changed])
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as! NSNumber
        precondition(permissions.intValue & 0o777 == 0o600)
        memory.remove(changed)
        precondition(memory.entries.isEmpty && HelloSpellingMemory(url: url).entries.isEmpty)
        precondition(memory.remember(name))
        memory.clear()
        precondition(memory.entries.isEmpty && !FileManager.default.fileExists(atPath: url.path))
        try Data("not valid JSON".utf8).write(to: url)
        let corrupt = HelloSpellingMemory(url: url)
        precondition(corrupt.entries.isEmpty && !corrupt.message.isEmpty)
        corrupt.clear()
        let blocker = directory.appendingPathComponent("file")
        try Data().write(to: blocker)
        let unavailable = HelloSpellingMemory(url: blocker.appendingPathComponent("spellings.json"))
        precondition(!unavailable.remember(name) && unavailable.entries.isEmpty)
        print("Hello spelling memory: scoped edit inference, Unicode, numeric rejection, one-pass replacements, persistence, removal and storage failure passed")
    }
}

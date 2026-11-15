import AppKit
import ApplicationServices

@main
struct HelloTextFieldTests {
    @MainActor static func main() async {
        func accepts(role: String? = kAXTextAreaRole, subrole: String? = nil,
                     enabled: Bool? = true, error: AXError = .success,
                     writable: Bool = true) -> Bool {
            HelloTextFieldEligibility.accepts(role: role, subrole: subrole,
                enabled: enabled, enabledError: error, selectionWritable: writable)
        }
        precondition(accepts())
        precondition(accepts(enabled: nil, error: .attributeUnsupported),
                     "A native writable text view may omit AXEnabled")
        precondition(accepts(enabled: nil, error: .noValue))
        precondition(!accepts(enabled: false))
        precondition(!accepts(enabled: nil), "Malformed successful values fail closed")
        precondition(!accepts(enabled: nil, error: .cannotComplete))
        precondition(!accepts(enabled: nil, error: .apiDisabled))
        precondition(!accepts(writable: false))
        precondition(!accepts(enabled: nil, error: .attributeUnsupported, writable: false))
        precondition(!accepts(role: kAXStaticTextRole))
        precondition(!accepts(role: nil))
        precondition(!accepts(subrole: kAXSecureTextFieldSubrole))
        precondition(!accepts(subrole: kAXSecureTextFieldSubrole, enabled: nil, error: .attributeUnsupported))
        print("Hello text-field eligibility: 13 writable, omitted, disabled, secure and failed-query cases passed")
        precondition(HelloTextFieldEligibility.writeAttribute(original: "", range: CFRange(location: 0, length: 0), valueWritable: true) == kAXValueAttribute)
        precondition(HelloTextFieldEligibility.writeAttribute(original: "", range: CFRange(location: 0, length: 0), valueWritable: false) == kAXSelectedTextAttribute)
        for original in ["existing draft", " ", "\n", "😊"] {
            precondition(HelloTextFieldEligibility.writeAttribute(original: original, range: CFRange(location: 0, length: original.utf16.count), valueWritable: true) == kAXSelectedTextAttribute,
                         "Never replace an existing field value, even when all its text is selected")
        }

        precondition(HelloPastePolicy.shouldUsePaste(for: "com.openai.chat"))
        precondition(HelloPastePolicy.shouldUsePaste(for: "com.openai.codex"))
        precondition(!HelloPastePolicy.shouldUsePaste(for: "com.apple.TextEdit"))
        precondition(HelloPastePolicy.isPlainPaste(role: kAXMenuItemRole, enabled: true, character: "V", modifiers: 0))
        for key in ["\r", "c", "x"] {
            precondition(!HelloPastePolicy.isPlainPaste(role: kAXMenuItemRole, enabled: true, character: key, modifiers: 0))
        }
        precondition(!HelloPastePolicy.isPlainPaste(role: kAXMenuItemRole, enabled: true, character: "V", modifiers: 1))
        precondition(!HelloPastePolicy.isPlainPaste(role: kAXMenuItemRole, enabled: false, character: "V", modifiers: 0))

        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let original = NSPasteboardItem()
        precondition(original.setString("original", forType: .string))
        let extraType = NSPasteboard.PasteboardType("com.markdebartolo.hello.test")
        precondition(original.setData(Data([1, 2, 3]), forType: extraType))
        precondition(board.writeObjects([original]))
        let snapshot = HelloClipboardSnapshot(board)!
        board.clearContents()
        precondition(board.setString("dictation", forType: .string))
        snapshot.restore(board, ifUnchangedSince: board.changeCount)
        precondition(board.string(forType: .string) == "original")
        precondition(board.data(forType: extraType) == Data([1, 2, 3]))
        let countBeforeNewCopy = board.changeCount
        board.clearContents()
        precondition(board.setString("new user copy", forType: .string))
        snapshot.restore(board, ifUnchangedSince: countBeforeNewCopy)
        precondition(board.string(forType: .string) == "new user copy")
        print("Hello Paste routing, command selection, clipboard format restoration and concurrent copy tests passed")

        func append(_ text: String, to draft: String) -> String {
            draft + HelloDraftPunctuation.appendChunk(text, to: draft,
                selection: CFRange(location: draft.utf16.count, length: 0))
        }
        var draft = append("Hey there", to: "")
        draft = append("Something about this is wrong", to: draft)
        draft = append("Do you see what I mean", to: draft)
        precondition(draft == "Hey there. Something about this is wrong. Do you see what I mean?")
        precondition(append("Ready to go!", to: "Good morning") == "Good morning. Ready to go!")
        precondition(append("that you’re ready", to: "I hope") == "I hope that you’re ready.")
        precondition(append("Here we go!", to: "Earlier text\n") == "Earlier text\nHere we go!")
        precondition(append("Next sentence", to: "Already punctuated?") == "Already punctuated? Next sentence.")
        precondition(append("thank you", to: "For your help,") == "For your help, thank you.")
        precondition(append("Visit example.com", to: "") == "Visit example.com")
        precondition(HelloDraftPunctuation.appendChunk("keep unchanged", to: "Existing selection",
            selection: CFRange(location: 9, length: 9)) == "keep unchanged")
        precondition(HelloDraftPunctuation.appendChunk("in the middle", to: "Existing draft",
            selection: CFRange(location: 8, length: 0)) == "in the middle")
        print("Hello draft punctuation: successive dictation, questions, existing punctuation and selection tests passed")

        var reads = 0
        var pauses = 0
        var outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            reads += 1
            return reads < 3 ? "original" : "inserted"
        }, isCurrent: { true }, pause: { pauses += 1 })
        precondition(outcome == .verified && reads == 3 && pauses == 2,
                     "Delayed accessibility readback must verify without issuing another write")
        reads = 0
        outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            reads += 1; return "inserted"
        }, isCurrent: { true }, pause: { preconditionFailure("Immediate success must not wait") })
        precondition(outcome == .verified && reads == 1)
        reads = 0
        outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            reads += 1; return nil
        }, isCurrent: { true }, pause: {})
        precondition(outcome == .unverified && reads == 10, "An unreadable field must time out")
        var current = true
        reads = 0
        outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            reads += 1; return "original"
        }, isCurrent: { current }, pause: { current = false })
        precondition(outcome == .interrupted && reads == 1, "Stop polling on focus or context changes")
        reads = 0
        outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            reads += 1; return "different text"
        }, isCurrent: { true }, pause: { throw CancellationError() })
        precondition(outcome == .interrupted && reads == 1)
        current = true
        outcome = await HelloInsertionVerification.waitForValue("inserted", read: {
            current = false; return "inserted"
        }, isCurrent: { current }, pause: {})
        precondition(outcome == .interrupted, "A matching value cannot override a changed context")
        print("Hello insertion verification: immediate/delayed readback, timeout, focus change and cancellation passed")
    }
}

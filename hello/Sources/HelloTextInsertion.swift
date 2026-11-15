import AppKit
import ApplicationServices
import Carbon

/// Some native text views omit AXEnabled. A writable selection is the required
/// capability; an explicit disabled flag or a failed AX request still rejects it.
enum HelloTextFieldEligibility {
    static func writeAttribute(original: String, range: CFRange, valueWritable: Bool) -> String {
        // Empty rich-text editors can expose AXSelectedText but ignore writes to
        // it. Setting AXValue is safe only when there is no existing text to lose.
        original.isEmpty && range.location == 0 && range.length == 0 && valueWritable
            ? kAXValueAttribute : kAXSelectedTextAttribute
    }

    static func accepts(role: String?, subrole: String?, enabled: Bool?,
                        enabledError: AXError, selectionWritable: Bool) -> Bool {
        guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? ""),
              subrole != kAXSecureTextFieldSubrole, selectionWritable else { return false }
        if enabledError == .success { return enabled == true }
        return enabledError == .attributeUnsupported || enabledError == .noValue
    }
}

/// Adjusts only the text being appended. Never rewrites an existing draft,
/// changes a recognized word, or formats an insertion in the middle of text.
enum HelloDraftPunctuation {
    static func appendChunk(_ text: String, to draft: String, selection: CFRange) -> String {
        guard selection.length == 0, selection.location == draft.utf16.count,
              let first = text.first, !first.isWhitespace else { return text }

        var prefix = ""
        if let last = draft.last, !last.isWhitespace,
           !".,;:!?…。！？、，；：)]}”’".contains(first),
           !"([{“".contains(last) {
            let newerSentence = first.isUppercase && canFinish(draft)
            prefix = newerSentence ? (isQuestion(draft) ? "? " : ". ") : " "
        }

        let suffix = canFinish(text) ? (isQuestion(text) ? "?" : ".") : ""
        return prefix + text + suffix
    }

    private static func canFinish(_ text: String) -> Bool {
        // Preserve existing punctuation, closing quotes and explicitly supplied
        // whitespace. Avoid adding a period to a lone word, URL or address.
        guard let last = text.last, last.isLetter || last.isNumber,
              let line = text.split(whereSeparator: \.isNewline).last else { return false }
        let words = line.split(whereSeparator: \.isWhitespace)
        guard words.count > 1, let tail = words.last else { return false }
        return !tail.contains("://") && !tail.contains("@") && !tail.contains(".")
    }

    private static func isQuestion(_ text: String) -> Bool {
        let line = text.split(whereSeparator: \.isNewline).last ?? ""
        let sentence = line.split(whereSeparator: { ".!?".contains($0) }).last ?? line
        let words = sentence.lowercased().split(whereSeparator: \.isWhitespace)
        let auxiliaries: Set<Substring> = ["am", "are", "is", "was", "were", "do", "does", "did",
            "can", "could", "will", "would", "should", "have", "has", "may"]
        let pronouns: Set<Substring> = ["i", "you", "he", "she", "it", "we", "they", "there", "this", "that"]
        let interrogatives: Set<Substring> = ["what", "when", "where", "why", "who", "how", "which"]
        guard words.count >= 3 else { return false }
        return (auxiliaries.contains(words[0]) && pronouns.contains(words[1]))
            || (interrogatives.contains(words[0]) && auxiliaries.contains(words[1]))
    }
}

enum HelloPastePolicy {
    static func shouldUsePaste(for bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.openai.chat" || bundleIdentifier == "com.openai.codex"
    }

    static func isPlainPaste(role: String?, enabled: Bool?, character: String?, modifiers: Int?) -> Bool {
        // Accessibility encodes Command as the default in a zero modifier mask.
        role == kAXMenuItemRole && enabled == true &&
            character?.lowercased() == "v" && modifiers == 0
    }
}

@MainActor
struct HelloClipboardSnapshot {
    let changeCount: Int
    let items: [NSPasteboardItem]

    init?(_ pasteboard: NSPasteboard) {
        changeCount = pasteboard.changeCount
        let originals = pasteboard.pasteboardItems ?? []
        guard originals.count <= 32, !originals.isEmpty || pasteboard.types?.isEmpty != false else { return nil }
        var copies: [NSPasteboardItem] = []
        var bytes = 0
        for original in originals {
            guard !original.types.isEmpty else { return nil }
            let copy = NSPasteboardItem()
            for type in original.types {
                guard !type.rawValue.lowercased().contains("filepromise"),
                      !type.rawValue.lowercased().contains("promised-file"),
                      let data = original.data(forType: type), data.count <= 16_000_000 - bytes,
                      copy.setData(data, forType: type) else { return nil }
                bytes += data.count
            }
            copies.append(copy)
        }
        guard pasteboard.changeCount == changeCount else { return nil }
        items = copies
    }

    func restore(_ pasteboard: NSPasteboard, ifUnchangedSince count: Int) {
        guard pasteboard.changeCount == count else { return }
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}

/// AX setters may return before an application's accessibility value refreshes.
/// Poll only the readback: retrying the write could insert the text twice.
@MainActor
enum HelloInsertionVerification {
    enum Outcome { case verified, unverified, interrupted }

    static func waitForValue(_ expected: String, read: () -> String?, isCurrent: () -> Bool,
                             pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(50)) }) async -> Outcome {
        let deadline = ContinuousClock.now + .milliseconds(500)
        for attempt in 0..<10 {
            guard !Task.isCancelled, isCurrent() else { return .interrupted }
            if read() == expected {
                return !Task.isCancelled && isCurrent() ? .verified : .interrupted
            }
            guard attempt < 9, ContinuousClock.now < deadline else { return .unverified }
            do { try await pause() }
            catch { return .interrupted }
        }
        return .unverified
    }
}

/// Captures a destination before recording. A focus or selection change invalidates it.
@MainActor
struct HelloTextDestination {
    let applicationIdentifier: pid_t
    let applicationName: String
    private let usesPaste: Bool
    private let element: AXUIElement
    private let selectedRange: CFRange
    private let originalValue: String

    enum InsertionFailure: Error, LocalizedError {
        case accessibility, secure, noField, unsupported, selectionUnavailable, differentApp, changed, notWritable, writeFailed, unverified, clipboardUnavailable
        var errorDescription: String? {
            switch self {
            case .accessibility: return "Allow Hello in Accessibility to insert text."
            case .secure: return "Secure fields and Secure Input cannot receive dictation."
            case .noField: return "No text field had keyboard focus. Click inside the field before holding Control + Option."
            case .unsupported: return "The focused control is not a supported editable text field."
            case .selectionUnavailable: return "This field does not expose a verifiable text selection."
            case .differentApp: return "The original app or focused field could not be verified."
            case .changed: return "The field, selection, or app changed before insertion."
            case .notWritable: return "This field does not allow its selected text to be replaced."
            case .writeFailed: return "The app did not accept text insertion."
            case .clipboardUnavailable: return "Hello couldn’t preserve the clipboard for this paste. Your transcript is available to copy."
            case .unverified: return "The app accepted the insertion request, but Hello could not verify the resulting text. Check the field before pasting."
            }
        }
    }

    static func capture() throws -> HelloTextDestination {
        guard AXIsProcessTrusted() else { throw InsertionFailure.accessibility }
        guard !IsSecureEventInputEnabled() else { throw InsertionFailure.secure }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let element = focusedElement() else { throw InsertionFailure.noField }
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard attribute(kAXSubroleAttribute, of: element) as? String != kAXSecureTextFieldSubrole else { throw InsertionFailure.secure }
        guard isEditableNonSecureElement(element) else { throw InsertionFailure.unsupported }
        guard let range = selectionRange(of: element),
              let value = attribute(kAXValueAttribute, of: element) as? String,
              range.location <= value.utf16.count,
              range.length <= value.utf16.count - range.location,
              Range(NSRange(location: range.location, length: range.length), in: value) != nil else { throw InsertionFailure.selectionUnavailable }
        var elementPID: pid_t = 0
        guard AXUIElementGetPid(element, &elementPID) == .success,
              elementPID == application.processIdentifier else { throw InsertionFailure.differentApp }
        return HelloTextDestination(
            applicationIdentifier: application.processIdentifier,
            applicationName: application.localizedName ?? "your app",
            usesPaste: HelloPastePolicy.shouldUsePaste(for: application.bundleIdentifier),
            element: element,
            selectedRange: range,
            originalValue: value
        )
    }

    func preparedInsertion(_ text: String) -> String {
        usesPaste ? HelloDraftPunctuation.appendChunk(text, to: originalValue, selection: selectedRange) : text
    }

    /// Replace the verified selection, or set a verified completely empty field.
    func insert(_ text: String, isCurrent: () -> Bool) async -> Result<Void, InsertionFailure> {
        guard !text.isEmpty else { return .failure(.writeFailed) }
        guard !Task.isCancelled, isCurrent() else { return .failure(.changed) }
        if let failure = validationFailure() { return .failure(failure) }
        if usesPaste { return await paste(text, isCurrent: isCurrent) }
        var valueSettable = DarwinBoolean(false)
        let canSetValue = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &valueSettable) == .success && valueSettable.boolValue
        let writeAttribute = HelloTextFieldEligibility.writeAttribute(original: originalValue,
            range: selectedRange, valueWritable: canSetValue)
        var isSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, writeAttribute as CFString, &isSettable) == .success,
              isSettable.boolValue else { return .failure(.notWritable) }
        // Recheck immediately before writing: querying another app can take time.
        if let failure = validationFailure() { return .failure(failure) }
        guard !Task.isCancelled, isCurrent() else { return .failure(.changed) }
        guard AXUIElementSetAttributeValue(element, writeAttribute as CFString, text as CFString) == .success else { return .failure(.writeFailed) }
        return await verifyInsertion(text, isCurrent: isCurrent)
    }

    private func paste(_ text: String, isCurrent: () -> Bool) async -> Result<Void, InsertionFailure> {
        guard let command = pasteMenuItem() else { return .failure(.notWritable) }
        let pasteboard = NSPasteboard.general
        guard let snapshot = HelloClipboardSnapshot(pasteboard) else { return .failure(.clipboardUnavailable) }
        if let failure = validationFailure() { return .failure(failure) }
        guard !Task.isCancelled, isCurrent() else { return .failure(.changed) }
        guard pasteboard.changeCount == snapshot.changeCount else { return .failure(.clipboardUnavailable) }
        var ownedCount = pasteboard.clearContents()
        defer { snapshot.restore(pasteboard, ifUnchangedSince: ownedCount) }
        let wrote = pasteboard.setString(text, forType: .string)
        ownedCount = pasteboard.changeCount
        guard wrote else { return .failure(.writeFailed) }
        // Revalidate after staging the clipboard. The action belongs to the
        // captured app's own menu, so no synthetic keys can reach another app.
        if let failure = validationFailure() { return .failure(failure) }
        guard !Task.isCancelled, isCurrent() else { return .failure(.changed) }
        guard pasteboard.changeCount == ownedCount, pasteboard.string(forType: .string) == text else {
            return .failure(.clipboardUnavailable)
        }
        let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
        // A timeout does not prove the target failed to paste. Never retry it.
        guard result == .success || result == .cannotComplete else { return .failure(.writeFailed) }
        return await verifyInsertion(text, isCurrent: isCurrent)
    }

    private func pasteMenuItem() -> AXUIElement? {
        let app = AXUIElementCreateApplication(applicationIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard let bar = Self.attribute(kAXMenuBarAttribute, of: app), CFGetTypeID(bar) == AXUIElementGetTypeID(),
              let top = Self.attribute(kAXChildrenAttribute, of: bar as! AXUIElement) as? [AXUIElement] else { return nil }
        let deadline = ContinuousClock.now + .milliseconds(750)
        var candidates: [AXUIElement] = []
        for group in top.prefix(24) {
            guard let menus = Self.attribute(kAXChildrenAttribute, of: group) as? [AXUIElement] else { continue }
            for menu in menus.prefix(4) {
                guard let items = Self.attribute(kAXChildrenAttribute, of: menu) as? [AXUIElement] else { continue }
                for item in items.prefix(100) {
                    guard ContinuousClock.now < deadline else { return nil }
                    guard let key = Self.attribute(kAXMenuItemCmdCharAttribute, of: item) as? String,
                          key.lowercased() == "v" else { continue }
                    if HelloPastePolicy.isPlainPaste(
                        role: Self.attribute(kAXRoleAttribute, of: item) as? String,
                        enabled: Self.attribute(kAXEnabledAttribute, of: item) as? Bool,
                        character: key,
                        modifiers: Self.attribute(kAXMenuItemCmdModifiersAttribute, of: item) as? Int
                    ) {
                        candidates.append(item)
                    }
                }
            }
        }
        guard candidates.count == 1 else { return nil }
        return candidates.first
    }

    private func verifyInsertion(_ text: String, isCurrent: () -> Bool) async -> Result<Void, InsertionFailure> {
        let expected = (originalValue as NSString).replacingCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length), with: text)
        let verification = await HelloInsertionVerification.waitForValue(expected,
            read: { Self.attribute(kAXValueAttribute, of: element) as? String },
            isCurrent: { isCurrent() && hasOriginalFocus() })
        return verification == .verified ? .success(()) : .failure(.unverified)
    }

    private func hasOriginalFocus() -> Bool {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == applicationIdentifier,
              let current = Self.focusedElement(), CFEqual(element, current),
              Self.isEditableNonSecureElement(current) else { return false }
        return true
    }

    private func validationFailure() -> InsertionFailure? {
        guard AXIsProcessTrusted() else { return .accessibility }
        guard !IsSecureEventInputEnabled() else { return .secure }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == applicationIdentifier,
              let currentElement = Self.focusedElement(), CFEqual(element, currentElement) else { return .changed }
        guard Self.isEditableNonSecureElement(currentElement) else { return .unsupported }
        guard let currentRange = Self.selectionRange(of: currentElement),
              currentRange.location == selectedRange.location,
              currentRange.length == selectedRange.length,
              Self.attribute(kAXValueAttribute, of: currentElement) as? String == originalValue else { return .changed }
        return nil
    }

    /// A short-lived read-only watch, created only after verified insertion.
    func correctionWatch(afterInserting text: String) -> CorrectionWatch? {
        guard text.utf16.count <= 4_000, originalValue.utf16.count <= 32_000,
              let range = Range(NSRange(location: selectedRange.location, length: selectedRange.length), in: originalValue) else { return nil }
        let watch = CorrectionWatch(destination: self, inserted: text,
                                    prefix: String(originalValue[..<range.lowerBound]),
                                    suffix: String(originalValue[range.upperBound...]))
        guard watch.currentInsertedText() == text else { return nil }
        return watch
    }

    @MainActor struct CorrectionWatch {
        private let destination: HelloTextDestination
        let inserted: String
        private let prefix: String
        private let suffix: String

        fileprivate init(destination: HelloTextDestination, inserted: String, prefix: String, suffix: String) {
            self.destination = destination; self.inserted = inserted; self.prefix = prefix; self.suffix = suffix
        }

        func currentInsertedText() -> String? {
            guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.applicationIdentifier,
                  let focused = HelloTextDestination.focusedElement(), CFEqual(focused, destination.element),
                  HelloTextDestination.isEditableNonSecureElement(focused),
                  let value = HelloTextDestination.attribute(kAXValueAttribute, of: focused) as? String,
                  value.utf16.count <= 32_000, value.hasPrefix(prefix), value.hasSuffix(suffix),
                  value.utf16.count >= prefix.utf16.count + suffix.utf16.count else { return nil }
            let ns = value as NSString
            let length = ns.length - prefix.utf16.count - suffix.utf16.count
            guard length <= 4_000,
                  let range = Range(NSRange(location: prefix.utf16.count, length: length), in: value) else { return nil }
            return String(value[range])
        }
    }

    private static func selectionRange(of element: AXUIElement) -> CFRange? {
        guard let value = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return nil }
        return range
    }

    private static func focusedElement() -> AXUIElement? {
        guard let value = attribute(kAXFocusedUIElementAttribute, of: AXUIElementCreateSystemWide()),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func isEditableNonSecureElement(_ element: AXUIElement) -> Bool {
        let role = attribute(kAXRoleAttribute, of: element) as? String
        let subrole = attribute(kAXSubroleAttribute, of: element) as? String
        var enabledValue: CFTypeRef?
        let enabledError = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue)
        var writable = DarwinBoolean(false)
        let writableError = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &writable)
        return HelloTextFieldEligibility.accepts(role: role, subrole: subrole,
            enabled: enabledValue as? Bool, enabledError: enabledError,
            selectionWritable: writableError == .success && writable.boolValue)
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

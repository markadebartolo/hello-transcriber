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
    private let element: AXUIElement
    private let selectedRange: CFRange
    private let originalValue: String

    enum InsertionFailure: Error, LocalizedError {
        case accessibility, secure, noField, unsupported, selectionUnavailable, differentApp, changed, notWritable, writeFailed, unverified
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
            element: element,
            selectedRange: range,
            originalValue: value
        )
    }

    /// Replace the verified selection, or set a verified completely empty field.
    func insert(_ text: String, isCurrent: () -> Bool) async -> Result<Void, InsertionFailure> {
        guard !text.isEmpty else { return .failure(.writeFailed) }
        guard !Task.isCancelled, isCurrent() else { return .failure(.changed) }
        if let failure = validationFailure() { return .failure(failure) }
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

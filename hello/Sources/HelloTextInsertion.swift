import AppKit
import ApplicationServices
import Carbon

/// Captures a destination before recording. A focus or selection change invalidates it.
@MainActor
struct HelloTextDestination {
    let applicationIdentifier: pid_t
    let applicationName: String
    private let element: AXUIElement
    private let selectedRange: CFRange
    private let originalValue: String

    static func capture() -> HelloTextDestination? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let element = focusedElement(), isEditableNonSecureElement(element),
              let range = selectionRange(of: element),
              let value = attribute(kAXValueAttribute, of: element) as? String,
              range.location <= value.utf16.count,
              range.length <= value.utf16.count - range.location else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.25)
        var elementPID: pid_t = 0
        guard AXUIElementGetPid(element, &elementPID) == .success,
              elementPID == application.processIdentifier else { return nil }
        return HelloTextDestination(
            applicationIdentifier: application.processIdentifier,
            applicationName: application.localizedName ?? "your app",
            element: element,
            selectedRange: range,
            originalValue: value
        )
    }

    /// AX replaces only the current selection. Apps without a writable selection keep
    /// the transcript in Hello for explicit copy/paste; never overwrite AXValue wholesale.
    func insert(_ text: String) -> Bool {
        guard !text.isEmpty, AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == applicationIdentifier,
              let currentElement = Self.focusedElement(), CFEqual(element, currentElement),
              Self.isEditableNonSecureElement(currentElement) else { return false }
        guard let currentRange = Self.selectionRange(of: currentElement),
              currentRange.location == selectedRange.location,
              currentRange.length == selectedRange.length,
              Self.attribute(kAXValueAttribute, of: currentElement) as? String == originalValue else { return false }
        var isSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable) == .success,
              isSettable.boolValue,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == applicationIdentifier,
              !IsSecureEventInputEnabled() else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
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
        guard attribute(kAXEnabledAttribute, of: element) as? Bool == true,
              subrole != kAXSecureTextFieldSubrole else { return false }
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? "")
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

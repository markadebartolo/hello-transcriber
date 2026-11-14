import AppKit
import ApplicationServices
import Carbon

/// Captures a destination before recording. A focus or selection change invalidates it.
@MainActor
struct HelloTextDestination {
    let applicationIdentifier: pid_t
    let applicationName: String
    private let element: AXUIElement
    private let selectedRange: CFTypeRef?

    static func capture() -> HelloTextDestination? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let element = focusedElement(), isEditableNonSecureElement(element) else { return nil }
        return HelloTextDestination(
            applicationIdentifier: application.processIdentifier,
            applicationName: application.localizedName ?? "your app",
            element: element,
            selectedRange: attribute(kAXSelectedTextRangeAttribute, of: element)
        )
    }

    /// AX replaces only the current selection. Apps without a writable selection keep
    /// the transcript in Hello for explicit copy/paste; never overwrite AXValue wholesale.
    func insert(_ text: String) -> Bool {
        guard !text.isEmpty, AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == applicationIdentifier,
              let currentElement = Self.focusedElement(), CFEqual(element, currentElement),
              Self.isEditableNonSecureElement(currentElement) else { return false }
        if let selectedRange {
            guard let currentRange = Self.attribute(kAXSelectedTextRangeAttribute, of: currentElement),
                  CFEqual(selectedRange, currentRange) else { return false }
        }
        var isSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable) == .success,
              isSettable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }

    private static func focusedElement() -> AXUIElement? {
        guard let value = attribute(kAXFocusedUIElementAttribute, of: AXUIElementCreateSystemWide()),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func isEditableNonSecureElement(_ element: AXUIElement) -> Bool {
        let role = attribute(kAXRoleAttribute, of: element) as? String
        let subrole = attribute(kAXSubroleAttribute, of: element) as? String
        guard subrole != kAXSecureTextFieldSubrole else { return false }
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? "")
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

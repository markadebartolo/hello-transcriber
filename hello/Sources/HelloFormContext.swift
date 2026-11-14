import AppKit
@preconcurrency import ApplicationServices
import Carbon
// Xcode 16 lacks Sendable annotations for the shareable-content snapshot.
// Received objects are read only, confined to this main-actor context.
@preconcurrency import ScreenCaptureKit

/// Snapshot of a single foreground window. Never clicks screen coordinates or
/// changes focus to infer an editable destination. Unknown/secure controls fail closed.
@MainActor
final class HelloFormContext {
    private struct Entry {
        let element: AXUIElement
        let role: String
        let label: String
        let value: String?
        let frame: CGRect?
    }
    private let pid: pid_t
    private let window: AXUIElement
    private let frame: CGRect
    private let title: String
    private let entries: [Entry]
    private let targets: [String: AXUIElement]
    let fields: [HelloFormField]

    private init(pid: pid_t, window: AXUIElement, frame: CGRect, title: String,
                 entries: [Entry], targets: [String: AXUIElement], fields: [HelloFormField]) {
        self.pid = pid; self.window = window; self.frame = frame; self.title = title
        self.entries = entries; self.targets = targets; self.fields = fields
    }

    static func capture() throws -> HelloFormContext {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let window = elementAttribute(kAXFocusedWindowAttribute, of: AXUIElementCreateApplication(app.processIdentifier)),
              let frame = rect(window) else { throw failure("Open a supported form in another app first.") }
        AXUIElementSetMessagingTimeout(window, 0.1)
        let entries = try scan(window)
        var fields: [HelloFormField] = []
        var targets: [String: AXUIElement] = [:]
        for entry in entries {
            guard [kAXTextFieldRole, kAXTextAreaRole].contains(entry.role), entry.value == "",
                  attribute(kAXEnabledAttribute, of: entry.element) as? Bool == true,
                  let bounds = entry.frame, frame.contains(bounds), bounds.width > 4, bounds.height > 4,
                  !sensitive(entry.label), isVisible(entry.element, frame: bounds), settable(kAXValueAttribute, on: entry.element) else { continue }
            let id = "field-\(fields.count + 1)"
            targets[id] = entry.element
            fields.append(HelloFormField(id: id, label: String(entry.label.prefix(300)),
                bounds: [bounds.minX - frame.minX, bounds.minY - frame.minY, bounds.width, bounds.height]))
        }
        guard !fields.isEmpty, fields.count <= 30 else { throw failure("No supported empty fields, or too many fields. Use Copy.") }
        return HelloFormContext(pid: app.processIdentifier, window: window, frame: frame,
                                title: attribute(kAXTitleAttribute, of: window) as? String ?? "",
                                entries: entries, targets: targets, fields: fields)
    }

    func screenshot() async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else { throw Self.failure("Enable Screen Recording in Hello before using form filling.") }
        guard isCurrent() else { throw Self.failure("The form changed. Use Copy or dictate again.") }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        try Task.checkCancellation()
        let matches = content.windows.filter {
            $0.owningApplication?.processID == pid && $0.windowLayer == 0 &&
            abs($0.frame.minX - frame.minX) < 2 && abs($0.frame.minY - frame.minY) < 2 &&
            abs($0.frame.width - frame.width) < 2 && abs($0.frame.height - frame.height) < 2 &&
            (title.isEmpty || $0.title == title)
        }
        guard matches.count == 1, isCurrent() else { throw Self.failure("The original window could not be verified. Use Copy.") }
        let filter = SCContentFilter(desktopIndependentWindow: matches[0])
        let configuration = SCStreamConfiguration()
        let scale = min(2.0, 1600 / max(frame.width, frame.height))
        configuration.width = max(1, Int(frame.width * scale))
        configuration.height = max(1, Int(frame.height * scale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.includeChildWindows = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        try Task.checkCancellation()
        guard isCurrent(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw Self.failure("The form changed during capture. Use Copy.")
        }
        return data
    }

    /// Preflight the whole batch, then recheck before each write. AX writes are not
    /// atomic across apps: report partial completion instead of attempting rollback.
    func apply(_ assignments: [HelloFormAssignment]) -> (filled: Int, complete: Bool) {
        guard !assignments.isEmpty, Set(assignments.map(\.fieldID)).count == assignments.count,
              assignments.allSatisfy({ targets[$0.fieldID] != nil }), isCurrent() else { return (0, false) }
        return HelloFormWriter.apply(assignments, validate: { self.isCurrent(written: $0) }, write: { assignment in
            guard !Task.isCancelled, let target = self.targets[assignment.fieldID],
                  Self.attribute(kAXValueAttribute, of: target) as? String == "",
                  Self.settable(kAXValueAttribute, on: target),
                  Self.attribute(kAXEnabledAttribute, of: target) as? Bool == true,
                  let bounds = Self.rect(target), Self.isVisible(target, frame: bounds), !IsSecureEventInputEnabled(),
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == self.pid else { return false }
            let status = AXUIElementSetAttributeValue(target, kAXValueAttribute as CFString, assignment.text as CFString)
            return status == .success && Self.attribute(kAXValueAttribute, of: target) as? String == assignment.text
        })
    }

    func isCurrent(written: [String: String] = [:]) -> Bool {
        guard !Task.isCancelled, AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let currentWindow = Self.elementAttribute(kAXFocusedWindowAttribute, of: AXUIElementCreateApplication(pid)),
              CFEqual(window, currentWindow), Self.rect(window) == frame,
              Self.attribute(kAXTitleAttribute, of: window) as? String ?? "" == title,
              let current = try? Self.scan(window), current.count == entries.count else { return false }
        for (original, now) in zip(entries, current) {
            let changedID = targets.first { CFEqual($0.value, original.element) }?.key
            let expected = changedID.flatMap { written[$0] } ?? original.value
            guard CFEqual(original.element, now.element), original.role == now.role,
                  original.label == now.label, original.frame == now.frame, expected == now.value else { return false }
        }
        return true
    }

    private static func scan(_ window: AXUIElement) throws -> [Entry] {
        let deadline = Date().addingTimeInterval(2)
        var queue = [window]
        var visited: [AXUIElement] = []
        var entries: [Entry] = []
        while let element = queue.popLast() {
            guard Date() < deadline, visited.count < 1500 else { throw failure("This page cannot be inspected reliably. Use Copy.") }
            if visited.contains(where: { CFEqual($0, element) }) { continue }
            visited.append(element)
            AXUIElementSetMessagingTimeout(element, 0.1)
            guard let role = attribute(kAXRoleAttribute, of: element) as? String else { throw failure("An inaccessible control prevents form verification. Use Copy.") }
            let subrole = attribute(kAXSubroleAttribute, of: element) as? String ?? ""
            // Refuse the entire capture when a password control is present. Its
            // contents are never read, included in field metadata or screenshotted.
            guard subrole != kAXSecureTextFieldSubrole, !subrole.localizedCaseInsensitiveContains("secure") else {
                throw failure("This window contains a secure field. Form capture is disabled; use normal dictation elsewhere.")
            }
            let label = [kAXTitleAttribute, kAXDescriptionAttribute, "AXPlaceholderValue"].compactMap {
                attribute($0, of: element) as? String
            }.filter { !$0.isEmpty }.joined(separator: " · ")
            var combinedLabel = label
            if let titleElement = elementAttribute(kAXTitleUIElementAttribute, of: element),
               let title = attribute(kAXValueAttribute, of: titleElement) as? String {
                combinedLabel += " " + title
            }
            let value = attribute(kAXValueAttribute, of: element) as? String
            entries.append(Entry(element: element, role: role, label: combinedLabel, value: value, frame: rect(element)))
            var children: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            guard result == .success || result == .attributeUnsupported || result == .noValue else {
                throw failure("This page stopped responding. Use Copy.")
            }
            if let children = children as? [AXUIElement] { queue.append(contentsOf: children.reversed()) }
        }
        return entries
    }

    private static func isVisible(_ element: AXUIElement, frame: CGRect) -> Bool {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(frame.midX), Float(frame.midY), &hit) == .success else { return false }
        // A text area can expose a text child at the hit point. Only accept that
        // exact field or a bounded parent chain; never infer visibility by bounds alone.
        for _ in 0..<8 {
            guard let current = hit else { return false }
            if CFEqual(current, element) { return true }
            hit = elementAttribute(kAXParentAttribute, of: current)
        }
        return false
    }

    private static func sensitive(_ label: String) -> Bool {
        ["password", "passcode", "verification code", "security code", "credit card", "card number", "cvv", "cvc",
         "social security", "routing number", "account number", "one-time", "otp"].contains { label.localizedCaseInsensitiveContains($0) }
    }
    private static func failure(_ message: String) -> HelloFormError { .unavailable(message) }
    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private static func elementAttribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(name, of: element), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func settable(_ name: String, on element: AXUIElement) -> Bool {
        var value = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, name as CFString, &value) == .success && value.boolValue
    }
    private static func rect(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(kAXPositionAttribute, of: element), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(kAXSizeAttribute, of: element), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let p = position as! AXValue, s = size as! AXValue
        guard AXValueGetType(p) == .cgPoint, AXValueGetType(s) == .cgSize else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        guard AXValueGetValue(p, .cgPoint, &origin), AXValueGetValue(s, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }
}

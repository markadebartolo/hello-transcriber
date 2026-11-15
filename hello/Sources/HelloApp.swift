import AppKit
import Charts
import SwiftUI
import Sparkle

@main
struct HelloApp: App {
    @NSApplicationDelegateAdaptor(HelloAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            HelloMenuPanel(controller: appDelegate.controller, openDashboard: appDelegate.showDashboard, updates: appDelegate.updates)
        } label: {
            HelloMenuBarLabel(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct HelloMenuPanel: View {
    @ObservedObject var controller: HelloController
    let openDashboard: () -> Void
    @ObservedObject var updates: HelloUpdates

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hello", systemImage: "waveform").font(.headline)
            Text(controller.statusText).font(.callout).foregroundStyle(.secondary)
            if !controller.transcript.isEmpty && !controller.isBusy {
                Text(controller.transcript).lineLimit(3)
                Button("Copy transcript") { controller.copyTranscript() }
            }
            Divider()
            Button("Open Dashboard", action: openDashboard)
            Button("Check for Updates…", action: updates.check)
                .disabled(!updates.canCheck || controller.isBusy)
            Button("Quit Hello", action: controller.quit)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .buttonStyle(HelloButtonStyle())
    }
}

private struct HelloMenuBarLabel: View {
    @ObservedObject var controller: HelloController
    var body: some View {
        Image("HelloWaveform")
            .accessibilityLabel(controller.dictation.isActivelyRecordingAudio ? "Hello · Listening" : "Hello")
            .opacity(controller.isBusy ? 0.65 : 1)
    }
}

@MainActor
final class HelloUpdates: ObservableObject {
    private let updater = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    @Published private(set) var canCheck = false
    @Published var automaticChecks = false {
        didSet {
            if updater.updater.automaticallyChecksForUpdates != automaticChecks {
                updater.updater.automaticallyChecksForUpdates = automaticChecks
            }
        }
    }

    func start() {
        updater.startUpdater()
        updater.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheck)
        automaticChecks = updater.updater.automaticallyChecksForUpdates
    }

    func check() {
        guard canCheck else { return }
        updater.checkForUpdates(nil)
    }

}

@MainActor
final class HelloAppDelegate: NSObject, NSApplicationDelegate {
    let controller = HelloController()
    let updates = HelloUpdates()
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updates.start()
        showDashboard()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.cancel()
        controller.shortcutMonitor.stop()
    }

    func showDashboard() {
        if dashboardWindow == nil {
            let availableHeight = NSScreen.main?.visibleFrame.height ?? 900
            let height = min(780, max(400, availableHeight - 100))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: height),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Hello Dashboard"
            window.minSize = NSSize(width: 700, height: 420)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView:
                HelloPanel(controller: controller, updates: updates))
            window.center()
            dashboardWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }
}

private struct HelloPanel: View {
    @ObservedObject var controller: HelloController
    @State private var apiKey = ""
    @ObservedObject var updates: HelloUpdates
    @State private var section = Section.overview

    private enum Section: String, CaseIterable {
        case overview = "Overview"
        case dictation = "Dictation"
        case spellings = "Personal Spellings"
        case forms = "Form Filling"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("hello").font(.system(size: 30, weight: .semibold, design: .rounded))
                    Spacer()
                    Image("HelloWaveform").resizable().scaledToFit()
                        .frame(width: 48, height: 32).foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }
                Picker("Dashboard section", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch section {
                    case .overview: overview
                    case .dictation: dictationSettings
                    case .spellings: spellingSettings
                    case .forms: formSettings
                    }
                }
                .padding(20)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .id(section)
            Divider()
            HStack(spacing: 12) {
                Text("Hello \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Automatic update checks", isOn: $updates.automaticChecks)
                    .font(.caption)
                Button("Check for Updates…", action: updates.check)
                    .disabled(!updates.canCheck || controller.isBusy)
                Button("Quit Hello", action: controller.quit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(HelloButtonStyle())
        .onAppear { controller.refreshShortcut() }
        .onChange(of: controller.formProvider) { _, _ in apiKey = "" }
        .onChange(of: section) { _, newSection in if newSection != .forms { apiKey = "" } }
    }

    @ViewBuilder private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hold Control + Option. Speak. Release.", systemImage: "keyboard")
                .font(.system(size: 13, weight: .medium))
            Text(controller.statusText).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !controller.insertionMessage.isEmpty {
                Text(controller.insertionMessage).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if controller.isBusy {
                ProgressView().controlSize(.small)
                if !controller.isRequestingPermissions {
                    Button("Cancel", action: controller.cancel)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

        HelloPermissions(controller: controller)
        HelloActivityDashboard(activity: controller.activity, reset: controller.resetActivity)

        if !controller.transcript.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(controller.isBusy ? "LIVE TRANSCRIPT" : "YOUR WORDS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                ScrollView {
                    Text(controller.transcript).font(.body).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 170)
                HStack {
                    Button("Copy", action: { controller.copyTranscript() }).disabled(controller.isBusy)
                    if controller.originalTranscript != controller.transcript {
                        Button("Copy original", action: { controller.copyTranscript(true) })
                    }
                    Spacer()
                    Button("Clear", action: controller.clearTranscript)
                }
            }
        }

        if !controller.formMessage.isEmpty {
            Text(controller.formMessage).font(.caption).foregroundStyle(.secondary)
        }
        if !controller.formPreview.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("FORM VALUES").font(.caption).foregroundStyle(.secondary)
                ForEach(controller.formPreview) { assignment in
                    VStack(alignment: .leading, spacing: 4) {
                        let field = controller.formFields.first { $0.id == assignment.fieldID }
                        Text(field?.label.isEmpty == false ? field!.label : assignment.fieldID).font(.caption).bold()
                        Text(assignment.text).textSelection(.enabled)
                        Button("Copy value") { controller.copyFormValue(assignment.text) }.disabled(controller.isBusy)
                    }
                }
            }
        }
    }

    private var dictationSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Dictation", detail: "Choose what Hello does with your words after you release the shortcut.")
            if controller.formMode {
                Label("Form Filling is on. Turn it off to use these dictation settings.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Open Form Filling") { section = .forms }
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Insert into the original text field", isOn: $controller.automaticallyInsert)
                    .disabled(controller.formMode || controller.isBusy).helloPointer()
                Text("Hello inserts into the field you started in when it can verify the selection. If it can’t safely insert, it copies your words or asks you to check the field.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Preview punctuation cleanup", isOn: $controller.cleanPunctuation)
                    .disabled(!OnDeviceModel.isAvailable || controller.formMode || controller.isBusy).helloPointer()
                Text(OnDeviceModel.isAvailable
                     ? "Review suggested punctuation in Hello, then copy the version you want. While this is on, Hello pauses automatic insertion."
                     : "Suggested punctuation requires Apple Intelligence on a supported Mac with macOS 26 or later.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            Text("Speech privacy").font(.headline)
            Text("Apple Speech runs on your Mac where supported. Otherwise Apple may process the audio. Hello keeps the latest transcript in memory and skips password fields.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var spellingSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Personal Spellings", detail: "Teach Hello how to spell names and words you use often.")
            Toggle("Use spelling memory", isOn: $controller.spellingMemoryEnabled).disabled(controller.isBusy)
            Text("Correct a spelling within 10 seconds of insertion. Pause for two seconds, then return here to review the suggestion. Approved spellings stay on this Mac and apply to future dictation.")
                .font(.caption).foregroundStyle(.secondary)
            if let suggestion = controller.suggestedSpelling {
                Text("Remember ‘\(suggestion.heard)’ as ‘\(suggestion.spelling)’?")
                HStack {
                    Button("Remember spelling", action: controller.rememberSuggestedSpelling)
                    Button("Ignore", action: controller.ignoreSuggestedSpelling)
                }.disabled(controller.isBusy)
            }
            ForEach(controller.spellingMemory.entries) { entry in
                HStack {
                    Text("\(entry.heard) → \(entry.spelling)").textSelection(.enabled)
                    Spacer()
                    Button("Remove") { controller.spellingMemory.remove(entry) }.disabled(controller.isBusy)
                }
            }
            if !controller.spellingMemory.message.isEmpty {
                Text(controller.spellingMemory.message).font(.caption)
            }
            if controller.spellingMemory.entries.isEmpty {
                Text("No saved spellings yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                Button("Clear saved spellings", action: controller.clearSavedSpellings).disabled(controller.isBusy)
            }
        }
    }

    private var formSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Form Filling", detail: "Dictate answers into empty fields. This optional feature uses your AI provider and can fill several fields at once.")
            Text("Connect a provider").font(.headline)
            Picker("AI provider", selection: $controller.formProvider) {
                ForEach(HelloAIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }.disabled(controller.isBusy)
            Text("Model: \(controller.formProvider.model)").font(.caption).foregroundStyle(.secondary)
            SecureField("\(controller.formProvider.displayName) API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save key") { controller.saveAPIKey(apiKey); apiKey = "" }
                    .disabled(apiKey.isEmpty || controller.isBusy)
                Button("Check saved key") { controller.checkAPIKey() }.disabled(controller.isBusy)
                Button("Remove key") { controller.removeAPIKey() }.disabled(controller.isBusy)
            }
            if controller.hasAPIKey { Text("\(controller.formProvider.displayName) key is available in Keychain.").font(.caption) }
            if !controller.keyMessage.isEmpty { Text(controller.keyMessage).font(.caption) }
            Divider()
            Text("Allow screenshots").font(.headline)
            Button("Allow form filling screenshots") { controller.requestScreenAccess() }.disabled(controller.isBusy)
            Text("Form filling uses a screenshot of the active window to identify text boxes. macOS calls this permission Screen Recording. Hello does not continuously record your screen or save screenshots. Ordinary dictation does not need this permission. After changing access, macOS may require reopening Hello. Form filling does not submit forms or send messages.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Turn on Form Filling").font(.headline)
            Text("When enabled, each dictation sends your transcript, a screenshot of the active window, and empty-field labels to \(controller.formProvider.recipientDescription). The screenshot may contain other private page content. API usage is billed to your account.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Send window to \(controller.formProvider.displayName) and fill empty fields", isOn: $controller.formMode)
                .disabled(controller.isBusy).helloPointer()
            Text("Speak one answer or several labeled answers. No field needs to be selected. Clear matches fill automatically; uncertain matches copy the original transcript to the clipboard. Existing values stay untouched. Screenshots are not saved by Hello. Switching apps, typing, or clicking cancels the destination.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct HelloPermissions: View {
    @ObservedObject var controller: HelloController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Permissions").font(.headline)
                Spacer()
                if let nextStep {
                    Button(nextStep.title, action: nextStep.action).disabled(controller.isBusy)
                } else {
                    Label("Setup complete", systemImage: "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                permission("Microphone", icon: "mic", detail: "Capture your voice",
                           ready: controller.microphoneReady) {
                    controller.requestAudioPermission(.microphone)
                }
                permission("Speech Recognition", icon: "text.bubble", detail: "Turn speech into text",
                           ready: controller.speechReady) {
                    controller.requestAudioPermission(.speech)
                }
                permission("Accessibility", icon: "accessibility", detail: "Insert into a text field",
                           ready: controller.accessibilityReady) {
                    controller.openPrivacySettings("Accessibility")
                }
                permission("Input Monitoring", icon: "keyboard", detail: "Listen for the shortcut",
                           ready: !controller.inputMonitoringNeeded,
                           readyLabel: controller.shortcutMonitor.tapUnavailable ? "Check shortcut" : "Shortcut available") {
                    controller.openPrivacySettings("ListenEvent")
                }
            }
            Text("Select the next step, approve it in macOS, then return here. Form filling has its own optional screenshot permission.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var nextStep: (title: String, action: () -> Void)? {
        if !controller.microphoneReady {
            return ("Set up microphone", { controller.requestAudioPermission(.microphone) })
        }
        if !controller.speechReady {
            return ("Set up speech recognition", { controller.requestAudioPermission(.speech) })
        }
        if !controller.accessibilityReady {
            return ("Set up Accessibility", { controller.openPrivacySettings("Accessibility") })
        }
        if controller.inputMonitoringNeeded {
            return ("Open Input Monitoring", { controller.openPrivacySettings("ListenEvent") })
        }
        if controller.shortcutMonitor.tapUnavailable { return ("Retry shortcut", controller.refreshShortcut) }
        return nil
    }

    private func permission(_ title: String, icon: String, detail: String, ready: Bool,
                            readyLabel: String = "Allowed", action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.blue).accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if ready {
                Text(readyLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            } else {
                Text("Needs setup").font(.caption).foregroundStyle(.secondary)
                Button("Set up", action: action)
                    .font(.caption).disabled(controller.isBusy)
                    .accessibilityLabel("Set up \(title)")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct HelloActivityDashboard: View {
    let activity: HelloActivity
    let reset: () -> Void
    @State private var confirmsReset = false

    var body: some View {
        let days = activity.recentDays()
        let sessions = days.reduce(0) { $0 + $1.sessions }
        let words = days.reduce(0) { $0 + $1.words }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dictation activity").font(.headline)
                Spacer()
                Text("Last 7 days").font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                metric(days.last?.words ?? 0, label: "Words today")
                metric(words, label: "Words in 7 days")
                metric(sessions, label: "Dictations in 7 days")
            }
            if sessions == 0 {
                Label("Finish a dictation to see your activity here.", systemImage: "chart.bar")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 95)
            } else {
                Chart(days) { day in
                    BarMark(x: .value("Date", String(day.id.suffix(5))), y: .value("Words", day.words))
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(3)
                        .accessibilityLabel(day.id)
                        .accessibilityValue("\(day.words) words, \(day.sessions) dictations")
                }
                .chartYScale(domain: 0...max(1, days.map(\.words).max() ?? 0))
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 120)
                .accessibilityLabel("Words by day")
            }
            HStack {
                Text("Daily counts stay on this Mac.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Reset activity", role: .destructive) { confirmsReset = true }
                    .font(.caption).disabled(sessions == 0)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog("Reset dictation activity?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset activity", role: .destructive, action: reset)
        }
    }

    private func metric(_ number: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(number, format: .number).font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }
}

struct HelloButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 8))
            .helloPointer()
    }
}

extension View {
    func helloPointer() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

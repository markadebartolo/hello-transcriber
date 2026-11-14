import AppKit
import SwiftUI

@main
struct HelloApp: App {
    @NSApplicationDelegateAdaptor(HelloAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ScrollView { HelloPanel(controller: appDelegate.controller) }
                .frame(width: 420, height: min(720, (NSScreen.main?.visibleFrame.height ?? 900) - 120))
        } label: {
            HelloMenuBarLabel(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)
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
final class HelloAppDelegate: NSObject, NSApplicationDelegate {
    let controller = HelloController()
    private var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) { showSetupWindow() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetupWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.cancel()
        controller.shortcutMonitor.stop()
    }

    private func showSetupWindow() {
        if setupWindow == nil {
            let availableHeight = NSScreen.main?.visibleFrame.height ?? 900
            let height = min(720, max(400, availableHeight - 120))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: height),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Hello Transcriber"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView:
                ScrollView { HelloPanel(controller: controller) }.frame(width: 420))
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }
}

private struct HelloPanel: View {
    @ObservedObject var controller: HelloController
    @AppStorage("Hello.didReviewPermissions") private var didReviewPermissions = false
    @State private var apiKey = ""
    @State private var showsFormSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("hello").font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("A little less typing.").foregroundStyle(.secondary)
                }
                Spacer()
                Image("HelloWaveform").resizable().scaledToFit()
                    .frame(width: 54, height: 36).foregroundStyle(.blue)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Hold Control + Option. Speak. Release.", systemImage: "keyboard")
                    .font(.system(size: 13, weight: .medium))
                Text(controller.statusText).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if controller.isBusy {
                    ProgressView().controlSize(.small)
                    Button("Cancel", action: controller.cancel)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            if !didReviewPermissions || !controller.microphoneReady || !controller.speechReady || !controller.accessibilityReady {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make room for your voice").font(.headline)
                    Text("Microphone captures your voice. Speech Recognition turns it into text. Accessibility enables the shortcut and inserts text into the field you started in.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(controller.microphoneReady && controller.speechReady ? "Audio ready ✓" : "Enable audio") {
                            controller.requestAudioPermissions()
                            didReviewPermissions = true
                        }.disabled(controller.isBusy)
                        Button(controller.accessibilityReady ? "Accessibility ready ✓" : "Enable Accessibility") {
                            controller.requestAccessibility()
                        }
                    }
                    HStack {
                        Button("Microphone settings") { controller.openPrivacySettings("Microphone") }
                        Button("Speech settings") { controller.openPrivacySettings("SpeechRecognition") }
                    }.font(.caption)
                }
            }
            if controller.shortcutMonitor.tapUnavailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The global shortcut isn't available. Allow Hello in Accessibility and Input Monitoring, then retry.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Input Monitoring") { controller.openPrivacySettings("ListenEvent") }
                        Button("Retry shortcut") { controller.refreshShortcut() }
                    }
                }
            }

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

            Divider()
            DisclosureGroup("Voice form filling (OpenAI)", isExpanded: $showsFormSettings) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When enabled, each dictation sends your transcript, a screenshot of the active window, and empty-field labels to OpenAI. The screenshot may contain other private page content. API usage is billed to your account.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Send window to OpenAI and fill empty fields", isOn: $controller.formMode)
                        .disabled(controller.isBusy).helloPointer()
                    Text("Speak one answer or several labeled answers. No field needs to be selected. Clear matches fill automatically; uncertain matches copy the original transcript to the clipboard. Existing values stay untouched. Screenshots are not saved by Hello. Switching apps, typing, or clicking cancels the destination.")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("OpenAI API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save key") { controller.saveAPIKey(apiKey); apiKey = "" }
                            .disabled(apiKey.isEmpty || controller.isBusy)
                        Button("Check saved key") { controller.checkAPIKey() }.disabled(controller.isBusy)
                        Button("Remove key") { controller.removeAPIKey() }.disabled(controller.isBusy)
                    }
                    if controller.hasAPIKey { Text("API key is available in Keychain.").font(.caption) }
                    if !controller.keyMessage.isEmpty { Text(controller.keyMessage).font(.caption) }
                    Button("Enable Screen Recording") { controller.requestScreenAccess() }.disabled(controller.isBusy)
                    Text("Screen Recording is needed only for this optional mode. After changing access, macOS may require reopening Hello. Form filling does not submit forms or send messages.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Insert into the original text field", isOn: $controller.automaticallyInsert).disabled(controller.formMode || controller.isBusy).helloPointer()
                Toggle("Preview punctuation cleanup", isOn: $controller.cleanPunctuation)
                    .disabled(!OnDeviceModel.isAvailable || controller.formMode || controller.isBusy).helloPointer()
                Text(OnDeviceModel.isAvailable
                     ? "Cleanup is review-only and disables automatic insertion. Check the suggestion before copying; punctuation can change meaning."
                     : "Optional cleanup needs Apple Intelligence on a supported Mac with macOS 26 or later.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Apple Speech uses on-device recognition where supported; otherwise audio may be sent to Apple. Hello keeps only the latest transcript in memory. Password fields are excluded. When no field can be filled, Hello copies the original transcript to your clipboard.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("Hello · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit Hello", action: controller.quit)
            }
        }
        .padding(24)
        .frame(width: 420)
        .buttonStyle(HelloButtonStyle())
        .onAppear { controller.refreshShortcut() }
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

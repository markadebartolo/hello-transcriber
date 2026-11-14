import AppKit
import Combine
import SwiftUI

@MainActor
final class HelloStatusPanel {
    private let panel: NSPanel
    private var subscription: AnyCancellable?

    init(controller: HelloController) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 132),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HelloRecordingStatus(controller: controller))
        subscription = controller.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak controller] _ in
                guard let self, let controller else { return }
                if controller.recordingFeedback.isVisible {
                    if !panel.isVisible {
                        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
                        if let screen {
                            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 190, y: screen.visibleFrame.minY + 34))
                        }
                        // Display without activation so the destination field keeps focus.
                        panel.orderFrontRegardless()
                    }
                } else {
                    panel.orderOut(nil)
                }
            }
    }
}

private struct HelloRecordingStatus: View {
    @ObservedObject var controller: HelloController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let feedback = controller.recordingFeedback
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: feedback.showsLiveWaveform ? "mic.fill" : feedback.phase == .stopped ? "mic.slash.fill" : "waveform")
                    .foregroundStyle(feedback.showsLiveWaveform ? Color.blue : Color.secondary)
                    .accessibilityHidden(true)
                Text(feedback.title).font(.headline)
                Spacer()
                if controller.shortcutMonitor.isShortcutCurrentlyPressed {
                    Text("⌃ ⌥ held").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Button(action: { if controller.isBusy { controller.cancel() } else { controller.dismissResult() } }) { Image(systemName: "xmark") }
                    .accessibilityLabel(controller.isBusy ? "Cancel dictation" : "Dismiss result").buttonStyle(HelloButtonStyle())
                    .disabled(controller.shortcutMonitor.isShortcutCurrentlyPressed && !controller.isBusy)
            }
            if feedback.showsLiveWaveform {
                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array(controller.dictation.recordedAudioPowerHistory.enumerated()), id: \.offset) { _, level in
                        Capsule().fill(Color.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(3, min(1, max(0, level)) * 32))
                    }
                }
                .frame(height: 32)
                .animation(reduceMotion ? nil : .linear(duration: 0.07), value: controller.dictation.recordedAudioPowerHistory)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Live microphone waveform")
            } else if feedback.phase == .starting || feedback.phase == .transcribing || feedback.phase == .processing {
                ProgressView().controlSize(.small).frame(height: 32)
            }
            Text(feedback.phase == .stopped
                 ? "\(controller.statusText) Release the keys to try again."
                 : controller.statusText)
                .font(.caption).lineLimit(3)
        }
        .padding(16)
        .frame(width: 380, height: 132, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

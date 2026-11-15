import AppKit
import Combine
import SwiftUI

@MainActor
final class HelloStatusPanel {
    private let panel: NSPanel
    private var subscription: AnyCancellable?

    init(controller: HelloController) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 168, height: 34),
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
                    let hasCaption = !controller.liveCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let size = NSSize(width: hasCaption ? 192 : controller.recordingFeedback.showsLiveWaveform ? 96 : 168,
                                      height: hasCaption ? 60 : 34)
                    if !panel.isVisible {
                        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
                        if let screen {
                            panel.setFrame(NSRect(x: screen.visibleFrame.midX - size.width / 2,
                                                  y: screen.visibleFrame.minY + 34,
                                                  width: size.width, height: size.height), display: true)
                        }
                        // Display without activation so the destination field keeps focus.
                        panel.orderFrontRegardless()
                    } else if panel.frame.size != size {
                        // Grow upward without moving the waveform or taking focus.
                        panel.setFrame(NSRect(x: panel.frame.midX - size.width / 2,
                                              y: panel.frame.minY,
                                              width: size.width, height: size.height), display: true)
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
        let caption = controller.liveCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = HelloLiveCaption(caption)
        VStack(spacing: 2) {
            if !caption.isEmpty {
                Text(preview.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .padding(.horizontal, 8)
                    .frame(width: 192, height: 24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Live transcript, may change: \(preview.text)")
                    .help("Latest three recognized words. Open Hello for the full transcript.")
            }
            recordingPill
        }
        .frame(width: caption.isEmpty ? (controller.recordingFeedback.showsLiveWaveform ? 96 : 168) : 192,
               height: caption.isEmpty ? 34 : 60, alignment: .bottom)
    }

    private var recordingPill: some View {
        let feedback = controller.recordingFeedback
        return HStack(spacing: 7) {
            if feedback.showsLiveWaveform {
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(controller.dictation.recordedAudioPowerHistory.suffix(12).enumerated()), id: \.offset) { _, level in
                        Capsule().fill(Color.blue)
                            .frame(width: 2, height: max(2, min(1, max(0, level)) * 18))
                    }
                }
                .frame(width: 46, height: 18)
                .animation(reduceMotion ? nil : .linear(duration: 0.07), value: controller.dictation.recordedAudioPowerHistory)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Live microphone waveform")
            } else if feedback.phase == .starting || feedback.phase == .transcribing || feedback.phase == .processing {
                ProgressView().controlSize(.mini).frame(width: 12, height: 12)
            } else if feedback.phase == .stopped {
                Image(systemName: "mic.slash.fill").foregroundStyle(.secondary).accessibilityHidden(true)
            }
            if !feedback.showsLiveWaveform {
                Text(compactTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(controller.statusText)
                    .accessibilityLabel("\(feedback.title). \(controller.statusText)")
            }
            Button(action: { if controller.isBusy { controller.cancel() } else { controller.dismissResult() } }) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controller.isBusy ? "Cancel dictation" : "Dismiss result")
            .disabled(controller.shortcutMonitor.isShortcutCurrentlyPressed && !controller.isBusy)
        }
        .padding(.horizontal, 10)
        .frame(width: feedback.showsLiveWaveform ? 96 : 168, height: 34)
        .background(.regularMaterial, in: Capsule())
    }

    private var compactTitle: String {
        switch controller.recordingFeedback.phase {
        case .starting: return "Starting…"
        case .stopped: return "Stopped"
        case .result:
            return controller.speechFallbackMessage.isEmpty ? controller.resultMessage : "Apple Speech fallback"
        default: return controller.recordingFeedback.title
        }
    }
}

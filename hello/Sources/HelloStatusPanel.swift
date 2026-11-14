import AppKit
import Combine
import SwiftUI

@MainActor
final class HelloStatusPanel {
    private let panel: NSPanel
    private var subscription: AnyCancellable?

    init(controller: HelloController) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 76),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HelloRecordingStatus(controller: controller))
        subscription = controller.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak controller] _ in
                guard let self, let controller else { return }
                if controller.dictation.isDictationInProgress || controller.isProcessingTranscript {
                    if !panel.isVisible {
                        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
                        if let screen {
                            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 170, y: screen.visibleFrame.minY + 34))
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform").font(.title2).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("hello").font(.headline)
                Text(controller.statusText).font(.caption).lineLimit(2)
            }
            Spacer()
            Button(action: controller.cancel) { Image(systemName: "xmark") }
                .accessibilityLabel("Cancel dictation").buttonStyle(HelloButtonStyle())
        }
        .padding(16)
        .frame(width: 340, height: 76)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

import SwiftUI
import AppKit

final class ProgressPanelController {
    private var panel: NSPanel?

    func show(model: ScanViewModel) {
        if panel == nil {
            let contentView = ProgressPanelView(model: model)
            let hosting = NSHostingView(rootView: contentView)

            let panel = NSPanel(
                contentRect: NSRect(x: 200, y: 220, width: 390, height: 146),
                styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Disk Audit Progress"
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentView = hosting
            panel.center()
            self.panel = panel
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

struct ProgressPanelView: View {
    @ObservedObject var model: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scanning selected locations")
                .font(.headline)
            ProgressView(value: model.progressValue)
                .progressViewStyle(.linear)
            Text(model.progressLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Text("Scanned: \(model.scannedCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isScanning {
                    Button("Cancel") {
                        model.cancelScan()
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !model.currentScanningPath.isEmpty {
                Text("Currently: \(model.currentScanningPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AboutSheetView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DISK AUDIT")
                .font(.title2.bold())
            Text("A macOS disk space visualizer with treemap view, category filters, risk levels and cleanup workflow.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Institut fuer digitale Herausforderungen")
                    .font(.headline)
                Link("institut-fdh.de", destination: URL(string: "https://institut-fdh.de")!)
                Link("Buy me a coffee", destination: URL(string: "https://buymeacoffee.com/nickyreinert")!)
                Link("GitHub: nickyreinert/DiskAudit", destination: URL(string: "https://github.com/nickyreinert/DiskAudit")!)
            }

            Spacer()
            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 300)
    }
}

final class AboutPanelController {
    static let shared = AboutPanelController()
    private var panel: NSPanel?

    private init() {}

    func show() {
        if panel == nil {
            let contentView = AboutSheetView { [weak self] in
                self?.panel?.orderOut(nil)
            }
            let hosting = NSHostingView(rootView: contentView)

            let newPanel = NSPanel(
                contentRect: NSRect(x: 240, y: 240, width: 420, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newPanel.title = "About DISK AUDIT"
            newPanel.isFloatingPanel = true
            newPanel.hidesOnDeactivate = false
            newPanel.contentView = hosting
            newPanel.center()
            self.panel = newPanel
        }

        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
}

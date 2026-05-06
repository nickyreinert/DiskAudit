import SwiftUI

@main
struct DiskAuditApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DISK AUDIT") {
                    AboutPanelController.shared.show()
                }
            }
        }
    }
}

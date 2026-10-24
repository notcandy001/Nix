import SwiftUI

@main
struct NixApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserWindow()
                .frame(minWidth: 820, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { BrowserStore.shared.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") { BrowserStore.shared.closeActiveTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Focus Address Bar") { BrowserStore.shared.focusAddressBar = true }
                    .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}

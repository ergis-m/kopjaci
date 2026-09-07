import Carbon
import SwiftUI

@main
struct KopjaciApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var history = History.shared

    var body: some Scene {
        MenuBarExtra("Kopjaci", systemImage: "doc.on.clipboard") {
            if history.items.isEmpty { Text("No history yet") }
            ForEach(history.items.prefix(20)) { item in
                Button { history.copy(item) } label: {
                    Label(String(item.preview.prefix(60)), systemImage: item.kind == .image ? "photo" : item.kind == .file ? "doc" : "text.alignleft")
                }
            }
            Divider()
            Button("Clear History") { history.clear() }
            Button("Settings…") { openWindow(id: "settings") }.keyboardShortcut(",")
            Divider()
            Button("Quit Kopjaci") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        Window("Settings", id: "settings") { SettingsView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 660, height: 460)
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(.suppressed)
            .handlesExternalEvents(matching: ["settings"])   // open with `open kopjaci://settings`
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: ["historyMax": 100, "pickerRows": 10, "mouseSelect": true, "deleteKey": true])
        HotKey.install()
        HotKey.onPress = { Picker.shared.onHotKey($0) }
        HotKey.register(HotKey.v, key: kVK_ANSI_V)
    }
}

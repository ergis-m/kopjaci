import ServiceManagement
import SwiftUI

struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case general = "General", history = "History", about = "About"
        var id: Self { self }
        var icon: String { [.general: "gearshape.fill", .history: "clock.fill", .about: "info"][self]! }
        var color: Color { [.general: .gray, .history: .blue, .about: .indigo][self]! }
    }
    @State private var pane = Pane.general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: floating glass column like System Settings; the traffic lights sit in its top-left.
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Pane.allCases) { p in
                    HStack(spacing: 8) {
                        Image(systemName: p.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(p.color.gradient, in: RoundedRectangle(cornerRadius: 6))
                        Text(p.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(pane == p ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(pane == p ? .white : .primary)
                    .contentShape(Rectangle())
                    .onTapGesture { pane = p }
                }
                Spacer()
            }
            .padding(8)
            .padding(.top, 30)
            .frame(width: 190)
            .background(SidebarMaterial().clipShape(RoundedRectangle(cornerRadius: 18)))
            .padding(10)

            VStack(alignment: .leading, spacing: 0) {
                Text(pane.rawValue).font(.title2.bold()).padding(.horizontal, 20).padding(.top, 22)
                switch pane {
                case .general: GeneralTab()
                case .history: HistoryTab()
                case .about: AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .containerBackground(.ultraThinMaterial, for: .window)
        .background(WindowChrome())
        .onAppear { NSApp.activate(ignoringOtherApps: true) }   // LSUIElement apps don't activate on their own
    }
}

struct GeneralTab: View {
    @AppStorage("historyMax") private var historyMax = 100
    @AppStorage("pickerRows") private var pickerRows = 10
    @AppStorage("mouseSelect") private var mouseSelect = true
    @AppStorage("deleteKey") private var deleteKey = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    try? (on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
                }
            Section("Picker") {
                Stepper("History size: \(historyMax)", value: $historyMax, in: 10...1000, step: 10)
                Stepper("Rows in picker: \(pickerRows)", value: $pickerRows, in: 3...30)
                Toggle("Select with mouse while holding", isOn: $mouseSelect)
                Toggle("Backspace removes the selected item", isOn: $deleteKey)
                LabeledContent("Shortcut", value: "⌘⇧V")
                LabeledContent("While holding", value: "V / ↓ next · ↑ previous · ⌫ remove · esc cancel")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

struct HistoryTab: View {
    @ObservedObject private var history = History.shared
    @State private var query = ""

    private var shown: [ClipItem] {
        query.isEmpty ? history.items : history.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack {
            TextField("Search", text: $query).textFieldStyle(.roundedBorder)
            List(shown) { item in
                HStack {
                    if let thumb = item.thumbnail {
                        Image(nsImage: thumb).resizable().scaledToFit().frame(height: 36).clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.preview).lineLimit(1)
                            Text(item.info ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: item.kind == .file ? "doc" : "text.alignleft").foregroundStyle(.secondary)
                        Text(item.preview).lineLimit(1)
                    }
                    Spacer()
                    Button("Copy") { history.copy(item) }
                    Button { history.remove(item) } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.borderless)
            }
            .scrollContentBackground(.hidden)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            HStack {
                Text("\(history.items.count) items").foregroundStyle(.secondary)
                Spacer()
                Button("Clear All", role: .destructive) { history.clear() }
            }
        }
        .padding(20)
    }
}

struct AboutTab: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 20))
            Text("Kopjaci").font(.title.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Clipboard history for macOS. Hold ⌘⇧ and tap V to pick, let go to paste.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Sidebar blur that shows the desktop behind the window, as System Settings does.
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_: NSVisualEffectView, context: Context) {}
}

/// Window tweaks that need the real NSWindow: draggable body, traffic lights inset into the sidebar panel.
private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ChromeView() }
    func updateNSView(_: NSView, context: Context) {}

    final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            guard let w = window else { return }
            w.isMovableByWindowBackground = true
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: w, queue: .main) { _ in Self.placeLights(w) }
            NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: w, queue: .main) { _ in Self.placeLights(w) }
            Self.placeLights(w)
        }
        static func placeLights(_ w: NSWindow) {
            for (i, b) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                w.standardWindowButton(b)?.setFrameOrigin(NSPoint(x: 20 + 23 * i, y: 1))
            }
        }
    }
}

import AppKit
import Carbon
import SwiftUI

/// One hold-to-cycle session: panel at the mouse, each V press advances, releasing cmd/shift pastes, Escape cancels.
final class Picker: ObservableObject {
    static let shared = Picker()
    static let width: CGFloat = 360
    static func rowHeight(_ item: ClipItem) -> CGFloat { item.kind == .image ? 64 : 26 }

    @Published var items: [ClipItem] = []
    @Published var selected = 0
    private let panel: NSPanel
    private var monitors: [Any] = []

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = NSHostingView(rootView: PickerView(picker: self))
    }

    func onHotKey(_ id: UInt32) {
        guard panel.isVisible else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            guard id == HotKey.v, AXIsProcessTrustedWithOptions(opts) else { return }   // release/paste need Accessibility
            items = Array(History.shared.items.prefix(UserDefaults.standard.integer(forKey: "pickerRows")))
            guard !items.isEmpty else { return }
            selected = 0
            return show()
        }
        switch id {
        case HotKey.v, HotKey.down: selected = (selected + 1) % items.count
        case HotKey.up: selected = (selected + items.count - 1) % items.count
        case HotKey.escape: finish(paste: false)
        case HotKey.delete where UserDefaults.standard.bool(forKey: "deleteKey"):
            History.shared.remove(items.remove(at: selected))
            guard !items.isEmpty else { return finish(paste: false) }
            selected = min(selected, items.count - 1)
            let f = panel.frame, h = Self.height(for: items)
            panel.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: f.width, height: h), display: true)
        default: break
        }
    }

    private static func height(for items: [ClipItem]) -> CGFloat { items.map { rowHeight($0) + 2 }.reduce(10, +) }

    private func show() {
        let size = NSSize(width: Self.width, height: Self.height(for: items))
        let at = anchor()
        let screen = (NSScreen.screens.first { $0.frame.contains(at) } ?? NSScreen.main)?.visibleFrame ?? .zero
        var origin = NSPoint(x: at.x, y: at.y - size.height)
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        origin.y = min(max(origin.y, screen.minY), screen.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        for (id, key) in Self.sessionKeys { HotKey.register(id, key: key) }

        let flags: (NSEvent) -> Void = { [weak self] e in
            if !e.modifierFlags.contains(.command) || !e.modifierFlags.contains(.shift) { self?.finish(paste: true) }
        }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags),
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { flags($0); return $0 },
        ].compactMap { $0 }
    }

    /// Hotkeys that only exist while the panel is up, so they don't shadow the apps' own cmd+shift shortcuts otherwise.
    private static let sessionKeys: [(UInt32, Int)] = [
        (HotKey.down, kVK_DownArrow), (HotKey.up, kVK_UpArrow), (HotKey.delete, kVK_Delete), (HotKey.escape, kVK_Escape),
    ]

    /// Top-left point for the panel: text caret → focused input's bottom edge → mouse.
    /// AX coordinates are top-left origin on the primary screen; AppKit is bottom-left, so flip Y.
    private func anchor() -> NSPoint {
        var focused: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        guard let focused else { return NSEvent.mouseLocation }
        let el = focused as! AXUIElement
        let flip = { (x: CGFloat, axBottom: CGFloat) in NSPoint(x: x, y: NSScreen.screens[0].frame.height - axBottom) }

        var range: CFTypeRef?, bounds: CFTypeRef?
        var caret = CGRect.zero
        if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &range) == .success, let range,
           AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, range, &bounds) == .success,
           let bounds, AXValueGetValue(bounds as! AXValue, .cgRect, &caret), (1...100).contains(caret.height) {
            return flip(caret.minX, caret.maxY)
        }
        var pos: CFTypeRef?, sz: CFTypeRef?
        var p = CGPoint.zero, s = CGSize.zero
        if AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &pos) == .success, let pos,
           AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sz) == .success, let sz,
           AXValueGetValue(pos as! AXValue, .cgPoint, &p), AXValueGetValue(sz as! AXValue, .cgSize, &s),
           (1...120).contains(s.height) {   // a text field, not a whole editor (Zed, terminals) → else mouse
            return flip(p.x, p.y + s.height)
        }
        return NSEvent.mouseLocation
    }

    func finish(paste: Bool) {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        Self.sessionKeys.forEach { HotKey.unregister($0.0) }
        panel.orderOut(nil)
        HotKey.pressed = false
        guard paste, items.indices.contains(selected) else { return }
        History.shared.copy(items[selected])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .combinedSessionState)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: down)
                e?.flags = .maskCommand
                e?.post(tap: .cgSessionEventTap)
            }
        }
    }
}

struct PickerView: View {
    @ObservedObject var picker: Picker
    @AppStorage("mouseSelect") private var mouseSelect = true

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 2) {
            ForEach(Array(picker.items.enumerated()), id: \.element.id) { i, item in
                HStack(spacing: 8) {
                    if let thumb = item.thumbnail {
                        Image(nsImage: thumb).resizable().scaledToFit().frame(maxHeight: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.preview).lineLimit(1)
                            Text(item.info ?? "").font(.caption).opacity(0.7)
                        }
                    } else {
                        Image(systemName: item.kind == .file ? "doc" : "text.alignleft").frame(width: 14)
                        Text(item.preview).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: Picker.rowHeight(item))
                .foregroundStyle(i == picker.selected ? Color.white : Color.primary)
                .glassEffect(i == picker.selected ? .regular.tint(.accentColor) : .identity, in: .rect(cornerRadius: 8))
                .contentShape(Rectangle())
                .onHover { if $0, mouseSelect { picker.selected = i } }
                .onTapGesture { if mouseSelect { picker.selected = i; picker.finish(paste: true) } }
            }
            }
            .padding(6)
            .frame(width: Picker.width)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }
}

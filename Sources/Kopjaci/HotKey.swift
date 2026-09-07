import Carbon

/// Global cmd+shift+<key> hotkeys via Carbon: no permissions needed and the keystroke never reaches the frontmost app.
/// `onPress(id)` fires for every press (auto-repeat included); `pressed` lets the caller filter repeats for V.
enum HotKey {
    static let v: UInt32 = 1, down: UInt32 = 2, up: UInt32 = 3, delete: UInt32 = 4, escape: UInt32 = 5
    static var onPress: (UInt32) -> Void = { _ in }
    static var pressed = false
    private static var refs: [UInt32: EventHotKeyRef] = [:]

    static func install() {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            switch Int(GetEventKind(event)) {
            case kEventHotKeyPressed where hk.id != HotKey.v || !HotKey.pressed:
                if hk.id == HotKey.v { HotKey.pressed = true }
                HotKey.onPress(hk.id)
            case kEventHotKeyReleased where hk.id == HotKey.v: HotKey.pressed = false
            default: break
            }
            return noErr
        }, specs.count, &specs, nil, nil)
    }

    static func register(_ id: UInt32, key: Int) {
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x4B50_4A43, id: id),
                            GetApplicationEventTarget(), 0, &ref)
        refs[id] = ref
    }

    static func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    }
}

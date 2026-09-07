import AppKit
import CryptoKit

struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, file, image }
    var id = UUID()
    var kind: Kind
    var text: String          // text, newline-joined file paths, or the image's SHA-256 (dedupe key)
    var date = Date()
    var source: String?       // image: app it was copied from, or "Screenshot"
    var info: String?         // image: "1920×1080 · PNG · 1.2 MB"

    var preview: String {
        kind == .image ? "Image" + (source.map { " from \($0)" } ?? "") : (text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "").trimmingCharacters(in: .whitespaces)
    }
    var urls: [URL] { text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) } }
    var thumbnail: NSImage? { kind == .image ? NSImage(contentsOf: History.imageURL(id, thumb: true)) : nil }
}

extension NSImage {
    var png: Data? { tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?.representation(using: .png, properties: [:]) }

    func scaled(toFit max: CGFloat) -> NSImage {
        let k = min(1, max / Swift.max(size.width, size.height))
        let out = NSSize(width: size.width * k, height: size.height * k)
        return NSImage(size: out, flipped: false) { self.draw(in: $0); return true }
    }
}

/// Polls the pasteboard and keeps the last `max` distinct items, persisted as JSON.
final class History: ObservableObject {
    static let shared = History()

    @Published private(set) var items: [ClipItem] = []
    private var lastChange = NSPasteboard.general.changeCount
    private static let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Kopjaci")
    private let file = dir.appendingPathComponent("history.json")
    static func imageURL(_ id: UUID, thumb: Bool = false) -> URL {
        dir.appendingPathComponent("images/\(id.uuidString)\(thumb ? "-thumb" : "").png")
    }

    private init() {
        items = (try? JSONDecoder().decode([ClipItem].self, from: Data(contentsOf: file))) ?? []
        // ponytail: NSPasteboard has no change notification; 0.5s polling is what every manager does.
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        if pb.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) == true { return }
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty, urls.allSatisfy(\.isFileURL) {
            add(ClipItem(kind: .file, text: urls.map(\.path).joined(separator: "\n")))
        } else if let img = NSImage(pasteboard: pb), let png = pb.data(forType: .png) ?? img.png {
            let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
            let types = pb.types ?? []
            let format = types.contains(.png) ? "PNG" : types.contains(.init("public.jpeg")) ? "JPEG" : types.contains(.tiff) ? "TIFF" : "Image"
            let rep = NSBitmapImageRep(data: png)
            let px = rep.map { "\($0.pixelsWide)×\($0.pixelsHigh)" } ?? ""
            let source = types.contains { $0.rawValue.contains("screencapture") } ? "Screenshot"
                : NSWorkspace.shared.frontmostApplication?.localizedName
            let item = ClipItem(kind: .image, text: hash, source: source,
                                info: "\(px) · \(format) · \(ByteCountFormatter.string(fromByteCount: Int64(png.count), countStyle: .file))")
            add(item, png: png, thumb: img.scaled(toFit: 200).png)
        } else if let s = pb.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(ClipItem(kind: .text, text: s))
        }
    }

    private func add(_ item: ClipItem, png: Data? = nil, thumb: Data? = nil) {
        var item = item
        if let old = items.first(where: { $0.text == item.text }) {
            item.id = old.id                       // duplicate image: keep the files already on disk
        } else if let png, let thumb {
            try? FileManager.default.createDirectory(at: Self.imageURL(item.id).deletingLastPathComponent(), withIntermediateDirectories: true)
            try? png.write(to: Self.imageURL(item.id))
            try? thumb.write(to: Self.imageURL(item.id, thumb: true))
        }
        items.removeAll { $0.text == item.text }
        items.insert(item, at: 0)
        let max = UserDefaults.standard.integer(forKey: "historyMax")
        if items.count > max { purge(items.suffix(from: max)); items.removeLast(items.count - max) }
        save()
    }

    func remove(_ item: ClipItem) { purge([item]); items.removeAll { $0.id == item.id }; save() }
    func clear() { purge(items); items = []; save() }

    private func purge(_ dropped: some Sequence<ClipItem>) {
        for i in dropped where i.kind == .image {
            try? FileManager.default.removeItem(at: Self.imageURL(i.id))
            try? FileManager.default.removeItem(at: Self.imageURL(i.id, thumb: true))
        }
    }

    /// Puts an item on the pasteboard; the next poll moves it to the top.
    func copy(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .file: pb.writeObjects(item.urls as [NSURL])
        case .text: pb.setString(item.text, forType: .string)
        case .image: if let img = NSImage(contentsOf: Self.imageURL(item.id)) { pb.writeObjects([img]) }   // offers PNG + TIFF
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(items).write(to: file)
    }
}

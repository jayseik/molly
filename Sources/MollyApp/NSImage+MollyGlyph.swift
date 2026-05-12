import AppKit

extension NSImage {

    /// Menu bar capsule / “pill” template image (distinct monoline brand mark).
    static func mollyStatusGlyph(size: CGSize = CGSize(width: 17, height: 11)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.white.setFill()
        let bezel = CGFloat(min(size.width, size.height) / 2)
        let path = NSBezierPath(
            roundedRect: NSRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2),
            xRadius: bezel,
            yRadius: bezel)
        path.fill()

        image.isTemplate = true

        return image
    }
}

import AppKit

@MainActor
enum StatusItemBadgeRenderer {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private static let horizontalPadding: CGFloat = 6
    private static let verticalPadding: CGFloat = 2
    private static let strokeWidth: CGFloat = 1

    static func image(for title: String) -> NSImage {
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        let size = NSSize(
            width: ceil(textSize.width + horizontalPadding * 2),
            height: ceil(textSize.height + verticalPadding * 2)
        )

        let image = NSImage(size: size, flipped: false) { rect in
            let color = NSColor.labelColor
            let inset = strokeWidth / 2
            let pillRect = rect.insetBy(dx: inset, dy: inset)
            let cornerRadius = pillRect.height / 2

            let path = NSBezierPath(roundedRect: pillRect, xRadius: cornerRadius, yRadius: cornerRadius)
            color.withAlphaComponent(0.55).setStroke()
            path.lineWidth = strokeWidth
            path.stroke()

            let textOrigin = NSPoint(
                x: horizontalPadding,
                y: verticalPadding
            )
            (title as NSString).draw(at: textOrigin, withAttributes: [
                .font: font,
                .foregroundColor: color,
            ])
            return true
        }
        image.isTemplate = false
        return image
    }
}

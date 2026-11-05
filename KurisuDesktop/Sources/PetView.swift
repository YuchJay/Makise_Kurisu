import AppKit

final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    let atlas: SpriteAtlas
    var pose: PetPose = .idle
    var animationFrame = 0
    var spriteVerticalOffset: CGFloat = 0
    var laptopFrame: Int?
    var onTap: (() -> Void)?
    var onDragChanged: ((Bool) -> Void)?
    var onDragMoved: ((CGFloat) -> Void)?
    var onPositionSaved: (() -> Void)?
    var makeMenu: (() -> NSMenu)?
    var onDrop: ((NSPasteboard) -> Bool)?
    var dropActive = false
    private var downPosition = NSPoint.zero
    private var windowOrigin = NSPoint.zero
    private var previousDragPosition = NSPoint.zero
    private var dragging = false
    private var tracking: NSTrackingArea?

    init(atlas: SpriteAtlas) {
        self.atlas = atlas
        super.init(frame: NSRect(x: 0, y: 0, width: 192, height: 224))
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Kurisu 像素桌宠")
        setAccessibilityHelp("点击打开便签、暂存、剪贴板和专注工具。拖入文件或链接可暂存，拖动小人可移动，右键打开菜单。")
        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { false }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        let scale = bounds.width / 192
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        let image = laptopFrame.map { atlas.laptopImage(frame: $0) }
            ?? atlas.image(pose, frame: animationFrame)
        context.draw(image,
                     in: CGRect(x: 0, y: 16 + spriteVerticalOffset, width: 192, height: 208))
        context.restoreGState()
        if dropActive {
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 10, yRadius: 10)
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropActive = true; needsDisplay = true
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropActive = false; needsDisplay = true }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { dropActive = false; needsDisplay = true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropActive = false; needsDisplay = true
        return onDrop?(sender.draggingPasteboard) ?? false
    }

    override func mouseDown(with event: NSEvent) {
        downPosition = NSEvent.mouseLocation
        previousDragPosition = downPosition
        windowOrigin = window?.frame.origin ?? .zero
        dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        let dx = point.x - downPosition.x, dy = point.y - downPosition.y
        if !dragging && hypot(dx, dy) < 4 { return }
        if !dragging { dragging = true; onDragChanged?(true) }
        let horizontalStep = point.x - previousDragPosition.x
        previousDragPosition = point
        onDragMoved?(horizontalStep)
        window?.setFrameOrigin(NSPoint(x: (windowOrigin.x + dx).rounded(),
                                      y: (windowOrigin.y + dy).rounded()))
    }
    override func mouseUp(with event: NSEvent) {
        if dragging {
            onDragChanged?(false)
            onPositionSaved?()
        } else { onTap?() }
        dragging = false
    }
    override func rightMouseDown(with event: NSEvent) {
        if let menu = makeMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

import AppKit
import SwiftUI

private final class ToolPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    var onEscape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

private struct SpeechView: View {
    let request: SpeechRequest
    let start: () -> Void
    let snooze: () -> Void
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(request.text).font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain).accessibilityLabel("收起气泡")
            }
            if request.isReminder {
                HStack {
                    Button("现在休息", action: start).buttonStyle(.borderedProminent)
                    Button("五分钟后", action: snooze)
                }.controlSize(.small)
            }
        }
        .padding(14).frame(width: 290, alignment: .leading)
        .foregroundStyle(UtilityTheme.ink).tint(UtilityTheme.accent)
        .background(UtilityTheme.ground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .light)
    }
}

/// Independent panels keep bubbles visible above a utility window without
/// activating the application or stealing focus from the user's editor.
final class UtilityWindows {
    let store: UtilityStore
    private weak var anchor: NSWindow?
    private var tool: ToolPanel?
    private var bubble: NSPanel?
    private var hideTask: DispatchWorkItem?
    private var reminderVisible = false
    private var isHidden = false
    private var anchorObserver: NSObjectProtocol?

    init(store: UtilityStore, anchor: NSWindow) {
        self.store = store; self.anchor = anchor
        store.onSpeech = { [weak self] request in self?.speak(request) }
        store.onStatusChanged = { [weak self] in
            guard let self else { return }
            if self.reminderVisible && !self.store.reminderDue { self.dismissBubble() }
        }
        anchorObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification,
                                                               object: anchor, queue: .main) { [weak self] _ in self?.position() }
    }

    func toggleTools() {
        if tool?.isVisible == true { tool?.orderOut(nil); return }
        showTools()
        store.say("open")
    }
    func showTools(tab: UtilityTab? = nil) {
        if let tab { store.tab = tab }
        if tool == nil {
            let panel = ToolPanel(contentRect: NSRect(x: 0,y: 0,width: 440,height: 600),
                                  styleMask: [.titled, .closable, .utilityWindow],
                                  backing: .buffered, defer: false)
            panel.title = "Kurisu · 随手工具"
            panel.isReleasedWhenClosed = false; panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: UtilityView(store: store) { [weak self] in self?.tool?.orderOut(nil) })
            panel.onEscape = { [weak self] in self?.tool?.orderOut(nil) }
            tool = panel
        }
        position()
        // Explicit click opens an editable panel. No activation on hover/bubbles.
        NSApp.activate(ignoringOtherApps: true)
        tool?.makeKeyAndOrderFront(nil)
    }
    func speak(_ request: SpeechRequest) {
        if request.text.isEmpty {
            if !reminderVisible { dismissBubble() }
            return
        }
        if reminderVisible && !request.isReminder && store.reminderDue { return }
        dismissBubble()
        reminderVisible = request.isReminder
        let panel = CompanionPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        let view = NSHostingView(rootView: SpeechView(
            request: request,
            start: { [weak self] in self?.dismissBubble(); self?.store.beginBreak() },
            snooze: { [weak self] in self?.dismissBubble(); self?.store.snoozeBreak() },
            close: { [weak self] in self?.dismissBubble() }))
        let size = view.fittingSize
        panel.setContentSize(NSSize(width: 290,height: max(64,size.height)))
        panel.contentView = view; panel.isOpaque = false
        panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        bubble = panel; position()
        if !isHidden { panel.orderFrontRegardless() }
        if !request.isReminder {
            let task = DispatchWorkItem { [weak self] in self?.dismissBubble() }
            hideTask = task
            DispatchQueue.main.asyncAfter(deadline: .now()+max(4, min(9, Double(request.text.count)*0.14)), execute: task)
        }
    }
    func dismissBubble() {
        hideTask?.cancel(); hideTask = nil
        bubble?.orderOut(nil); bubble = nil; reminderVisible = false
    }
    func setHidden(_ value: Bool) {
        isHidden = value
        if value { tool?.orderOut(nil); bubble?.orderOut(nil) }
        else if bubble != nil { bubble?.orderFrontRegardless() }
    }
    func position() {
        guard let anchor else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor.frame) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            max(lower, min(value, max(lower, upper)))
        }
        if let tool {
            let size = tool.frame.size
            let left = anchor.frame.minX-size.width-12
            let x = left >= visible.minX ? left : anchor.frame.maxX+12
            tool.setFrameOrigin(NSPoint(x: clamp(x,visible.minX+8,visible.maxX-size.width-8),
                                        y: clamp(anchor.frame.minY,visible.minY+8,visible.maxY-size.height-8)))
        }
        if let bubble {
            let size = bubble.frame.size
            let above = anchor.frame.maxY+8
            let y = above+size.height <= visible.maxY-8 ? above : anchor.frame.minY-size.height-8
            bubble.setFrameOrigin(NSPoint(x: clamp(anchor.frame.midX-size.width/2,visible.minX+8,visible.maxX-size.width-8),
                                          y: clamp(y,visible.minY+8,visible.maxY-size.height-8)))
        }
    }
    func shutdown() {
        dismissBubble(); tool?.close()
        if let anchorObserver { NotificationCenter.default.removeObserver(anchorObserver) }
        store.onSpeech = nil; store.onStatusChanged = nil
    }
}

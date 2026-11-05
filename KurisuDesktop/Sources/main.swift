import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let duplicates = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = duplicates.first {
            existing.activate(options: [])
            NSApplication.shared.terminate(nil)
            return
        }
        do {
            let model = try AppModel()
            self.model = model
            model.showSettings = { [weak self] in self?.openSettings() }
            model.menuFactory = { [weak self] in self?.makeMenu() ?? NSMenu() }
            setupStatusItem()
            if !UserDefaults.standard.bool(forKey: "hasOpened") {
                openSettings()
                UserDefaults.standard.set(true, forKey: "hasOpened")
                model.play(.wave)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Kurisu 无法启动"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(contentsOf: Bundle.main.url(forResource: "menubar", withExtension: "png")!) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            item.button?.image = image
        }
        item.button?.toolTip = "Kurisu · 像素桌宠"
        item.button?.setAccessibilityLabel("Kurisu 桌宠菜单")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    private func action(_ title: String, selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    private func populate(_ menu: NSMenu) {
        guard let model else { return }
        menu.removeAllItems()
        let status = NSMenuItem(title: "Kurisu · \(model.activity)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(action("随手工具…", selector: #selector(openTools)))
        menu.addItem(action("设置…", selector: #selector(openSettings), key: ","))
        menu.addItem(action(model.paused ? "继续陪伴" : "暂停陪伴", selector: #selector(togglePause)))
        menu.addItem(action(model.hidden ? "显示桌宠" : "隐藏桌宠", selector: #selector(toggleHidden)))
        menu.addItem(action("回到屏幕右下角", selector: #selector(resetPosition)))
        let sizes = NSMenuItem(title: "宠物大小", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (name, value) in [("小", 144), ("标准", 192), ("大", 288)] {
            let item = action(name, selector: #selector(changeSize(_:)))
            item.tag = value
            item.state = Int(model.size) == value ? .on : .off
            sizeMenu.addItem(item)
        }
        sizes.submenu = sizeMenu
        menu.addItem(sizes)
        let poses = NSMenuItem(title: "看看她的动作", action: nil, keyEquivalent: "")
        let poseMenu = NSMenu()
        let laptopPreview = action("坐在桌前打字", selector: #selector(previewLaptop))
        laptopPreview.isEnabled = !model.paused
        poseMenu.addItem(laptopPreview)
        poseMenu.addItem(.separator())
        for pose in PetPose.allCases {
            let item = action(pose.title, selector: #selector(previewPose(_:)))
            item.tag = pose.rawValue
            item.isEnabled = !model.paused
            poseMenu.addItem(item)
        }
        poses.submenu = poseMenu
        menu.addItem(poses)
        menu.addItem(.separator())
        menu.addItem(action("退出 Kurisu", selector: #selector(quit), key: "q"))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu)
        return menu
    }

    @objc func openSettings() {
        guard let model else { return }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 684, height: 680),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Kurisu · 桌面搭档"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePause() { model?.togglePause() }
    @objc private func openTools() { model?.utilityWindows?.showTools() }
    @objc private func toggleHidden() { model?.toggleHidden() }
    @objc private func resetPosition() { model?.resetPosition() }
    @objc private func previewLaptop() { model?.previewLaptop() }
    @objc private func changeSize(_ sender: NSMenuItem) { model?.size = Double(sender.tag) }
    @objc private func previewPose(_ sender: NSMenuItem) {
        if let pose = PetPose(rawValue: sender.tag) { model?.play(pose) }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import AppKit
import Combine
import ServiceManagement

final class AppModel: ObservableObject {
    @Published var paused = false
    @Published var hidden = false
    @Published var monitoring = false
    @Published var permissionGranted = false
    @Published var secureInputActive = false
    @Published var keyboardFeedback = "尚未收到键盘活动"
    @Published var laptopPreviewFrame: Int?
    @Published var activity = "待机"
    @Published var size = UserDefaults.standard.object(forKey: "petSize") as? Double ?? 192 {
        didSet {
            UserDefaults.standard.set(size, forKey: "petSize")
            resizePet()
            savePosition()
        }
    }
    @Published var reactsToTyping = UserDefaults.standard.object(forKey: "typing") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(reactsToTyping, forKey: "typing")
            if !reactsToTyping { keyTimes.removeAll(); lastKey = -.infinity }
        }
    }
    @Published var reactsToMouse = UserDefaults.standard.object(forKey: "mouse") as? Bool ?? true {
        didSet { UserDefaults.standard.set(reactsToMouse, forKey: "mouse") }
    }
    @Published var reducedMotion = UserDefaults.standard.bool(forKey: "stillMode") {
        didSet { UserDefaults.standard.set(reducedMotion, forKey: "stillMode") }
    }
    @Published var startupStatus = "未开启"
    @Published var startupEnabled = false
    @Published var message = ""

    let atlas: SpriteAtlas
    let input = InputMonitor()
    let utilities = UtilityStore()
    private(set) var utilityWindows: UtilityWindows?
    let panel: CompanionPanel
    let pet: PetView
    var showSettings: (() -> Void)?
    var menuFactory: (() -> NSMenu)?
    private var timer: Timer?
    private var lastActivity = ProcessInfo.processInfo.systemUptime
    private var lastKey: TimeInterval = -.infinity
    private var lastKeyboardActivity: TimeInterval = -.infinity
    private var keyTimes: [TimeInterval] = []
    private var lastMouse = NSEvent.mouseLocation
    private var lastMouseReaction: TimeInterval = -.infinity
    private var poseStarted = ProcessInfo.processInfo.systemUptime
    private var forcedPose: PetPose?
    private var forcedUntil: TimeInterval = 0
    private var dragging = false
    private var dragPose: PetPose = .runRight
    private var suspended = false
    private var wasNear = false
    private var lastPermissionPoll: TimeInterval = 0
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var alphaMaps: [PetPose: [NSBitmapImageRep]] = [:]
    private var hasRestoredPosition = false
    private var laptopAnimation = LaptopAnimation()
    private var laptopAlphaMaps: [NSBitmapImageRep] = []
    private var laptopPreviewStarted: TimeInterval = -.infinity

    var motionIsReduced: Bool {
        reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init() throws {
        atlas = try SpriteAtlas()
        pet = PetView(atlas: atlas)
        panel = CompanionPanel(contentRect: pet.frame,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        if size < 96 || size > 288 { size = 192 }
        panel.contentView = pet
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.title = "Kurisu 桌宠"
        for pose in PetPose.allCases {
            alphaMaps[pose] = (0..<pose.frameCount).map { NSBitmapImageRep(cgImage: atlas.image(pose, frame: $0)) }
        }
        laptopAlphaMaps = (0..<SpriteAtlas.laptopFrameCount).map {
            NSBitmapImageRep(cgImage: atlas.laptopImage(frame: $0))
        }
        resizePet()
        restorePosition()
        hasRestoredPosition = true
        savePosition()
        utilityWindows = UtilityWindows(store: utilities, anchor: panel)
        pet.onTap = { [weak self] in
            guard let self else { return }
            self.play(.happy)
            self.utilityWindows?.toggleTools()
        }
        pet.onDrop = { [weak self] board in
            guard let self else { return false }
            let accepted = self.utilities.acceptPasteboard(board)
            if accepted { self.utilityWindows?.showTools(tab: .shelf) }
            return accepted
        }
        pet.onDragChanged = { [weak self] dragging in
            guard let self else { return }
            self.dragging = dragging
            if dragging { self.utilityWindows?.cancelHover() }
            self.lastActivity = ProcessInfo.processInfo.systemUptime
            if !dragging { self.clampToScreen(); self.play(.wave) }
        }
        pet.onDragMoved = { [weak self] horizontalStep in
            guard let self else { return }
            // Latest movement, not displacement from the pickup point.
            if horizontalStep < -1 { self.dragPose = .runLeft }
            else if horizontalStep > 1 { self.dragPose = .runRight }
            self.tick()
        }
        pet.onPositionSaved = { [weak self] in self?.savePosition() }
        pet.makeMenu = { [weak self] in self?.menuFactory?() ?? NSMenu() }
        input.onActivity = { [weak self] type in self?.received(type) }
        input.onKeyboardActivity = { [weak self] count in self?.receivedKeyboard(count: count) }
        input.onAvailabilityChanged = { [weak self] available in self?.monitoring = available }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.clampToScreen(); self?.savePosition() })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshPermission() })
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.suspend() })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.resume() })
        refreshPermission()
        refreshStartup()
        panel.orderFrontRegardless()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.015
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func received(_ type: CGEventType) {
        guard !paused, !suspended else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastActivity = now
        if type != .keyDown && reactsToMouse && now - lastMouseReaction > 2 {
            // Interactions on the pet itself have their own click/drag behavior.
            if !panel.frame.contains(NSEvent.mouseLocation) {
                forcedPose = type == .scrollWheel ? .think : .curious
                forcedUntil = now + 0.8
                lastMouseReaction = now
            }
        }
    }

    private func receivedKeyboard(count: Int) {
        guard !paused, !suspended else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastActivity = now
        lastKeyboardActivity = now
        keyboardFeedback = "刚刚收到键盘活动"
        guard reactsToTyping else { return }
        lastKey = now
        laptopPreviewStarted = -.infinity
        keyTimes.removeAll { now - $0 > 1 }
        keyTimes.append(contentsOf: repeatElement(now, count: min(count, max(0, 80 - keyTimes.count))))
        // A recent click/wave must not hide the first second of real typing.
        forcedPose = nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionPoll > 2 {
            lastPermissionPoll = now
            refreshPermission()
            refreshStartup()
        }
        input.pollKeyboardActivity()
        if secureInputActive != input.secureInputActive {
            secureInputActive = input.secureInputActive
        }
        if secureInputActive {
            keyTimes.removeAll()
            lastKey = -.infinity
        } else if lastKeyboardActivity.isFinite && now - lastKeyboardActivity > 8 && keyboardFeedback != "已收到过键盘活动" {
            keyboardFeedback = "已收到过键盘活动"
        }
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 2 {
            lastActivity = now
            lastMouse = mouse
        }
        keyTimes.removeAll { now - $0 > 1 }
        let near = panel.frame.insetBy(dx: -24, dy: -24).contains(mouse)
        if reactsToMouse && near && !wasNear && !paused && now - lastMouseReaction > 3 {
            forcedPose = .curious
            forcedUntil = now + 1.4
            lastMouseReaction = now
        }
        wasNear = near

        let typing = !paused && reactsToTyping && now - lastKey < 1.1
        let previewAge = now - laptopPreviewStarted
        let preview = previewAge >= 0 && previewAge < 5.2
        let laptop = laptopAnimation.update(
            now: now,
            typing: typing || (preview && previewAge < 3.4),
            keepOpen: (reactsToTyping && now - lastKey < 3.2) || preview,
            fast: keyTimes.count >= 6,
            enabled: !paused && !dragging,
            reducedMotion: motionIsReduced
        )
        let nextPose: PetPose
        let label: String
        if paused { nextPose = .idle; label = "已暂停" }
        else if dragging { nextPose = dragPose; label = dragPose == .runLeft ? "向左移动" : "向右移动" }
        else if let laptop {
            nextPose = .idle
            label = laptop.phase == .typing && keyTimes.count >= 6 ? "飞快敲键中" : laptop.phase.title
        }
        else if let forcedPose, now < forcedUntil { nextPose = forcedPose; label = forcedPose.title }
        else if now - lastActivity > 90 { nextPose = .sleep; label = "坐着休息" }
        else { nextPose = .idle; label = "待机" }
        if activity != label { activity = label }
        if pet.pose != nextPose { pet.pose = nextPose; poseStarted = now }
        pet.spriteVerticalOffset = 0
        if nextPose == .sleep {
            let rest = RestAnimation.sample(elapsed: now - poseStarted, reducedMotion: motionIsReduced)
            pet.animationFrame = rest.frame
            pet.spriteVerticalOffset = rest.verticalOffset
            if forcedPose != .sleep {
                let restLabel = rest.isSettled ? "坐着休息" : "坐下来歇歇"
                if activity != restLabel { activity = restLabel }
            }
        } else {
            pet.animationFrame = paused || motionIsReduced ? 0 : Int((now - poseStarted) / 0.18)
        }
        pet.laptopFrame = laptop?.imageIndex
        if laptopPreviewFrame != pet.laptopFrame { laptopPreviewFrame = pet.laptopFrame }
        updateClickThrough(at: mouse)
        utilityWindows?.updateHover(
            at: mouse,
            onPet: panel.frame.contains(mouse) && !panel.ignoresMouseEvents,
            interacting: dragging || pet.dropActive || NSEvent.pressedMouseButtons != 0)
        if !hidden { pet.needsDisplay = true }
    }

    private func updateClickThrough(at point: NSPoint) {
        if dragging || pet.dropActive { panel.ignoresMouseEvents = false; return }
        // An external file/link drag should be able to enter the transparent
        // margin of the pet window, not only the current sprite's opaque pixels.
        if NSEvent.pressedMouseButtons & 1 != 0 &&
            panel.frame.insetBy(dx: -8, dy: -8).contains(point) {
            panel.ignoresMouseEvents = false
            return
        }
        guard panel.frame.contains(point) else { panel.ignoresMouseEvents = true; return }
        let factor = panel.frame.width / 192
        let x = Int((point.x - panel.frame.minX) / factor)
        let y = (point.y - panel.frame.minY) / factor
        let imageY = 207 - Int(y - 16 - pet.spriteVerticalOffset)
        if let laptopFrame = pet.laptopFrame {
            guard x >= 0, x < 192, imageY >= 0, imageY < 208 else {
                panel.ignoresMouseEvents = true
                return
            }
            let pixel = laptopAlphaMaps[laptopFrame].colorAt(x: x, y: imageY)
            panel.ignoresMouseEvents = (pixel?.alphaComponent ?? 0) < 0.12
            return
        }
        guard x >= 0, x < 192, imageY >= 0, imageY < 208,
              let frames = alphaMaps[pet.pose] else { panel.ignoresMouseEvents = true; return }
        let pixel = frames[pet.animationFrame % frames.count].colorAt(x: x, y: imageY)
        panel.ignoresMouseEvents = (pixel?.alphaComponent ?? 0) < 0.12
    }

    func play(_ pose: PetPose) {
        guard !paused else { return }
        laptopPreviewStarted = -.infinity
        laptopAnimation.reset()
        // Explicit reactions take over from previous typing; fresh keys can
        // still interrupt them immediately through receivedKeyboard(count:).
        lastKey = -.infinity
        keyTimes.removeAll()
        forcedPose = pose
        forcedUntil = ProcessInfo.processInfo.systemUptime + (pose == .sleep ? 8 : 2.4)
        poseStarted = ProcessInfo.processInfo.systemUptime
        lastActivity = ProcessInfo.processInfo.systemUptime
        tick()
    }

    func previewLaptop() {
        guard !paused else { return }
        laptopPreviewStarted = ProcessInfo.processInfo.systemUptime
        laptopAnimation.reset()
        forcedPose = nil
        lastActivity = laptopPreviewStarted
        tick()
    }

    func togglePause() {
        paused.toggle()
        keyTimes.removeAll()
        lastKey = -.infinity
        forcedPose = nil
        laptopPreviewStarted = -.infinity
        laptopAnimation.reset()
        if paused { input.stop() }
        else { refreshPermission() }
        tick()
    }

    func toggleHidden() {
        hidden.toggle()
        utilityWindows?.setHidden(hidden)
        if hidden { panel.orderOut(nil) }
        else { clampToScreen(); panel.orderFrontRegardless() }
    }

    func resetPosition() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 32,
                                     y: screen.visibleFrame.minY + 24))
        savePosition()
        if hidden { toggleHidden() }
    }

    private func resizePet() {
        let width = min(288, max(96, size == 0 ? 192 : size))
        let origin = panel.frame.origin
        let newSize = NSSize(width: width, height: width * 224 / 192)
        panel.setFrame(NSRect(origin: origin, size: newSize), display: true)
        pet.frame = NSRect(origin: .zero, size: newSize)
        clampToScreen()
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "petX") != nil {
            panel.setFrameOrigin(NSPoint(x: defaults.double(forKey: "petX"),
                                         y: defaults.double(forKey: "petY")))
            clampToScreen()
        } else { resetPosition() }
    }

    private func savePosition() {
        guard hasRestoredPosition else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "petX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "petY")
    }

    private func clampToScreen() {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, frame.minX), max(frame.minX, frame.maxX - panel.frame.width))
        origin.y = min(max(origin.y, frame.minY), max(frame.minY, frame.maxY - panel.frame.height))
        panel.setFrameOrigin(origin)
    }

    func refreshPermission() {
        permissionGranted = input.hasPermission
        if permissionGranted && !paused && !suspended {
            monitoring = input.startIfAllowed()
        } else { input.stop(); monitoring = false }
    }

    func enableInput() {
        input.requestPermission()
        refreshPermission()
        if !permissionGranted { openPrivacySettings() }
    }

    func reconnectInput() {
        input.stop()
        lastKeyboardActivity = -.infinity
        keyboardFeedback = "尚未收到键盘活动"
        refreshPermission()
    }

    func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshStartup() {
        let status = SMAppService.mainApp.status
        startupEnabled = status == .enabled || status == .requiresApproval
        switch status {
        case .enabled: startupStatus = "已开启"
        case .requiresApproval: startupStatus = "等待系统批准"
        case .notFound: startupStatus = "尚未登记到系统；开启时将尝试注册"
        default: startupStatus = "未开启"
        }
    }

    func setStartup(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = ""
        } catch {
            message = "无法更改登录启动：\(error.localizedDescription)"
        }
        refreshStartup()
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func suspend() {
        utilityWindows?.cancelHover()
        suspended = true
        input.stop()
        timer?.invalidate()
        keyTimes.removeAll()
        lastKey = -.infinity
        laptopPreviewStarted = -.infinity
        laptopAnimation.reset()
    }

    func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func resume() {
        suspended = false
        lastActivity = ProcessInfo.processInfo.systemUptime
        forcedPose = nil
        refreshPermission()
        clampToScreen()
        startTimer()
    }

    func shutdown() {
        utilityWindows?.shutdown()
        utilities.shutdown()
        timer?.invalidate()
        input.stop()
        savePosition()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}

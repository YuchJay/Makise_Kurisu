import AppKit
import CoreFoundation
import CoreGraphics

/// The companion never requests input access itself. The independently launched,
/// fixed-path input app owns permission and sends only classified activity.
final class InputMonitor {
    var onActivity: ((CGEventType) -> Void)?
    var onKeyboardActivity: ((Int) -> Void)?
    var onTypingInterrupted: (() -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?
    var onStatusChanged: (() -> Void)?
    private(set) var hasPermission = false
    private(set) var secureInputActive = false
    private(set) var statusText = "正在连接固定输入监听组件…"
    private(set) var authorizing = false
    private var listening = false
    private var desired = false
    private var installing = false
    private var launching = false
    private var stopped = false
    private var inFlight = false
    private var installation: InputAgentInstallation.Result?
    private var application: NSRunningApplication?
    private var lastLaunch: TimeInterval = -.infinity
    private var lastReply: TimeInterval = -.infinity
    private var lastInstallation: TimeInterval = -.infinity
    private var session = UUID().uuidString
    private var token = UUID().uuidString + UUID().uuidString
    private var permissionRequest: UUID?
    private var restartRequested = false
    private var epoch = 0
    private var authorizationRestarts = 0
    private var authorizationStarted: TimeInterval = -.infinity
    private var settingsWasFront = false
    private var lastRecovery: TimeInterval = -.infinity
    private var observer: NSObjectProtocol?
    private let queue = DispatchQueue(label: "local.kurisu.input.client", qos: .userInteractive)

    var isRunning: Bool {
        desired && listening && ProcessInfo.processInfo.systemUptime - lastReply < 2
    }

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, self.authorizing,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier == "com.apple.systempreferences" {
                self.settingsWasFront = true
            } else if self.settingsWasFront && !self.hasPermission {
                self.settingsWasFront = false
                self.scheduleAuthorizationRecovery()
            }
        }
    }

    @discardableResult
    func startIfAllowed() -> Bool {
        desired = true
        ensureAgent()
        return isRunning
    }

    private func ensureAgent() {
        guard !stopped else { return }
        if installation == nil {
            guard !installing, ProcessInfo.processInfo.systemUptime - lastInstallation > 3 else { return }
            installing = true
            lastInstallation = ProcessInfo.processInfo.systemUptime
            setStatus("正在准备固定输入监听组件…")
            queue.async { [weak self] in
                let result = Result { try InputAgentInstallation.prepare() }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.installing = false
                    guard !self.stopped else { return }
                    switch result {
                    case .success(let installation):
                        self.installation = installation
                        self.setStatus(installation.replaced
                            ? "监听组件已更新；如系统要求，请重新确认一次权限。"
                            : "正在连接输入监听组件…")
                        self.launch()
                    case .failure(let error):
                        self.setStatus("无法准备输入监听组件：\(error.localizedDescription)")
                    }
                }
            }
        } else if application == nil || application?.isTerminated == true {
            launch()
        }
    }

    private func launch() {
        guard !launching, !stopped, let installation,
              ProcessInfo.processInfo.systemUptime - lastLaunch > 2 else { return }
        // Stop only the installed copy; never touch unrelated applications.
        for old in NSRunningApplication.runningApplications(withBundleIdentifier: InputAgentProtocol.identifier)
        where old.bundleURL?.standardizedFileURL == installation.url.standardizedFileURL {
            _ = old.terminate()
        }
        session = UUID().uuidString
        token = UUID().uuidString + UUID().uuidString
        lastReply = -.infinity
        listening = false
        epoch += 1
        launching = true
        lastLaunch = ProcessInfo.processInfo.systemUptime
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--port", portName, "--token", token,
                                   "--owner", String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: installation.url, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.launching = false
                if self.stopped { _ = app?.terminate(); return }
                if let error {
                    self.setStatus("输入监听组件启动失败：\(error.localizedDescription)")
                } else {
                    self.application = app
                    self.setStatus("正在等待输入监听组件连接…")
                }
            }
        }
    }

    private var portName: String { "local.kurisu.input.\(session)" }

    func pollKeyboardActivity() {
        guard !stopped else { return }
        ensureAgent()
        guard !inFlight, !launching, application?.isTerminated == false,
              let installation else { return }
        if !isRunning && listening {
            listening = false; onAvailabilityChanged?(false); onTypingInterrupted?()
        }
        let requestID = permissionRequest
        let restart = restartRequested
        let request = InputAgentRequest(version: InputAgentProtocol.version, token: token,
                                        enabled: desired, requestPermission: requestID != nil,
                                        restart: restart, quit: false)
        guard let data = try? JSONEncoder().encode(request) else { return }
        let name = portName
        let generation = epoch
        inFlight = true
        queue.async { [weak self] in
            var result: InputAgentReply?
            if let remote = CFMessagePortCreateRemote(kCFAllocatorDefault, name as CFString) {
                var reply: Unmanaged<CFData>?
                let status = CFMessagePortSendRequest(remote, 1, data as CFData,
                                                      0.1, 0.15, CFRunLoopMode.defaultMode.rawValue, &reply)
                if status == kCFMessagePortSuccess, let reply {
                    result = try? JSONDecoder().decode(InputAgentReply.self, from: reply.takeRetainedValue() as Data)
                }
            }
            let received = result
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                guard !self.stopped, generation == self.epoch else { return }
                guard let reply = received, reply.token == request.token,
                      reply.version == InputAgentProtocol.version, reply.buildID == installation.buildID else {
                    self.connectionLost()
                    return
                }
                self.lastReply = ProcessInfo.processInfo.systemUptime
                if self.permissionRequest == requestID { self.permissionRequest = nil }
                if restart {
                    self.restartRequested = false
                    self.restartApplication()
                    return
                }
                self.hasPermission = reply.permission
                self.secureInputActive = reply.secureInput
                self.listening = reply.listening
                if reply.permission { self.authorizing = false }
                self.updateStatus(activeSession: reply.activeSession)
                self.onAvailabilityChanged?(self.isRunning)
                // A pause/reconnect may have happened while this request was in flight.
                guard self.desired, request.enabled else { return }
                if reply.interrupted || !reply.listening || reply.secureInput || !reply.activeSession {
                    self.onTypingInterrupted?()
                }
                if reply.keyboardActivity { self.onActivity?(.keyDown) }
                if let raw = reply.mouseEvent, let type = CGEventType(rawValue: raw) { self.onActivity?(type) }
                if reply.listening && reply.activeSession && !reply.secureInput && reply.typingCount > 0 {
                    self.onKeyboardActivity?(min(80, reply.typingCount))
                }
            }
        }
    }

    private func updateStatus(activeSession: Bool) {
        if !desired { setStatus("监听已暂停。") }
        else if !activeSession { setStatus("锁屏、睡眠或熄屏期间暂停监听。") }
        else if hasPermission && listening { setStatus("固定监听组件已连接，后续普通桌宠更新会复用它。") }
        else if hasPermission {
            setStatus("系统已授权，正在自动重新连接…")
            if ProcessInfo.processInfo.systemUptime - lastRecovery > 8 {
                lastRecovery = ProcessInfo.processInfo.systemUptime
                restartRequested = true
            }
        } else if authorizing {
            setStatus("请在系统“输入监控”中允许“Kurisu 输入监听”，完成后会自动连接。")
        } else {
            setStatus("点击“我授权”，在系统中允许“Kurisu 输入监听”即可。")
        }
    }

    private func connectionLost() {
        listening = false; secureInputActive = false
        onAvailabilityChanged?(false)
        onTypingInterrupted?()
        if authorizing, ProcessInfo.processInfo.systemUptime - authorizationStarted < 120,
           application?.isTerminated == false {
            // The system consent dialog may temporarily block the helper's main
            // run loop. Do not kill it while the user is answering that dialog.
            setStatus("正在等待系统授权；完成确认后会自动连接。")
            return
        }
        let age = ProcessInfo.processInfo.systemUptime - max(lastLaunch, lastReply)
        if age > 3 {
            setStatus("输入监听连接中断，正在自动恢复…")
            restartApplication()
        }
    }

    private func restartApplication() {
        epoch += 1
        _ = application?.terminate()
        application = nil
        listening = false
        lastReply = -.infinity
        onTypingInterrupted?()
        onAvailabilityChanged?(false)
        // The next render tick reconnects with a fresh process and fresh TCC state.
    }

    private func scheduleAuthorizationRecovery() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - authorizationStarted < 300, now - lastRecovery > 2,
              authorizationRestarts < 3 else { return }
        authorizationRestarts += 1
        lastRecovery = now
        restartRequested = true
    }

    func requestPermission() {
        desired = true
        authorizing = true
        authorizationStarted = ProcessInfo.processInfo.systemUptime
        authorizationRestarts = 0
        permissionRequest = UUID()
        setStatus("正在请求系统输入监控授权…")
        ensureAgent()
        pollKeyboardActivity()
    }

    func revealPermissionApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([installation?.url ?? InputAgentInstallation.installedURL])
    }

    func reconnect() {
        desired = true
        restartRequested = true
        ensureAgent()
        pollKeyboardActivity()
    }

    func stop() {
        desired = false
        epoch += 1
        listening = false
        secureInputActive = false
        onTypingInterrupted?()
        onAvailabilityChanged?(false)
        // Remain connected so pause explicitly removes the helper's event tap.
        pollKeyboardActivity()
    }

    func shutdown() {
        stopped = true
        desired = false
        _ = application?.terminate()
        application = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }

    private func setStatus(_ text: String) {
        guard statusText != text else { return }
        statusText = text
        onStatusChanged?()
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}

import AppKit
import CoreFoundation
import Darwin

/// Launched independently by Launch Services so the stable app owns its TCC
/// identity. It has no login item, network listener, event log or text access.
final class InputAgentDelegate: NSObject, NSApplicationDelegate {
    private let monitor = KeyboardEventMonitor()
    private var port: CFMessagePort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var token = ""
    private var owner: pid_t = 0
    private var lastContact = ProcessInfo.processInfo.systemUptime
    private var lastRefresh: TimeInterval = 0
    private var wantsInput = false
    private var sessionActive = true
    private var displayAwake = true
    private var keyboardActivity = false
    private var typingCount = 0
    private var interrupted = false
    private var mouseEvent: UInt32?
    private var requesting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        func argument(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        guard let name = argument("--port"), name.hasPrefix("local.kurisu.input."),
              let secret = argument("--token"), secret.count >= 32,
              let ownerString = argument("--owner"), let ownerPID = Int32(ownerString),
              ownerPID > 0 else { NSApp.terminate(nil); return }
        token = secret
        owner = ownerPID
        monitor.onActivity = { [weak self] type in
            if type == .keyDown { self?.keyboardActivity = true }
            else { self?.mouseEvent = type.rawValue }
        }
        monitor.onKeyboardActivity = { [weak self] count in
            guard let self else { return }
            self.typingCount = min(80, self.typingCount + count)
        }
        monitor.onTypingInterrupted = { [weak self] in
            self?.typingCount = 0
            self?.interrupted = true
        }
        var context = CFMessagePortContext(version: 0,
                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        var freeInfo = DarwinBoolean(false)
        port = CFMessagePortCreateLocal(kCFAllocatorDefault, name as CFString,
                                       { _, _, data, context in
            guard let data, let context else { return nil }
            let agent = Unmanaged<InputAgentDelegate>.fromOpaque(context).takeUnretainedValue()
            guard let reply = agent.receive(data as Data) else { return nil }
            return Unmanaged.passRetained(reply as CFData)
        }, &context, &freeInfo)
        guard let port, !freeInfo.boolValue,
              let source = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            NSApp.terminate(nil); return
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        observeSession()
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func receive(_ data: Data) -> Data? {
        guard data.count < 4096,
              let request = try? JSONDecoder().decode(InputAgentRequest.self, from: data),
              request.version == InputAgentProtocol.version, request.token == token else { return nil }
        lastContact = ProcessInfo.processInfo.systemUptime
        if wantsInput != request.enabled {
            wantsInput = request.enabled
            refresh()
        }
        monitor.pollKeyboardActivity()
        let reply = InputAgentReply(
            version: InputAgentProtocol.version, token: token,
            buildID: Bundle.main.object(forInfoDictionaryKey: "InputAgentBuildID") as? String ?? "",
            permission: monitor.hasPermission, listening: monitor.isRunning,
            secureInput: monitor.secureInputActive,
            activeSession: sessionActive && displayAwake,
            keyboardActivity: keyboardActivity, typingCount: typingCount,
            interrupted: interrupted, mouseEvent: mouseEvent)
        keyboardActivity = false; typingCount = 0; interrupted = false; mouseEvent = nil
        if request.requestPermission && !requesting {
            requesting = true
            // Reply before showing system UI: never block the companion's IPC.
            DispatchQueue.main.async { [weak self] in self?.authorize() }
        }
        if request.restart || request.quit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.terminate(nil) }
        }
        return try? JSONEncoder().encode(reply)
    }

    private func authorize() {
        NSApp.activate(ignoringOtherApps: true)
        monitor.requestPermission()
        refresh()
        if !monitor.hasPermission,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        requesting = false
    }

    private func refresh() {
        if wantsInput && sessionActive && displayAwake {
            _ = monitor.startIfAllowed()
        } else { monitor.stop() }
        lastRefresh = ProcessInfo.processInfo.systemUptime
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let age = now - lastContact
        // Stop listening quickly after a stalled/crashed/sleeping owner.
        if age > 3 || kill(owner, 0) != 0 {
            if wantsInput { wantsInput = false; monitor.stop() }
            if age > 30 || kill(owner, 0) != 0 { NSApp.terminate(nil) }
            return
        }
        if now - lastRefresh >= 1 { refresh() }
    }

    private func observeSession() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sessionActive = false; self?.refresh()
            })
        }
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sessionActive = true; self?.refresh()
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            self?.displayAwake = false; self?.refresh()
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            self?.displayAwake = true; self?.refresh()
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        timer?.invalidate()
        if let port { CFMessagePortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = InputAgentDelegate()
app.delegate = delegate
app.run()

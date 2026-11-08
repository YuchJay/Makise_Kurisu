import AppKit
import Carbon
import CoreGraphics

/// No input text is extracted or saved. The typing filter temporarily tracks
/// held keys and timings to separate character input from shortcuts.
final class KeyboardEventMonitor {
    var onActivity: ((CGEventType) -> Void)?
    var onKeyboardActivity: ((Int) -> Void)?
    var onTypingInterrupted: (() -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sampling = false
    private var pendingKeyEvents = 0
    private var typingFilter = TypingActivityFilter()
    private var lastSessionCount: UInt32 = 0
    private var lastHardwareCount: UInt32 = 0
    private(set) var secureInputActive = false

    var hasPermission: Bool { CGPreflightListenEventAccess() }
    var isRunning: Bool {
        guard sampling, let tap, CFMachPortIsValid(tap) else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func startIfAllowed() -> Bool {
        guard hasPermission else {
            stop()
            return false
        }
        if !sampling {
            resetKeyboardBaseline()
            sampling = true
        }
        if let tap, CFMachPortIsValid(tap) {
            if !CGEvent.tapIsEnabled(tap: tap) {
                resetTyping()
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            let running = isRunning
            onAvailabilityChanged?(running)
            return running
        }
        removeTap()
        resetTyping()
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .scrollWheel
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.resetTyping()
                if let tap = monitor.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                monitor.onAvailabilityChanged?(monitor.isRunning)
            } else if type == .keyDown || type == .keyUp || type == .flagsChanged {
                monitor.receivedKeyboardEvent(type, event: event)
            } else {
                monitor.resetTyping()
                monitor.onActivity?(type)
            }
            return Unmanaged.passUnretained(event)
        }
        // Alternative passive placements. Aggregate counters can still mark
        // general activity but must never bypass per-event typing classification.
        for location in [CGEventTapLocation.cgSessionEventTap, .cgAnnotatedSessionEventTap] {
            guard let port = CGEvent.tapCreate(tap: location,
                                              place: .headInsertEventTap,
                                              options: .listenOnly,
                                              eventsOfInterest: mask,
                                              callback: callback,
                                              userInfo: Unmanaged.passUnretained(self).toOpaque()) else { continue }
            guard let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
                CFMachPortInvalidate(port)
                continue
            }
            tap = port
            source = runSource
            CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            break
        }
        let running = isRunning
        onAvailabilityChanged?(running)
        return running
    }

    private func receivedKeyboardEvent(_ type: CGEventType, event: CGEvent) {
        if type != .keyUp { onActivity?(.keyDown) }
        secureInputActive = IsSecureEventInputEnabled()
        guard !secureInputActive else { resetTyping(); return }
        switch typingFilter.process(type, event: event,
                                    now: ProcessInfo.processInfo.systemUptime) {
        case .none: break
        case .typing(let count):
            pendingKeyEvents = min(80, pendingKeyEvents + count)
        case .interrupt:
            pendingKeyEvents = 0
            onTypingInterrupted?()
        }
    }

    private func resetTyping() {
        pendingKeyEvents = 0
        typingFilter.reset()
        onTypingInterrupted?()
    }

    /// Only classified event callbacks drive typing. Aggregate counters do not
    /// contain enough detail to distinguish a shortcut or navigation key.
    func pollKeyboardActivity() {
        guard sampling else { return }
        guard hasPermission else { stop(); return }
        secureInputActive = IsSecureEventInputEnabled()
        let session = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        let hardware = CGEventSource.counterForEventType(.hidSystemState, eventType: .keyDown)
        let sessionDelta = session &- lastSessionCount
        let hardwareDelta = hardware &- lastHardwareCount
        lastSessionCount = session
        lastHardwareCount = hardware
        guard !secureInputActive else { resetTyping(); return }
        let delta = max(sessionDelta < 256 ? Int(sessionDelta) : 0,
                        hardwareDelta < 256 ? Int(hardwareDelta) : 0)
        if delta > 0 { onActivity?(.keyDown) }
        guard isRunning else { resetTyping(); onAvailabilityChanged?(false); return }
        let count = pendingKeyEvents
        pendingKeyEvents = 0
        if count > 0 { onKeyboardActivity?(count) }
    }

    private func resetKeyboardBaseline() {
        resetTyping()
        lastSessionCount = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        lastHardwareCount = CGEventSource.counterForEventType(.hidSystemState, eventType: .keyDown)
        secureInputActive = IsSecureEventInputEnabled()
    }

    func requestPermission() {
        _ = CGRequestListenEventAccess()
        _ = startIfAllowed()
    }

    private func removeTap() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    func stop() {
        removeTap()
        sampling = false
        resetTyping()
        secureInputActive = false
        onAvailabilityChanged?(false)
    }

    deinit { stop() }
}

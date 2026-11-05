import AppKit
import Carbon
import CoreGraphics

/// Activity only: no text, key codes or event objects are retained.
final class InputMonitor {
    var onActivity: ((CGEventType) -> Void)?
    var onKeyboardActivity: ((Int) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sampling = false
    private var pendingKeyEvents = 0
    private var lastSessionCount: UInt32 = 0
    private var lastHardwareCount: UInt32 = 0
    private(set) var secureInputActive = false

    var hasPermission: Bool { CGPreflightListenEventAccess() }
    var isRunning: Bool { sampling }

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
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return true
        }
        removeTap()
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else if type == .keyDown {
                monitor.pendingKeyEvents = min(80, monitor.pendingKeyEvents + 1)
            } else {
                monitor.onActivity?(type)
            }
            return Unmanaged.passUnretained(event)
        }
        // Alternative passive placements; the counter sampler remains available
        // when no tap can attach or a tap receives no keyboard callbacks.
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
        onAvailabilityChanged?(true)
        return true
    }

    /// Drained at render cadence. Overlapping sources are combined, not summed;
    /// the result estimates animation intensity, not an exact typing statistic.
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
        let callbackCount = pendingKeyEvents
        pendingKeyEvents = 0
        // Respect secure input even if an aggregate activity counter advances.
        guard !secureInputActive else { return }
        let delta = max(sessionDelta < 256 ? Int(sessionDelta) : 0,
                        hardwareDelta < 256 ? Int(hardwareDelta) : 0)
        let count = min(80, max(callbackCount, delta))
        if count > 0 { onKeyboardActivity?(count) }
    }

    private func resetKeyboardBaseline() {
        pendingKeyEvents = 0
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
        pendingKeyEvents = 0
        secureInputActive = false
        onAvailabilityChanged?(false)
    }

    deinit { stop() }
}

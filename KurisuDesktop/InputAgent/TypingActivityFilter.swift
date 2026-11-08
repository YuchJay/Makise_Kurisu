import CoreGraphics
import Foundation

/// Classifies physical input without extracting text. Only currently held key
/// codes and short-lived timing state are retained; nothing is logged or saved.
struct TypingActivityFilter {
    enum Decision {
        case none
        case typing(Int)
        case interrupt
    }

    private static let shortcutModifiers: CGEventFlags = [
        .maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn, .maskHelp
    ]
    // macOS virtual key positions for letters, numbers and punctuation, plus
    // ISO/JIS punctuation and numeric keypad characters. No Unicode is read.
    private static let characterKeys: Set<Int64> =
        Set(Int64(0)...Int64(50)).subtracting([36, 48, 49])
        .union([65, 67, 69, 75, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89,
                91, 92, 93, 94, 95])
    // Space, Return and deletion can continue established typing but cannot
    // start it. Tab is excluded because it commonly navigates between controls.
    private static let editingKeys: Set<Int64> = [36, 49, 51, 76, 117]
    private var heldKeys: Set<Int64> = []
    private var suppressedKeys: Set<Int64> = []
    private var candidateAt: TimeInterval?
    private var lastTypingAt: TimeInterval?
    private let confirmationWindow: TimeInterval = 0.8
    private let continuationWindow: TimeInterval = 1.1

    mutating func reset() {
        heldKeys.removeAll()
        suppressedKeys.removeAll()
        candidateAt = nil
        lastTypingAt = nil
    }

    private mutating func interrupt() -> Decision {
        candidateAt = nil
        lastTypingAt = nil
        return .interrupt
    }

    mutating func process(_ type: CGEventType, event: CGEvent,
                          now: TimeInterval) -> Decision {
        let shortcut = !event.flags.intersection(Self.shortcutModifiers).isEmpty
        if type == .flagsChanged {
            guard shortcut else { return .none } // Shift and Caps Lock are valid.
            // A held letter must be released before it can start typing again,
            // even if the shortcut modifier is released first.
            suppressedKeys.formUnion(heldKeys)
            return interrupt()
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            heldKeys.remove(key)
            suppressedKeys.remove(key)
            return .none
        }
        guard type == .keyDown else { return .none }
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let wasHeld = heldKeys.contains(key)
        heldKeys.insert(key)
        if shortcut {
            suppressedKeys.formUnion(heldKeys)
            return interrupt()
        }
        guard !suppressedKeys.contains(key) else { return interrupt() }
        let continuing = lastTypingAt.map { now - $0 <= continuationWindow } ?? false
        if Self.editingKeys.contains(key) {
            guard continuing, !repeating || wasHeld else { return interrupt() }
            lastTypingAt = now
            return .typing(1)
        }
        guard Self.characterKeys.contains(key) else { return interrupt() }
        if repeating {
            // A single held key must never satisfy the two-press confirmation.
            guard continuing, wasHeld else { return .none }
            lastTypingAt = now
            return .typing(1)
        }
        if continuing {
            lastTypingAt = now
            return .typing(1)
        }
        if let candidateAt, now - candidateAt <= confirmationWindow {
            self.candidateAt = nil
            lastTypingAt = now
            return .typing(2)
        }
        candidateAt = now
        return .none
    }
}

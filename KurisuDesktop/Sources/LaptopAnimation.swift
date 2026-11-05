import Foundation

/// Reversible opening progress prevents a new key from restarting a full
/// opening sequence halfway through closing. No keyboard content is involved.
struct LaptopAnimation {
    enum Phase {
        case opening, typing, waiting, closing

        var title: String {
            switch self {
            case .opening: return "坐到电脑前"
            case .typing: return "坐在桌前打字"
            case .waiting: return "留着电脑等你"
            case .closing: return "收起电脑起身"
            }
        }
    }

    struct Sample {
        let imageIndex: Int
        let phase: Phase
    }

    private var openness: Double = 0
    private var lastUpdate: TimeInterval?
    private var motionTime: TimeInterval = 0
    private var wasTyping = false
    private let openingDuration: Double = 0.75
    private let closingDuration: Double = 0.80

    mutating func reset() {
        openness = 0
        lastUpdate = nil
        motionTime = 0
        wasTyping = false
    }

    mutating func update(now: TimeInterval, typing: Bool, keepOpen: Bool,
                         fast: Bool, enabled: Bool, reducedMotion: Bool) -> Sample? {
        guard enabled else { reset(); return nil }
        let dt = min(0.25, max(0, lastUpdate.map { now - $0 } ?? (1.0 / 24)))
        lastUpdate = now
        let wantsComputer = typing || keepOpen

        if reducedMotion {
            openness = wantsComputer ? 1 : 0
            return wantsComputer
                ? Sample(imageIndex: typing ? 16 : 32, phase: typing ? .typing : .waiting)
                : nil
        }
        openness = wantsComputer
            ? min(1, openness + dt / openingDuration)
            : max(0, openness - dt / closingDuration)

        if openness == 0 {
            motionTime = 0
            wasTyping = false
            return nil
        }
        if openness < 1 {
            if wantsComputer {
                return Sample(imageIndex: min(11, Int(openness * 12)), phase: .opening)
            }
            // Closing retraces the seating transition at the same progress,
            // including if typing resumes midway through returning to idle.
            return Sample(imageIndex: 48 + min(11, Int((1 - openness) * 12)), phase: .closing)
        }
        if typing != wasTyping {
            // Both loops begin and end in the same neutral hand/shoulder pose.
            motionTime = 0
            wasTyping = typing
        }
        motionTime += dt * (fast && typing ? 1.55 : 1)
        if typing {
            return Sample(imageIndex: 16 + Int(motionTime / 0.10) % 16, phase: .typing)
        }
        return Sample(imageIndex: 32 + Int(motionTime / 0.30) % 12, phase: .waiting)
    }
}

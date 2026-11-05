import Foundation

/// This row tells a story: 0–4 sit down, 5 sits, 6 lowers her head,
/// 7 stands up again. Resting must never wrap through frame 7 back to 0.
enum RestAnimation {
    struct Sample {
        let frame: Int
        let verticalOffset: CGFloat
        let isSettled: Bool
    }

    static func sample(elapsed: TimeInterval, reducedMotion: Bool) -> Sample {
        if reducedMotion {
            return Sample(frame: 5, verticalOffset: 0, isSettled: true)
        }
        let entryFrames = [0, 1, 2, 3, 4]
        let entryStep = 0.28
        let entryDuration = Double(entryFrames.count) * entryStep
        let time = max(0, elapsed)
        if time < entryDuration {
            let index = min(entryFrames.count - 1, Int(time / entryStep))
            return Sample(frame: entryFrames[index], verticalOffset: 0, isSettled: false)
        }
        let restingTime = time - entryDuration
        // One source-pixel breath and an occasional already-seated nod.
        let breath = restingTime.truncatingRemainder(dividingBy: 4.8)
        let nod = restingTime.truncatingRemainder(dividingBy: 11)
        return Sample(frame: nod >= 8.8 && nod < 10.1 ? 6 : 5,
                      verticalOffset: breath >= 1.8 && breath < 3.4 ? 1 : 0,
                      isSettled: true)
    }
}

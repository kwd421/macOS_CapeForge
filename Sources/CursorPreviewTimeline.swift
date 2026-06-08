import Foundation

enum CursorPreviewTimeline {
    static let startDate = Date(timeIntervalSinceReferenceDate: 0)
    static let minimumRefreshInterval: TimeInterval = 1.0 / 24.0

    static func refreshInterval(for animation: CursorAnimation) -> TimeInterval? {
        guard animation.frames.count > 1 else { return nil }
        let positiveDelays = animation.frames.map(\.delay).filter { $0 > 0 }
        guard let shortestDelay = positiveDelays.min() else { return nil }
        return max(shortestDelay, minimumRefreshInterval)
    }

    static func frameIndex(for animation: CursorAnimation, at date: Date) -> Int {
        guard animation.frames.count > 1 else { return 0 }
        let totalDuration = animation.frames.reduce(0.0) { partial, frame in
            partial + max(frame.delay, 0)
        }
        guard totalDuration > 0 else { return 0 }

        let rawElapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)
        let elapsed = rawElapsed >= 0 ? rawElapsed : rawElapsed + totalDuration
        var runningDuration = 0.0

        for (index, frame) in animation.frames.enumerated() {
            runningDuration += max(frame.delay, 0)
            if elapsed < runningDuration {
                return index
            }
        }

        return animation.frames.count - 1
    }
}

import Foundation
import SwiftData

enum CountdownStyle: String, CaseIterable, Identifiable {
    case classic, ring, matrix
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: "经典"
        case .ring: "环形"
        case .matrix: "矩阵"
        }
    }
}

@Model
final class Countdown {
    var title: String
    var totalDuration: Double
    var storedRemaining: Double
    var createdAt: Date
    var startedAt: Date?
    var isRunning: Bool
    var isCompleted: Bool
    var styleRawValue: String = CountdownStyle.classic.rawValue
    var isCapsule = false
    var targetDate: Date?

    init(title: String, duration: TimeInterval, style: CountdownStyle = .classic, isCapsule: Bool = false, targetDate: Date? = nil) {
        self.title = title
        self.totalDuration = duration
        self.storedRemaining = duration
        self.createdAt = .now
        self.startedAt = nil
        self.isRunning = false
        self.isCompleted = false
        self.styleRawValue = style.rawValue
        self.isCapsule = isCapsule
        self.targetDate = targetDate
    }

    var style: CountdownStyle {
        get { CountdownStyle(rawValue: styleRawValue) ?? .classic }
        set { styleRawValue = newValue.rawValue }
    }

    func remaining(at date: Date = .now) -> TimeInterval {
        if isCapsule {
            if isRunning, let targetDate { return max(0, targetDate.timeIntervalSince(date)) }
            return max(0, storedRemaining)
        }
        guard isRunning, let startedAt else { return max(0, storedRemaining) }
        return max(0, storedRemaining - date.timeIntervalSince(startedAt))
    }

    func start(at date: Date = .now) {
        guard !isCompleted, remaining(at: date) > 0 else { return }
        storedRemaining = remaining(at: date)
        if isCapsule { targetDate = date.addingTimeInterval(storedRemaining) }
        startedAt = date
        isRunning = true
    }

    func pause(at date: Date = .now) {
        guard isRunning else { return }
        storedRemaining = remaining(at: date)
        if isCapsule { targetDate = nil }
        startedAt = nil
        isRunning = false
        if storedRemaining <= 0 { isCompleted = true }
    }

    func reset() {
        isRunning = isCapsule
        startedAt = nil
        storedRemaining = totalDuration
        targetDate = isCapsule ? Date.now.addingTimeInterval(totalDuration) : nil
        isCompleted = false
    }

    func reconcile(at date: Date = .now) {
        guard isRunning, remaining(at: date) <= 0 else { return }
        storedRemaining = 0
        targetDate = nil
        startedAt = nil
        isRunning = false
        isCompleted = true
    }
}

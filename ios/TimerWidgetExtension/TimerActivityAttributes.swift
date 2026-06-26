import ActivityKit
import Foundation

/// Identical copy of ios/Runner/TimerActivityAttributes.swift.
/// Both files must exist and have the same struct layout so the host app
/// and the widget extension share the same ActivityAttributes type identity.
struct TimerActivityAttributes: ActivityAttributes {
    let workoutName: String
    let totalPhases: Int

    struct ContentState: Codable, Hashable {
        var phaseName: String
        var phaseType: String
        var phaseIndex: Int
        var phaseEndDate: Date
        var isPaused: Bool
        var pausedSecondsRemaining: Int
    }
}

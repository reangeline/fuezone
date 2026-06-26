import ActivityKit
import Foundation

/// ActivityAttributes for the Fuezone timer Live Activity.
/// This file must be added to BOTH the Runner target and the
/// TimerWidgetExtension target (identical copy, same type identity).
struct TimerActivityAttributes: ActivityAttributes {
    /// Static data — set at Activity.request(), never changes mid-session.
    let workoutName: String
    let totalPhases: Int

    /// Dynamic data — updated on every phase transition, pause, and resume.
    struct ContentState: Codable, Hashable {
        /// Current phase label ("Round 1", "Rest", "Sprint").
        var phaseName: String
        /// "work" | "rest" | "prepare" | "cooldown"
        var phaseType: String
        /// 0-based index of the current phase.
        var phaseIndex: Int
        /// Wall-clock time when the current phase ends.
        /// The widget uses Text(phaseEndDate, style: .timer) so the
        /// countdown runs natively without per-second Flutter updates.
        var phaseEndDate: Date
        /// True while the timer is paused.
        var isPaused: Bool
        /// Seconds remaining at the moment of pause (shown when isPaused).
        var pausedSecondsRemaining: Int
    }
}

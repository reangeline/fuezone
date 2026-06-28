import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Color helpers

private extension Color {
    static let fuezoneBackground = Color(red: 0.051, green: 0.051, blue: 0.059) // #0D0D0F
    static let fuezoneRed        = Color(red: 1.0,   green: 0.231, blue: 0.188) // #FF3B30
    static let fuezoneBlue       = Color(red: 0.196, green: 0.588, blue: 1.0)   // #3296FF
    static let fuezoneGreen      = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    static let fuezoneYellow     = Color(red: 1.0,   green: 0.800, blue: 0.0)   // #FFCC00
}

private func phaseColor(_ phaseType: String) -> Color {
    switch phaseType {
    case "rest":     return .fuezoneBlue
    case "prepare":  return .fuezoneYellow
    case "cooldown": return .fuezoneGreen
    default:         return .fuezoneRed   // work
    }
}

private func phaseIcon(_ phaseType: String) -> String {
    switch phaseType {
    case "rest":     return "pause.circle.fill"
    case "prepare":  return "bolt.fill"
    case "cooldown": return "wind"
    default:         return "flame.fill"  // work
    }
}

// MARK: - Countdown view

/// Shows a live countdown when running, or a static formatted time when paused.
private struct CountdownView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        if context.state.isPaused {
            Text(formattedTime(context.state.pausedSecondsRemaining))
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        } else {
            // distantPast as start keeps it constant across phases so only
            // phaseEndDate changes on updates — SwiftUI diffs one parameter
            // instead of two, making the countdown reset reliably.
            // countsDown:true clamps at 0:00 when the end date passes instead
            // of flipping to count-up (the original bug on the lock screen).
            // .id forces full view recreation on every phase change so the
            // system timer inside Text() resets rather than updating in-place.
            Text(timerInterval: Date.distantPast...context.state.phaseEndDate,
                 countsDown: true)
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .id(context.state.phaseIndex)
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Progress dots

private struct PhaseDots: View {
    let current: Int   // 0-based
    let total: Int
    let color: Color

    private let maxVisible = 12

    var body: some View {
        let visible = min(total, maxVisible)
        HStack(spacing: 4) {
            ForEach(0..<visible, id: \.self) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(i <= current ? color : color.opacity(0.25))
            }
            if total > maxVisible {
                Text("+\(total - maxVisible)")
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.5))
            }
        }
    }
}

// MARK: - Lock screen / banner view

private struct LockScreenView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        let color = phaseColor(context.state.phaseType)

        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Image(systemName: phaseIcon(context.state.phaseType))
                    .foregroundStyle(color)
                Text(context.attributes.workoutName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Spacer()
                if context.state.isPaused {
                    Label("Pausado", systemImage: "pause.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Phase name + countdown
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(context.state.phaseName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer()

                CountdownView(context: context)
            }

            // Progress dots
            PhaseDots(
                current: context.state.phaseIndex,
                total: context.attributes.totalPhases,
                color: color
            )
        }
        .padding(16)
        .background(Color.fuezoneBackground)
    }
}

// MARK: - Dynamic Island compact countdown

private struct CompactCountdown: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        if context.state.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Text(timerInterval: Date.distantPast...context.state.phaseEndDate,
                 countsDown: true)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 36)
                .id(context.state.phaseIndex)
        }
    }
}

// MARK: - Dynamic Island expanded view

private struct ExpandedView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        let color = phaseColor(context.state.phaseType)

        VStack(spacing: 8) {
            Text(context.state.phaseName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            CountdownView(context: context)
            PhaseDots(
                current: context.state.phaseIndex,
                total: context.attributes.totalPhases,
                color: color
            )
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Widget declaration

struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(context: context)
                }
            } compactLeading: {
                Image(systemName: phaseIcon(context.state.phaseType))
                    .foregroundStyle(phaseColor(context.state.phaseType))
            } compactTrailing: {
                CompactCountdown(context: context)
            } minimal: {
                Image(systemName: phaseIcon(context.state.phaseType))
                    .foregroundStyle(phaseColor(context.state.phaseType))
            }
        }
    }
}

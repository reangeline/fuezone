import ActivityKit
import Flutter
import Foundation

/// Handles the "com.fuezone.timer/live_activity" MethodChannel.
/// Called from AppDelegate after the Flutter engine initialises.
/// All ActivityKit calls are guarded behind iOS 16.1; on older OS the
/// channel registers but every call is a safe no-op.
class LiveActivityHandler {

    // Stored as Any to avoid @available on the property declaration.
    private var currentActivity: Any?

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.fuezone.timer/live_activity",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            let args = call.arguments as? [String: Any] ?? [:]
            switch call.method {
            case "start":  self.startActivity(args: args, result: result)
            case "update": self.updateActivity(args: args, result: result)
            case "end":    self.endActivity(result: result)
            default:       result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Channel handlers

    private func startActivity(args: [String: Any], result: FlutterResult) {
        guard #available(iOS 16.1, *) else { result(nil); return }
        terminateCurrent()
        let attrs = TimerActivityAttributes(
            workoutName: args["workoutName"] as? String ?? "",
            totalPhases: args["totalPhases"] as? Int ?? 1
        )
        do {
            let activity = try Activity<TimerActivityAttributes>.request(
                attributes: attrs,
                contentState: contentState(from: args),
                pushType: nil
            )
            currentActivity = activity
            result(nil)
        } catch {
            result(FlutterError(code: "LA_START_FAILED",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    private func updateActivity(args: [String: Any], result: FlutterResult) {
        guard #available(iOS 16.1, *),
              let activity = currentActivity as? Activity<TimerActivityAttributes>
        else { result(nil); return }
        let state = contentState(from: args)
        Task {
            do {
                if #available(iOS 16.2, *) {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    try await activity.update(using: state)
                }
            } catch {
                print("[LiveActivity] update failed: \(error)")
            }
        }
        result(nil)
    }

    private func endActivity(result: FlutterResult) {
        terminateCurrent()
        result(nil)
    }

    // MARK: - Helpers

    private func terminateCurrent() {
        guard #available(iOS 16.1, *),
              let activity = currentActivity as? Activity<TimerActivityAttributes>
        else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        currentActivity = nil
    }

    @available(iOS 16.1, *)
    private func contentState(from args: [String: Any]) -> TimerActivityAttributes.ContentState {
        let ms = args["phaseEndMs"] as? Double ?? 0
        let endDate = ms > 0 ? Date(timeIntervalSince1970: ms / 1000.0) : Date()
        return TimerActivityAttributes.ContentState(
            phaseName: args["phaseName"] as? String ?? "",
            phaseType: args["phaseType"] as? String ?? "work",
            phaseIndex: args["phaseIndex"] as? Int ?? 0,
            phaseEndDate: endDate,
            isPaused: args["isPaused"] as? Bool ?? false,
            pausedSecondsRemaining: args["pausedSecondsRemaining"] as? Int ?? 0
        )
    }
}

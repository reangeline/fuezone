import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../timer/timer_engine.dart';
import '../timer/timer_models.dart';

/// Drives iOS Live Activities from the engine's snapshot stream.
///
/// Strategy: only send updates on phase transitions, pause, and resume —
/// NOT on every tick. The widget uses Text(phaseEndDate, style: .timer)
/// so the countdown runs natively without per-second Flutter pushes.
///
/// On Android (and non-iOS) all calls are silent no-ops.
class LiveActivityService {
  static const _channel = MethodChannel('com.fuezone.timer/live_activity');

  StreamSubscription<TimerSnapshot>? _sub;
  int _lastPhaseIndex = -1;
  TimerStatus _lastStatus = TimerStatus.idle;
  bool _started = false;
  late TimerConfig _config;

  void start(TimerConfig config, Stream<TimerSnapshot> snapshots) {
    if (!Platform.isIOS) return;
    _config = config;
    _lastPhaseIndex = -1;
    _lastStatus = TimerStatus.idle;
    _started = false;
    _sub = snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(TimerSnapshot snap) {
    final phaseChanged = snap.phaseIndex != _lastPhaseIndex;
    final statusChanged = snap.status != _lastStatus;
    if (!phaseChanged && !statusChanged) return;

    _lastPhaseIndex = snap.phaseIndex;
    _lastStatus = snap.status;

    if (snap.status == TimerStatus.finished) {
      _end();
      return;
    }

    if (!_started) {
      _invoke('start', _payload(snap));
      _started = true;
    } else {
      _invoke('update', _payload(snap));
    }
  }

  Future<void> _end() async {
    if (!_started) return;
    await _invoke('end', null);
    _started = false;
  }

  Future<void> _invoke(String method, Map<String, dynamic>? args) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (_) {
      // Never crash the app because of a Live Activity failure.
    }
  }

  Map<String, dynamic> _payload(TimerSnapshot snap) {
    final isPaused = snap.status == TimerStatus.paused;
    final phaseEndMs = isPaused
        ? 0.0
        : DateTime.now()
            .add(snap.remainingInPhase)
            .millisecondsSinceEpoch
            .toDouble();

    return {
      'workoutName': _config.name,
      'phaseName': snap.currentPhase.label,
      'phaseType': snap.currentPhase.type.name,
      'phaseIndex': snap.phaseIndex,
      'totalPhases': snap.totalPhases,
      'phaseEndMs': phaseEndMs,
      'isPaused': isPaused,
      'pausedSecondsRemaining': snap.remainingInPhase.inSeconds,
    };
  }

  void dispose() {
    _sub?.cancel();
    _end();
  }
}

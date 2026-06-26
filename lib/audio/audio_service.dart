import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import '../timer/timer_engine.dart';
import '../timer/timer_models.dart';

/// Listens to the engine's event stream and plays the corresponding sounds.
/// Configured with mixWithOthers so timer sounds overlay the user's music.
class AudioService {
  AudioService(Stream<TimerEvent> events, {required List<TimerPhase> phases})
      : _events = events,
        _phases = phases;

  final Stream<TimerEvent> _events;
  final List<TimerPhase> _phases;

  StreamSubscription<TimerEvent>? _subscription;
  int _currentPhaseIndex = 0;
  bool _hasVibrator = false;

  final _startPlayer   = AudioPlayer();
  final _restPlayer    = AudioPlayer();
  final _warningPlayer = AudioPlayer();
  final _endPlayer     = AudioPlayer();

  Future<void> init() async {
    await _configureAudioSession();
    await _preloadPlayers();
    _hasVibrator = await Vibration.hasVibrator();
    _subscribe();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.notification,
      ),
      androidWillPauseWhenDucked: false,
    ));
  }

  Future<void> _preloadPlayers() async {
    await Future.wait([
      _load(_startPlayer,   'assets/sounds/start.mp3'),
      _load(_restPlayer,    'assets/sounds/rest.mp3'),
      _load(_warningPlayer, 'assets/sounds/warning.mp3'),
      _load(_endPlayer,     'assets/sounds/end.mp3'),
    ]);
  }

  Future<void> _load(AudioPlayer player, String asset) async {
    try {
      await player.setAsset(asset);
    } catch (_) {
      // Missing sound file must never crash the app.
    }
  }

  void _subscribe() {
    _subscription = _events.listen((event) {
      switch (event) {
        case TimerEvent.phaseStarted:
          _onPhaseStarted();
        case TimerEvent.warning:
          _play(_warningPlayer);
          _vibrate(duration: 80);
        case TimerEvent.phaseEnded:
          final phase = _phases.elementAtOrNull(_currentPhaseIndex);
          if (phase?.type == PhaseType.work) _play(_endPlayer);
          _currentPhaseIndex++;
        case TimerEvent.finished:
          _currentPhaseIndex = 0;
          if (_phases.lastOrNull?.type != PhaseType.work) _play(_endPlayer);
          _vibrate(pattern: [0, 300, 120, 300]);
      }
    });
  }

  void _onPhaseStarted() {
    final phase = _phases.elementAtOrNull(_currentPhaseIndex);
    if (phase?.type == PhaseType.rest) {
      _play(_restPlayer);
      _vibrate(duration: 150);
    } else {
      _play(_startPlayer);
      _vibrate(duration: 250);
    }
  }

  Future<void> _play(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  void _vibrate({int? duration, List<int>? pattern}) {
    if (!_hasVibrator) return;
    try {
      if (pattern != null) {
        Vibration.vibrate(pattern: pattern);
      } else {
        Vibration.vibrate(duration: duration ?? 200);
      }
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _startPlayer.dispose();
    _restPlayer.dispose();
    _warningPlayer.dispose();
    _endPlayer.dispose();
  }
}

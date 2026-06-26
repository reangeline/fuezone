import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../timer/timer_engine.dart';
import '../timer/timer_models.dart';

/// Escuta o stream [TimerEvent] do engine e toca os sons correspondentes.
///
/// Usa 4 players fixos (um por arquivo) para que cada som esteja sempre
/// pronto no início — sem latência perceptível ao tocar.
///
/// Configurado com mixWithOthers (iOS) / sonification (Android) para que
/// os sons do timer sobreponham a música do usuário sem pausá-la.
class AudioService {
  AudioService(Stream<TimerEvent> events, {required List<TimerPhase> phases})
      : _events = events,
        _phases = phases;

  final Stream<TimerEvent> _events;
  final List<TimerPhase> _phases;

  StreamSubscription<TimerEvent>? _subscription;
  int _currentPhaseIndex = 0;

  final _startPlayer = AudioPlayer();
  final _restPlayer = AudioPlayer();
  final _warningPlayer = AudioPlayer();
  final _endPlayer = AudioPlayer();

  Future<void> init() async {
    await _configureAudioSession();
    await _preloadPlayers();
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
      _load(_startPlayer, 'assets/sounds/start.mp3'),
      _load(_restPlayer, 'assets/sounds/rest.mp3'),
      _load(_warningPlayer, 'assets/sounds/warning.mp3'),
      _load(_endPlayer, 'assets/sounds/end.mp3'),
    ]);
  }

  Future<void> _load(AudioPlayer player, String asset) async {
    try {
      await player.setAsset(asset);
    } catch (_) {
      // Som ausente não deve travar o timer.
    }
  }

  void _subscribe() {
    _subscription = _events.listen((event) {
      switch (event) {
        case TimerEvent.phaseStarted:
          _onPhaseStarted();
        case TimerEvent.warning:
          _play(_warningPlayer);
        case TimerEvent.phaseEnded:
          _currentPhaseIndex++;
        case TimerEvent.finished:
          _currentPhaseIndex = 0;
          _play(_endPlayer);
      }
    });
  }

  void _onPhaseStarted() {
    final phase = _phases.elementAtOrNull(_currentPhaseIndex);
    if (phase?.type == PhaseType.rest) {
      _play(_restPlayer);
    } else {
      _play(_startPlayer);
    }
  }

  Future<void> _play(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Falha de reprodução não deve travar o timer.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _startPlayer.dispose();
    _restPlayer.dispose();
    _warningPlayer.dispose();
    _endPlayer.dispose();
  }
}

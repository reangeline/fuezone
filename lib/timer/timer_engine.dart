import 'dart:async';
import 'timer_models.dart';

/// Estado de execução do motor.
enum TimerStatus { idle, running, paused, awaitingManual, finished }

/// Eventos discretos que a camada de áudio/haptics escuta.
/// O motor NÃO toca som — só anuncia o que aconteceu. Isso mantém
/// a lógica testável e desacoplada do plugin de áudio.
enum TimerEvent {
  phaseStarted, // começou uma fase nova (toca sino de início)
  warning, // entrou nos últimos warningSeconds da fase (bip de aviso)
  phaseEnded, // fase terminou
  finished, // sequência inteira acabou (toca sino final)
}

/// Snapshot imutável do estado atual, emitido pra UI a cada tick.
class TimerSnapshot {
  final TimerStatus status;
  final int phaseIndex;
  final TimerPhase currentPhase;
  final Duration remainingInPhase;
  final Duration elapsedTotal;
  final int totalPhases;

  const TimerSnapshot({
    required this.status,
    required this.phaseIndex,
    required this.currentPhase,
    required this.remainingInPhase,
    required this.elapsedTotal,
    required this.totalPhases,
  });
}

/// O coração do app: percorre a lista de fases de um TimerConfig,
/// emitindo snapshots pra UI e eventos pra áudio.
///
/// Decisão de arquitetura — tempo ABSOLUTO:
/// Em vez de "remaining -= 1" a cada tick (que acumula erro e quebra
/// se o app for suspenso), guardamos quando a fase começou em tempo
/// real e calculamos o restante a partir do relógio. Assim o timer
/// permanece correto mesmo com ticks irregulares ou app em background.
class TimerEngine {
  TimerEngine(this.config);

  final TimerConfig config;

  final _snapshotController = StreamController<TimerSnapshot>.broadcast();
  final _eventController = StreamController<TimerEvent>.broadcast();

  /// UI escuta isto pra renderizar o número/cor.
  Stream<TimerSnapshot> get snapshots => _snapshotController.stream;

  /// Camada de áudio/vibração escuta isto.
  Stream<TimerEvent> get events => _eventController.stream;

  Timer? _ticker;
  TimerStatus _status = TimerStatus.idle;
  int _phaseIndex = 0;

  /// Momento (wall-clock) em que a fase atual deveria terminar.
  DateTime? _phaseEndsAt;

  /// Quanto da fase atual já passou quando foi pausada (pra retomar certo).
  Duration _phaseElapsedBeforePause = Duration.zero;

  /// Soma das fases já concluídas, pra calcular o tempo total decorrido.
  Duration _completedPhasesDuration = Duration.zero;

  bool _warningFired = false;

  TimerStatus get status => _status;

  void start() {
    if (_status == TimerStatus.running || _status == TimerStatus.awaitingManual) return;
    if (_status == TimerStatus.idle) {
      _phaseIndex = 0;
      _completedPhasesDuration = Duration.zero;
      _beginPhase(_phaseIndex);
      // _beginPhase pode ter entrado em awaitingManual (fase de duração zero).
      if (_status == TimerStatus.awaitingManual) return;
    } else if (_status == TimerStatus.paused) {
      if (_phaseEndsAt == null) {
        // Estava em awaitingManual antes de pausar — retoma a espera manual.
        _status = TimerStatus.awaitingManual;
        _emitSnapshot();
        return;
      }
      // Retoma: reposiciona o fim da fase a partir de agora.
      final remaining = config.phases[_phaseIndex].duration -
          _phaseElapsedBeforePause;
      _phaseEndsAt = DateTime.now().add(remaining);
    }
    _status = TimerStatus.running;
    _startTicker();
  }

  void pause() {
    if (_status == TimerStatus.awaitingManual) {
      // Pausa durante espera manual: preserva o estado pra retomar depois.
      _ticker?.cancel();
      _status = TimerStatus.paused;
      _phaseEndsAt = null; // sinaliza que era awaitingManual
      _phaseElapsedBeforePause = Duration.zero;
      _emitSnapshot();
      return;
    }
    if (_status != TimerStatus.running) return;
    _ticker?.cancel();
    // Guarda quanto já passou da fase pra retomar exatamente daqui.
    final remaining = _phaseEndsAt!.difference(DateTime.now());
    _phaseElapsedBeforePause =
        config.phases[_phaseIndex].duration - remaining;
    _status = TimerStatus.paused;
    _emitSnapshot();
  }

  /// Pula pra próxima fase manualmente (ex: terminou o round antes).
  void skip() {
    if (_status == TimerStatus.idle || _status == TimerStatus.finished) return;
    _advancePhase();
  }

  /// Confirma a conclusão de uma fase de duração zero (execução manual).
  /// Só tem efeito quando o motor está em [TimerStatus.awaitingManual].
  void completeCurrentPhase() {
    if (_status != TimerStatus.awaitingManual) return;
    _status = TimerStatus.running;
    _advancePhase();
  }

  /// Encerra tudo. A UI usa isto pra disparar o ad de fim de sessão.
  void stop() {
    _ticker?.cancel();
    _status = TimerStatus.finished;
    _emitSnapshot();
  }

  void _beginPhase(int index) {
    _warningFired = false;
    _phaseElapsedBeforePause = Duration.zero;
    final phase = config.phases[index];
    _eventController.add(TimerEvent.phaseStarted);
    if (phase.duration == Duration.zero) {
      // Fase manual: não agenda deadline; espera ação do usuário.
      _status = TimerStatus.awaitingManual;
      _phaseEndsAt = null;
      _warningFired = true; // sem aviso em fase manual
      _emitSnapshot();
      return;
    }
    _phaseEndsAt = DateTime.now().add(phase.duration);
    _emitSnapshot();
  }

  void _startTicker() {
    _ticker?.cancel();
    // 100ms dá fluidez visual sem custo de bateria relevante.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (_status != TimerStatus.running) return;

    final now = DateTime.now();
    final remaining = _phaseEndsAt!.difference(now);

    // Dispara o aviso ao cruzar o limiar (uma vez por fase).
    if (!_warningFired &&
        config.warningSeconds > 0 &&
        remaining.inMilliseconds <= config.warningSeconds * 1000 &&
        remaining.inMilliseconds > 0) {
      _warningFired = true;
      _eventController.add(TimerEvent.warning);
    }

    if (remaining.inMilliseconds <= 0) {
      _advancePhase();
      return;
    }

    _emitSnapshot();
  }

  void _advancePhase() {
    _eventController.add(TimerEvent.phaseEnded);
    _completedPhasesDuration += config.phases[_phaseIndex].duration;
    final next = _phaseIndex + 1;

    if (next >= config.phases.length) {
      _ticker?.cancel();
      _status = TimerStatus.finished;
      _eventController.add(TimerEvent.finished);
      _emitSnapshot();
      return;
    }

    _phaseIndex = next;
    _beginPhase(_phaseIndex);
  }

  void _emitSnapshot() {
    final phase = config.phases[_phaseIndex];
    Duration remaining;
    if (_status == TimerStatus.awaitingManual) {
      remaining = Duration.zero;
    } else if (_status == TimerStatus.paused && _phaseEndsAt == null) {
      // Pausado enquanto esperava avanço manual.
      remaining = Duration.zero;
    } else if (_status == TimerStatus.paused) {
      remaining = phase.duration - _phaseElapsedBeforePause;
    } else if (_status == TimerStatus.finished) {
      remaining = Duration.zero;
    } else {
      remaining = _phaseEndsAt!.difference(DateTime.now());
      if (remaining.isNegative) remaining = Duration.zero;
    }

    final elapsedInPhase = phase.duration - remaining;

    _snapshotController.add(TimerSnapshot(
      status: _status,
      phaseIndex: _phaseIndex,
      currentPhase: phase,
      remainingInPhase: remaining,
      elapsedTotal: _completedPhasesDuration + elapsedInPhase,
      totalPhases: config.phases.length,
    ));
  }

  void dispose() {
    _ticker?.cancel();
    _snapshotController.close();
    _eventController.close();
  }
}

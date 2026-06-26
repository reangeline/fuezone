import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ads/ad_service.dart';
import '../audio/audio_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_engine.dart';
import '../timer/timer_models.dart';
import '../widgets/glass_container.dart';
import '../widgets/phase_ring.dart';
import '../widgets/pressable_card.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.config, this.heroTag});

  final TimerConfig config;
  final String? heroTag;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late TimerEngine _engine;
  late AudioService _audio;
  late AdService _ads;

  @override
  void initState() {
    super.initState();
    _engine = TimerEngine(widget.config);
    _audio = AudioService(_engine.events, phases: widget.config.phases);
    _ads = AdService(_engine.events, _engine.snapshots);
    _audio.init();
    _ads.init();
    WakelockPlus.enable();
    // Inicia automaticamente para o usuário não precisar tocar "play" após abrir
    _engine.start();
  }

  @override
  void dispose() {
    _engine.dispose();
    _audio.dispose();
    _ads.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimerSnapshot>(
      stream: _engine.snapshots,
      builder: (context, snap) {
        final s = snap.data ?? _idleSnapshot();
        return _TimerView(
          snapshot: s,
          config: widget.config,
          heroTag: widget.heroTag,
          onPause: _engine.pause,
          onResume: _engine.start,
          onSkip: _engine.skip,
          onStop: _engine.stop,
          onRestart: _restart,
        );
      },
    );
  }

  TimerSnapshot _idleSnapshot() => TimerSnapshot(
        status: TimerStatus.idle,
        phaseIndex: 0,
        currentPhase: widget.config.phases.first,
        remainingInPhase: widget.config.phases.first.duration,
        elapsedTotal: Duration.zero,
        totalPhases: widget.config.phases.length,
      );

  void _restart() {
    _engine.dispose();
    _audio.dispose();
    // Substituir por uma nova instância do engine e reiniciar
    setState(() {
      _engine = TimerEngine(widget.config);
      _audio = AudioService(_engine.events, phases: widget.config.phases);
    });
    _audio.init();
    _engine.start();
  }
}

// ---------------------------------------------------------------------------

class _TimerView extends StatelessWidget {
  const _TimerView({
    required this.snapshot,
    required this.config,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onStop,
    required this.onRestart,
    this.heroTag,
  });

  final TimerSnapshot snapshot;
  final TimerConfig config;
  final String? heroTag;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  bool get _isFinished => snapshot.status == TimerStatus.finished;
  bool get _isRunning  => snapshot.status == TimerStatus.running;

  bool get _isWarning {
    if (config.warningSeconds <= 0) return false;
    return snapshot.remainingInPhase.inSeconds <= config.warningSeconds &&
        snapshot.remainingInPhase.inMilliseconds > 0;
  }

  Color get _bgColor {
    if (_isFinished) return AppColors.surface;
    return AppColors.forPhase(snapshot.currentPhase.type);
  }

  double get _ringProgress {
    final total = snapshot.currentPhase.duration.inMilliseconds;
    if (total <= 0) return 0;
    final elapsed = total - snapshot.remainingInPhase.inMilliseconds;
    return elapsed / total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Hero(
        tag: heroTag ?? 'timer_bg_default',
        child: AnimatedContainer(
          duration: AppAnimations.durationSlow,
          curve: AppAnimations.curveEmphasis,
          color: _bgColor,
          child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(snapshot: snapshot, config: config),
                  Expanded(child: _CenterRing(
                    snapshot: snapshot,
                    ringProgress: _ringProgress,
                    isWarning: _isWarning,
                  )),
                  _BottomControls(
                    isRunning: _isRunning,
                    isFinished: _isFinished,
                    onPause: onPause,
                    onResume: onResume,
                    onSkip: onSkip,
                    onStop: onStop,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
              // Overlay de fim de sessão
              if (_isFinished)
                _FinishedOverlay(
                  elapsed: snapshot.elapsedTotal,
                  onRestart: onRestart,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.snapshot, required this.config});

  final TimerSnapshot snapshot;
  final TimerConfig config;

  String get _phaseCounter {
    // Conta apenas as fases de trabalho para exibir "Round X / Y"
    final workPhases = config.phases
        .where((p) => p.type == PhaseType.work)
        .toList();
    if (workPhases.isEmpty) return '';
    final completedWork = config.phases
        .sublist(0, snapshot.phaseIndex)
        .where((p) => p.type == PhaseType.work)
        .length;
    final currentIsWork = snapshot.currentPhase.type == PhaseType.work;
    final current = completedWork + (currentIsWork ? 1 : 0);
    return 'Round $current / ${workPhases.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          Text(
            config.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedSwitcher(
            duration: AppAnimations.durationMedium,
            switchInCurve: AppAnimations.curveFade,
            switchOutCurve: AppAnimations.curveFade,
            child: Text(
              snapshot.currentPhase.label.toUpperCase(),
              key: ValueKey(snapshot.phaseIndex),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _phaseCounter,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CenterRing extends StatelessWidget {
  const _CenterRing({
    required this.snapshot,
    required this.ringProgress,
    required this.isWarning,
  });

  final TimerSnapshot snapshot;
  final double ringProgress;
  final bool isWarning;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide * 0.72;
    final textColor = isWarning ? AppColors.warning : Colors.white;

    return Center(
      child: PhaseRing(
        progress: ringProgress,
        phaseColor: AppColors.forPhase(snapshot.currentPhase.type),
        isWarning: isWarning,
        size: size,
        child: Text(
          _format(snapshot.remainingInPhase),
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isRunning,
    required this.isFinished,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onStop,
  });

  final bool isRunning;
  final bool isFinished;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    if (isFinished) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.skip_next_rounded,
            label: 'Pular',
            onTap: onSkip,
          ),
          _ControlButton(
            icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: isRunning ? 'Pausar' : 'Retomar',
            size: 72,
            onTap: isRunning ? onPause : onResume,
            onLongPress: onStop,
          ),
          // Espaço simétrico para centralizar visualmente o botão principal
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: size / 2,
      padding: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.18),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FinishedOverlay extends StatelessWidget {
  const _FinishedOverlay({required this.elapsed, required this.onRestart});

  final Duration elapsed;
  final VoidCallback onRestart;

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 52),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sessão concluída',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _format(elapsed),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PressableCard(
                onTap: onRestart,
                borderRadius: 14,
                color: Colors.white.withValues(alpha: 0.22),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Novo treino',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

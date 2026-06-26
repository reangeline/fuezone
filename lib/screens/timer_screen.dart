import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ads/ad_service.dart';
import '../audio/audio_service.dart';
import '../live_activity/live_activity_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_engine.dart';
import '../timer/timer_models.dart';
import '../widgets/phase_ring.dart';
import '../widgets/pressable_card.dart';
import 'workout_complete_screen.dart';

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
  final _liveActivity = LiveActivityService();
  bool _completionNavigated = false;

  @override
  void initState() {
    super.initState();
    _engine = TimerEngine(widget.config);
    _audio = AudioService(_engine.events, phases: widget.config.phases);
    _ads = AdService(_engine.events, _engine.snapshots);
    _audio.init();
    _ads.init();
    _liveActivity.start(widget.config, _engine.snapshots);
    WakelockPlus.enable();
    _engine.start();
  }

  @override
  void dispose() {
    _engine.dispose();
    _audio.dispose();
    _ads.dispose();
    _liveActivity.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimerSnapshot>(
      stream: _engine.snapshots,
      builder: (context, snap) {
        final s = snap.data ?? _idleSnapshot();

        if (s.status == TimerStatus.finished && !_completionNavigated) {
          _completionNavigated = true;
          final elapsed = s.elapsedTotal;
          final nav = Navigator.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            nav.push(
              PageRouteBuilder<String>(
                transitionDuration: AppAnimations.durationSlow,
                pageBuilder: (_, __, ___) => WorkoutCompleteScreen(
                  config: widget.config,
                  elapsedTotal: elapsed,
                  ads: _ads,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            ).then((result) {
              if (!mounted) return;
              if (result == 'repeat') {
                _restart();
              } else {
                nav.maybePop();
              }
            });
          });
        }

        return _TimerView(
          snapshot: s,
          config: widget.config,
          heroTag: widget.heroTag,
          onPause: _engine.pause,
          onResume: _engine.start,
          onSkip: _engine.skip,
          onStop: _engine.stop,
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
    _completionNavigated = false;
    _engine.dispose();
    _audio.dispose();
    _ads.dispose();
    _liveActivity.dispose();
    setState(() {
      _engine = TimerEngine(widget.config);
      _audio = AudioService(_engine.events, phases: widget.config.phases);
      _ads = AdService(_engine.events, _engine.snapshots);
    });
    _audio.init();
    _ads.init();
    _liveActivity.start(widget.config, _engine.snapshots);
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
    this.heroTag,
  });

  final TimerSnapshot snapshot;
  final TimerConfig config;
  final String? heroTag;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onStop;

  bool get _isFinished => snapshot.status == TimerStatus.finished;
  bool get _isRunning  => snapshot.status == TimerStatus.running;

  bool get _isWarning {
    if (config.warningSeconds <= 0) return false;
    return snapshot.remainingInPhase.inSeconds <= config.warningSeconds &&
        snapshot.remainingInPhase.inMilliseconds > 0;
  }

  Color _bgColor(BuildContext context) {
    if (_isFinished) return AppColors.surface;
    if (config.workoutType != WorkoutType.fight) return AppColors.background;
    const blend = 0.55;
    return Color.lerp(AppColors.background, AppColors.forPhase(snapshot.currentPhase.type), blend)!;
  }

  String _fmtRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Hero(
        tag: heroTag ?? 'timer_bg_default',
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppAnimations.durationSlow,
          curve: AppAnimations.curveEmphasis,
          color: _bgColor(context),
          child: SafeArea(
            child: Stack(
              children: [
                if (config.workoutType != WorkoutType.fight)
                  Positioned.fill(
                    child: _WorkoutLayout(
                      snapshot: snapshot,
                      config: config,
                      isWarning: _isWarning,
                      isRunning: _isRunning,
                      isFinished: _isFinished,
                      onPause: onPause,
                      onResume: onResume,
                      onSkip: onSkip,
                      onStop: onStop,
                    ),
                  )
                else
                  Positioned.fill(
                    child: OrientationBuilder(
                      builder: (context, orientation) {
                        if (orientation == Orientation.landscape) {
                          return _LandscapeTimerLayout(
                            snapshot: snapshot,
                            config: config,
                            isWarning: _isWarning,
                            isRunning: _isRunning,
                            isFinished: _isFinished,
                            reduceMotion: reduceMotion,
                            fmtRemaining: _fmtRemaining,
                            onPause: onPause,
                            onResume: onResume,
                            onSkip: onSkip,
                            onStop: onStop,
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AppBar(config: config),
                            _PhaseLabel(
                              label: snapshot.currentPhase.label,
                              phaseIndex: snapshot.phaseIndex,
                              snapshot: snapshot,
                              config: config,
                              reduceMotion: reduceMotion,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Text(
                                    _fmtRemaining(snapshot.remainingInPhase),
                                    softWrap: false,
                                    style: TextStyle(
                                      color: _isWarning
                                          ? AppColors.warning
                                          : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                      height: 0.9,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _SessionDots(config: config, snapshot: snapshot),
                            _Controls(
                              isRunning: _isRunning,
                              isFinished: _isFinished,
                              onPause: onPause,
                              onResume: onResume,
                              onSkip: onSkip,
                              onStop: onStop,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        );
                      },
                    ),
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

class _AppBar extends StatelessWidget {
  const _AppBar({required this.config});

  final TimerConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          PressableCard(
            onTap: () => Navigator.maybePop(context),
            borderRadius: 24,
            padding: EdgeInsets.zero,
            color: Colors.white.withValues(alpha: 0.18),
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Text(
            config.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({
    required this.label,
    required this.phaseIndex,
    required this.snapshot,
    required this.config,
    required this.reduceMotion,
  });

  final String label;
  final int phaseIndex;
  final TimerSnapshot snapshot;
  final TimerConfig config;
  final bool reduceMotion;

  /// Conta quantas fases de trabalho existem e qual a atual (1-based).
  (int current, int total) _workCounter() {
    final total = config.phases.where((p) => p.type == PhaseType.work).length;
    final current = config.phases
            .sublist(0, snapshot.phaseIndex + 1)
            .where((p) => p.type == PhaseType.work)
            .length;
    return (current, total);
  }

  String _buildLabel() {
    final isRest = snapshot.currentPhase.type == PhaseType.rest;
    final isPrepare = snapshot.currentPhase.type == PhaseType.prepare;

    switch (config.workoutType) {
      case WorkoutType.fight:
        if (isPrepare) return 'GET READY';
        if (isRest) return 'REST';
        final (cur, tot) = _workCounter();
        return 'ROUND $cur / $tot';
      case WorkoutType.hiit:
        if (isPrepare) return 'GET READY';
        if (isRest) return 'REST';
        final (cur, tot) = _workCounter();
        return 'INTERVAL $cur / $tot';
      case WorkoutType.workout:
        return label.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = _buildLabel();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge de tipo (apenas fight/hiit — workout não precisa)
        if (config.workoutType != WorkoutType.workout)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _WorkoutTypeBadge(type: config.workoutType),
          ),
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : AppAnimations.durationMedium,
          switchInCurve: AppAnimations.curveFade,
          switchOutCurve: AppAnimations.curveFade,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: reduceMotion
                ? child
                : SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
          ),
          child: Text(
            displayLabel,
            key: ValueKey('$phaseIndex-$displayLabel'),
            style: TextStyle(
              color: Colors.white,
              fontSize: config.workoutType == WorkoutType.workout ? 18 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: config.workoutType == WorkoutType.workout ? 3 : 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutTypeBadge extends StatelessWidget {
  const _WorkoutTypeBadge({required this.type});

  final WorkoutType type;

  (String emoji, String label, Color color) _info() => switch (type) {
        WorkoutType.fight   => ('🥋', 'Fight',   AppColors.work),
        WorkoutType.hiit    => ('⚡', 'HIIT',    AppColors.prepare),
        WorkoutType.workout => ('💪', 'Workout', AppColors.rest),
      };

  @override
  Widget build(BuildContext context) {
    final (emoji, lbl, color) = _info();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            lbl,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TimerHero extends StatefulWidget {
  const _TimerHero({
    required this.snapshot,
    required this.ringProgress,
    required this.isWarning,
  });

  final TimerSnapshot snapshot;
  final double ringProgress;
  final bool isWarning;

  @override
  State<_TimerHero> createState() => _TimerHeroState();
}

class _TimerHeroState extends State<_TimerHero>
    with SingleTickerProviderStateMixin {
  static const _kPulseSeconds = 3;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  int? _lastHapticSec;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TimerHero old) {
    super.didUpdateWidget(old);
    _maybeHaptic();
    _updatePulse();
  }

  void _updatePulse() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldPulse = widget.snapshot.remainingInPhase.inSeconds <=
            _kPulseSeconds &&
        widget.snapshot.remainingInPhase.inMilliseconds > 0 &&
        widget.snapshot.status == TimerStatus.running;

    if (shouldPulse && !_pulseCtrl.isAnimating && !reduceMotion) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!shouldPulse && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.animateTo(0);
    }
  }

  void _maybeHaptic() {
    final rem = widget.snapshot.remainingInPhase;
    if (rem.inSeconds <= _kPulseSeconds && rem.inMilliseconds > 0) {
      final sec = rem.inSeconds;
      if (sec != _lastHapticSec) {
        _lastHapticSec = sec;
        HapticFeedback.mediumImpact();
      }
    } else {
      _lastHapticSec = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide * 0.80;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: _pulseCtrl.isAnimating ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: PhaseRing(
        progress: widget.ringProgress,
        phaseColor: AppColors.forPhase(widget.snapshot.currentPhase.type),
        isWarning: widget.isWarning,
        size: size,
        child: _CountdownText(
          remaining: widget.snapshot.remainingInPhase,
          isWarning: widget.isWarning,
          size: size,
        ),
      ),
    );
  }
}

class _CountdownText extends StatelessWidget {
  const _CountdownText({
    required this.remaining,
    required this.isWarning,
    required this.size,
  });

  final Duration remaining;
  final bool isWarning;
  final double size;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Inner width for text ≈ ring diameter × 0.68 (fits inside circle)
    final maxWidth = size * 0.68;
    return SizedBox(
      width: maxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _format(remaining),
          softWrap: false,
          style: TextStyle(
            color: isWarning ? AppColors.warning : Colors.white,
            fontSize: size * 0.40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 0.9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.config, required this.snapshot});

  final TimerConfig config;
  final TimerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final workPhases = config.phases
        .where((p) => p.type == PhaseType.work)
        .toList();
    if (workPhases.isEmpty) return const SizedBox.shrink();

    final completedWork = config.phases
        .sublist(0, snapshot.phaseIndex)
        .where((p) => p.type == PhaseType.work)
        .length;
    final currentIsWork = snapshot.currentPhase.type == PhaseType.work;
    if (workPhases.length > 12) {
      return Text(
        '$completedWork / ${workPhases.length}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white54,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(workPhases.length, (i) {
        final isDone = i < completedWork;
        final isCurrent = currentIsWork && i == completedWork;
        final radius = isCurrent ? 5.0 : 4.0;
        final alpha = (isDone || isCurrent) ? 1.0 : 0.25;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: alpha),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({
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
            icon: Icons.stop_rounded,
            size: 64,
            onTap: onStop,
          ),
          _ControlButton(
            icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 88,
            primary: true,
            onTap: isRunning ? onPause : onResume,
          ),
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 64,
            onTap: onSkip,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: size / 2,
      padding: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: primary ? 0.28 : 0.18),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Landscape full-screen layout (fight / hiit)
// ---------------------------------------------------------------------------

class _LandscapeTimerLayout extends StatelessWidget {
  const _LandscapeTimerLayout({
    required this.snapshot,
    required this.config,
    required this.isWarning,
    required this.isRunning,
    required this.isFinished,
    required this.reduceMotion,
    required this.fmtRemaining,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onStop,
  });

  final TimerSnapshot snapshot;
  final TimerConfig config;
  final bool isWarning;
  final bool isRunning;
  final bool isFinished;
  final bool reduceMotion;
  final String Function(Duration) fmtRemaining;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Timer + phase label filling all available width minus controls column
        Positioned.fill(
          child: Row(
            children: [
              // Main timer area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    _PhaseLabel(
                      label: snapshot.currentPhase.label,
                      phaseIndex: snapshot.phaseIndex,
                      snapshot: snapshot,
                      config: config,
                      reduceMotion: reduceMotion,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            fmtRemaining(snapshot.remainingInPhase),
                            softWrap: false,
                            style: TextStyle(
                              color: isWarning ? AppColors.warning : Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 0.9,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionDots(config: config, snapshot: snapshot),
                    ),
                  ],
                ),
              ),
              // Compact controls column on the right
              if (!isFinished)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(icon: Icons.stop_rounded, size: 44, onTap: onStop),
                      const SizedBox(height: 12),
                      _ControlButton(
                        icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 58,
                        primary: true,
                        onTap: isRunning ? onPause : onResume,
                      ),
                      const SizedBox(height: 12),
                      _ControlButton(icon: Icons.skip_next_rounded, size: 44, onTap: onSkip),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Back button top-left
        Positioned(
          top: 8,
          left: 8,
          child: PressableCard(
            onTap: () => Navigator.maybePop(context),
            borderRadius: 24,
            padding: EdgeInsets.zero,
            color: Colors.white.withValues(alpha: 0.18),
            child: const SizedBox.square(
              dimension: 36,
              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Workout-type list layout
// ---------------------------------------------------------------------------

class _WorkoutLayout extends StatefulWidget {
  const _WorkoutLayout({
    required this.snapshot,
    required this.config,
    required this.isWarning,
    required this.isRunning,
    required this.isFinished,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onStop,
  });

  final TimerSnapshot snapshot;
  final TimerConfig config;
  final bool isWarning;
  final bool isRunning;
  final bool isFinished;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onStop;

  @override
  State<_WorkoutLayout> createState() => _WorkoutLayoutState();
}

class _WorkoutLayoutState extends State<_WorkoutLayout> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  int? _lastIndex;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_WorkoutLayout old) {
    super.didUpdateWidget(old);
    final idx = widget.snapshot.phaseIndex;
    if (idx != _lastIndex) {
      _lastIndex = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[idx]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: AppAnimations.durationMedium,
            curve: AppAnimations.curveDefault,
            alignment: 0.15,
          );
        }
      });
    }
  }

  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final phases = widget.config.phases;
    final current = widget.snapshot.phaseIndex;

    return Column(
      children: [
        _AppBar(config: widget.config),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
            ),
            itemCount: phases.length,
            itemBuilder: (context, i) {
              final phase = phases[i];
              final isCurrent = i == current;
              final isDone = i < current;
              final totalMs = phase.duration.inMilliseconds.clamp(1, 1 << 53);
              final progress = isCurrent
                  ? 1.0 -
                     (widget.snapshot.remainingInPhase.inMilliseconds /
                         totalMs)
                  : (isDone ? 1.0 : 0.0);

              return Padding(
                key: _keyFor(i),
                padding: EdgeInsets.only(
                  bottom: phase.type == PhaseType.rest
                     ? AppSpacing.xs
                     : AppSpacing.sm,
                ),
                child: _WorkoutPhaseItem(
                  phase: phase,
                  isCurrent: isCurrent,
                  isDone: isDone,
                  progress: progress.clamp(0.0, 1.0),
                  remaining: isCurrent
                     ? widget.snapshot.remainingInPhase
                     : null,
                  isWarning: isCurrent && widget.isWarning,
                ),
              );
            },
          ),
        ),
        _Controls(
          isRunning: widget.isRunning,
          isFinished: widget.isFinished,
          onPause: widget.onPause,
          onResume: widget.onResume,
          onSkip: widget.onSkip,
          onStop: widget.onStop,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _WorkoutPhaseItem extends StatelessWidget {
  const _WorkoutPhaseItem({
    required this.phase,
    required this.isCurrent,
    required this.isDone,
    required this.progress,
    this.remaining,
    this.isWarning = false,
  });

  final TimerPhase phase;
  final bool isCurrent;
  final bool isDone;
  final double progress;
  final Duration? remaining;
  final bool isWarning;

  Color get _accent => AppColors.forPhase(phase.type);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (isCurrent) return _buildCurrentCard(context);
    if (phase.type == PhaseType.rest) return _buildRestRow(context);
    return _buildNormalRow(context);
  }

  Widget _buildCurrentCard(BuildContext context) {
    final rem = remaining ?? phase.duration;
    final color = isWarning ? AppColors.warning : _accent;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                   phase.label.toUpperCase(),
                   style: const TextStyle(
                     color: Colors.white,
                     fontSize: 17,
                     fontWeight: FontWeight.w800,
                     letterSpacing: 1.5,
                   ),
                  ),
                ),
                Text(
                  _fmt(rem),
                  style: TextStyle(
                   color: isWarning ? AppColors.warning : Colors.white,
                   fontSize: 40,
                   fontWeight: FontWeight.w900,
                   letterSpacing: -1,
                   height: 1,
                   fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDone ? 0.04 : 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white38, size: 15)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phase.label,
              style: TextStyle(
                color: isDone ? Colors.white38 : Colors.white70,
                fontSize: 15,
                fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white38,
              ),
            ),
          ),
          Text(
            _fmt(phase.duration),
            style: TextStyle(
              color: isDone ? Colors.white24 : Colors.white38,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md + 4),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 24,
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.rest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 11,
            color: isDone
                ? Colors.white24
                : AppColors.rest.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            'Rest · ${_fmt(phase.duration)}',
            style: TextStyle(
              color: isDone ? Colors.white24 : Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

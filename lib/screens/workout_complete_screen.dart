import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_models.dart';
import '../widgets/primary_button.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.config,
    required this.elapsedTotal,
    required this.ads,
  });

  final TimerConfig config;
  final Duration elapsedTotal;
  final AdService ads;

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppAnimations.durationSlow,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: AppAnimations.curveEmphasis);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppAnimations.curveEmphasis));

    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) widget.ads.showIfEligible();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _roundCount =>
      widget.config.phases.where((p) => p.type == PhaseType.work).length;

  String _roundLabel(WorkoutType type) => switch (type) {
        WorkoutType.fight   => 'Rounds',
        WorkoutType.hiit    => 'Intervals',
        WorkoutType.workout => 'Intervals',
      };

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.prepare,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'WORKOUT COMPLETE',
                    textAlign: TextAlign.center,
                    style: tt.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.config.name,
                    textAlign: TextAlign.center,
                    style: tt.headlineMedium?.copyWith(
                      color: AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _StatBlock(
                    value: _formatTime(widget.elapsedTotal),
                    label: 'Total time',
                    valueStyle: tt.displayMedium?.copyWith(
                      color: AppColors.onBackground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    labelStyle: tt.bodySmall?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StatBlock(
                    value: '$_roundCount',
                    label: _roundLabel(widget.config.workoutType),
                    valueStyle: tt.headlineLarge?.copyWith(
                      color: AppColors.onBackground,
                    ),
                    labelStyle: tt.bodySmall?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  PrimaryButton(
                    label: 'Repeat',
                    onPressed: () => Navigator.pop(context, 'repeat'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'home'),
                    child: Text(
                      'Back to home',
                      style: tt.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.valueStyle,
    required this.labelStyle,
  });

  final String value;
  final String label;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, textAlign: TextAlign.center, style: valueStyle),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: labelStyle),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../storage/local_preset_repository.dart';
import '../storage/preset_repository.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_models.dart';
import '../widgets/pressable_card.dart';
import 'add_workout_screen.dart';
import 'timer_screen.dart';

// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;

  final PresetRepository _repo = LocalPresetRepository();
  List<SavedPreset> _saved = [];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final saved = await _repo.list();
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _deleteSaved(String id) async {
    setState(() => _saved.removeWhere((p) => p.id == id));
    await _repo.delete(id);
  }

  Future<void> _reorderSaved(int oldIndex, int newIndex) async {
    setState(() => _saved.insert(newIndex, _saved.removeAt(oldIndex)));
    await _repo.reorder(_saved.map((p) => p.id).toList());
  }

  void _navigateToTimer(TimerConfig config) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => TimerScreen(config: config),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openEditWorkout(SavedPreset preset) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => AddWorkoutScreen(editPreset: preset),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) => _loadPresets());
  }

  void _openAddWorkout() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const AddWorkoutScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) => _loadPresets());
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _AddFab(onTap: _openAddWorkout),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'FUEZONE',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
            ),
          ),
          if (_saved.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _StaggeredItem(
                ctrl: _staggerCtrl,
                index: 0,
                child: _EmptyState(onAddTap: _openAddWorkout),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl + 80, // space for FAB
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StaggeredItem(
                    ctrl: _staggerCtrl,
                    index: 0,
                    child: const _SectionHeader('MY WORKOUTS'),
                  ),
                  _StaggeredItem(
                    ctrl: _staggerCtrl,
                    index: 1,
                    child: _WorkoutList(
                      saved: _saved,
                      onTap: (config) => _navigateToTimer(config),
                      onEdit: _openEditWorkout,
                      onDelete: _deleteSaved,
                      onReorder: _reorderSaved,
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAB de adicionar
// ---------------------------------------------------------------------------

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      color: AppColors.work,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'New workout',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.work.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚡', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No workouts yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first workout to get started',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PressableCard(
              onTap: onAddTap,
              color: AppColors.work,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Text(
                'Create workout',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stagger wrapper (mantido igual)
// ---------------------------------------------------------------------------

class _StaggeredItem extends StatelessWidget {
  const _StaggeredItem({
    required this.ctrl,
    required this.index,
    required this.child,
  });

  final AnimationController ctrl;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(start, 1.0);
    final curved = CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: AppAnimations.curveDefault),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ) ??
            const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lista de treinos (reordenável + swipe-to-delete)
// ---------------------------------------------------------------------------

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({
    required this.saved,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<SavedPreset> saved;
  final void Function(TimerConfig) onTap;
  final void Function(SavedPreset) onEdit;
  final void Function(String id) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      children: [
        for (final (i, preset) in saved.indexed)
          Dismissible(
            key: ValueKey(preset.id),
            direction: DismissDirection.horizontal,
            // Swipe direita→esquerda: deletar (vermelho)
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.lg + 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 22),
            ),
            // Swipe esquerda→direita: editar (azul)
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: AppSpacing.lg + 4),
              decoration: BoxDecoration(
                color: AppColors.rest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 22),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Editar: abre a tela e cancela o dismiss
                onEdit(preset);
                return false;
              }
              // Deletar: confirma o dismiss
              return true;
            },
            onDismissed: (_) => onDelete(preset.id),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _WorkoutCard(
                index: i,
                preset: preset,
                onTap: () => onTap(preset.config),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de treino
// ---------------------------------------------------------------------------

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.index,
    required this.preset,
    required this.onTap,
  });

  final int index;
  final SavedPreset preset;
  final VoidCallback onTap;

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final mins = d.inMinutes.remainder(60);
      return mins > 0 ? '${d.inHours}h ${mins}min' : '${d.inHours}h';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}min';
    return '${d.inSeconds}s';
  }

  int _sectionCount(TimerConfig config) =>
      config.phases.where((p) => p.type == PhaseType.work).length;

  @override
  Widget build(BuildContext context) {
    final total = preset.config.totalDuration;
    final sections = _sectionCount(preset.config);

    return PressableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Accent bar
            Container(
              width: 4,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.work,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),

            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.config.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ) ??
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.timer_outlined,
                          label: _formatDuration(total),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _Chip(
                          icon: Icons.fitness_center_rounded,
                          label: '$sections section(s)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Play button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.work.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.work,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

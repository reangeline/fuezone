import 'package:flutter/material.dart';

import '../storage/local_preset_repository.dart';
import '../storage/preset_repository.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_models.dart';
import '../timer/timer_presets.dart';
import '../widgets/pressable_card.dart';
import 'custom_timer_screen.dart';
import 'timer_screen.dart';

// ---------------------------------------------------------------------------
// Modelo local de preset para exibição na home
// ---------------------------------------------------------------------------

class _PresetEntry {
  const _PresetEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.config,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final TimerConfig config;
}

// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final List<_PresetEntry> _fightPresets;
  late final List<_PresetEntry> _otherPresets;

  final PresetRepository _repo = LocalPresetRepository();
  List<SavedPreset> _saved = [];

  @override
  void initState() {
    super.initState();
    _buildPresets();
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

  void _buildPresets() {
    _fightPresets = [
      _PresetEntry(
        id: 'bjj',
        title: 'BJJ',
        subtitle: '5 rounds × 5 min',
        emoji: '🥋',
        color: AppColors.work,
        config: TimerPresets.bjj(),
      ),
      _PresetEntry(
        id: 'boxing',
        title: 'Boxe',
        subtitle: '12 rounds × 3 min',
        emoji: '🥊',
        color: const Color(0xFFFF6B35),
        config: TimerPresets.boxing(),
      ),
      _PresetEntry(
        id: 'muaythai',
        title: 'Muay Thai',
        subtitle: '5 rounds × 3 min',
        emoji: '🦵',
        color: AppColors.work,
        config: TimerPresets.fight(
          name: 'Muay Thai',
          rounds: 5,
          roundDuration: const Duration(minutes: 3),
          restDuration: const Duration(minutes: 2),
        ),
      ),
      _PresetEntry(
        id: 'wrestling',
        title: 'Wrestling',
        subtitle: '3 rounds × 2 min',
        emoji: '🤼',
        color: const Color(0xFFFF9F0A),
        config: TimerPresets.fight(
          name: 'Wrestling',
          rounds: 3,
          roundDuration: const Duration(minutes: 2),
          restDuration: const Duration(minutes: 1),
        ),
      ),
    ];

    _otherPresets = [
      _PresetEntry(
        id: 'hiit',
        title: 'HIIT / Tabata',
        subtitle: '8 rounds × 20s + 10s',
        emoji: '⚡',
        color: AppColors.prepare,
        config: TimerPresets.hiit(),
      ),
      _PresetEntry(
        id: 'emom',
        title: 'EMOM',
        subtitle: '10 rounds × 1 min',
        emoji: '⏱',
        color: AppColors.rest,
        config: TimerPresets.emom(),
      ),
      _PresetEntry(
        id: 'mobility',
        title: 'Mobilidade',
        subtitle: '6 posições × 1 min',
        emoji: '🧘',
        color: AppColors.cooldown,
        config: TimerPresets.mobility(
          positions: [
            'Quadril',
            'Coluna',
            'Ombro D',
            'Ombro E',
            'Isquio D',
            'Isquio E',
          ],
          hold: const Duration(minutes: 1),
        ),
      ),
      _PresetEntry(
        id: 'rest',
        title: 'Descanso',
        subtitle: '90 segundos',
        emoji: '💤',
        color: const Color(0xFF636366),
        config: TimerPresets.restTimer(
          exercise: 'Descanso',
          rest: const Duration(seconds: 90),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _openCustomTimer() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const CustomTimerScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) => _loadPresets());
  }

  void _navigateTo(_PresetEntry entry) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => TimerScreen(
          config: entry.config,
          heroTag: 'preset_hero_${entry.id}',
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // Offset de índice para o stagger: +2 quando há presets salvos (header + lista)
  int _idx(int base) => base + (_saved.isEmpty ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Meus presets (visível só quando há salvos) ──────────────
                if (_saved.isNotEmpty) ...[
                  _StaggeredItem(
                    ctrl: _staggerCtrl,
                    index: 0,
                    child: const _SectionHeader('MEUS PRESETS'),
                  ),
                  _StaggeredItem(
                    ctrl: _staggerCtrl,
                    index: 1,
                    child: _SavedPresetsList(
                      saved: _saved,
                      onTap: _navigateToTimer,
                      onDelete: _deleteSaved,
                      onReorder: _reorderSaved,
                    ),
                  ),
                ],
                // ── Presets de luta ─────────────────────────────────────────
                _StaggeredItem(
                  ctrl: _staggerCtrl,
                  index: _idx(0),
                  child: const _SectionHeader('LUTA'),
                ),
                _StaggeredItem(
                  ctrl: _staggerCtrl,
                  index: _idx(1),
                  child: _FightGrid(
                    entries: _fightPresets,
                    onTap: _navigateTo,
                  ),
                ),
                _StaggeredItem(
                  ctrl: _staggerCtrl,
                  index: _idx(2),
                  child: const _SectionHeader('OUTROS TREINOS'),
                ),
                ..._otherPresets.indexed.map(
                  (e) => _StaggeredItem(
                    ctrl: _staggerCtrl,
                    index: _idx(3 + e.$1),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm + 2),
                      child: _ListPresetCard(
                        entry: e.$2,
                        onTap: () => _navigateTo(e.$2),
                      ),
                    ),
                  ),
                ),
                _StaggeredItem(
                  ctrl: _staggerCtrl,
                  index: _idx(3 + _otherPresets.length),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xl,
                    ),
                    child: _CustomCard(onTap: _openCustomTimer),
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
// Stagger wrapper
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
      padding: EdgeInsets.only(
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
// Fight grid (2×2)
// ---------------------------------------------------------------------------

class _FightGrid extends StatelessWidget {
  const _FightGrid({required this.entries, required this.onTap});

  final List<_PresetEntry> entries;
  final void Function(_PresetEntry) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm + 2,
      mainAxisSpacing: AppSpacing.sm + 2,
      childAspectRatio: 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: entries
          .map((e) => _FightCard(entry: e, onTap: () => onTap(e)))
          .toList(),
    );
  }
}

class _FightCard extends StatelessWidget {
  const _FightCard({required this.entry, required this.onTap});

  final _PresetEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: 20,
      child: Hero(
        tag: 'preset_hero_${entry.id}',
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: entry.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.emoji,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 30,
                          ) ??
                      const TextStyle(fontSize: 30),
                ),
                const Spacer(),
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          ) ??
                      TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
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
// List preset card (outros treinos)
// ---------------------------------------------------------------------------

class _ListPresetCard extends StatelessWidget {
  const _ListPresetCard({required this.entry, required this.onTap});

  final _PresetEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: 16,
      child: Hero(
        tag: 'preset_hero_${entry.id}',
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: entry.color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      entry.emoji,
                      style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontSize: 22) ??
                          const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ) ??
                            TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 13,
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
// Lista de presets salvos (reordenável + swipe-to-delete)
// ---------------------------------------------------------------------------

class _SavedPresetsList extends StatelessWidget {
  const _SavedPresetsList({
    required this.saved,
    required this.onTap,
    required this.onDelete,
    required this.onReorder,
  });

  final List<SavedPreset> saved;
  final void Function(TimerConfig) onTap;
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
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onDelete(preset.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: AppSpacing.lg + 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 22),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _SavedPresetCard(
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

class _SavedPresetCard extends StatelessWidget {
  const _SavedPresetCard({
    required this.index,
    required this.preset,
    required this.onTap,
  });

  final int index;
  final SavedPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: 14,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🔖', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.config.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ) ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${preset.config.phaseCount} fases · ${_formatDuration(preset.config.totalDuration)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ) ??
                        TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}min';
    }
    return '${d.inSeconds}s';
  }
}

// ---------------------------------------------------------------------------
// Custom card (em breve)
// ---------------------------------------------------------------------------

class _CustomCard extends StatelessWidget {
  const _CustomCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      borderRadius: 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white70, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timer personalizado',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ) ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Monte sua sequência de fases',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ) ??
                        const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.25),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

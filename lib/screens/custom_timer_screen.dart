import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../storage/local_preset_repository.dart';
import '../storage/preset_repository.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../timer/timer_models.dart';
import '../widgets/pressable_card.dart';
import 'timer_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _defaultLabel(PhaseType t) => t == PhaseType.work ? 'Work' : 'Rest';

// ---------------------------------------------------------------------------
// Estado mutável de uma fase em edição
// ---------------------------------------------------------------------------

class _PhaseData {
  _PhaseData({
    required this.type,
    String label = '',
    int min = 1,
    int sec = 0,
  })  : key = UniqueKey(),
        labelCtrl = TextEditingController(text: label),
        minCtrl = TextEditingController(text: min.toString()),
        secCtrl = TextEditingController(text: sec.toString().padLeft(2, '0'));

  PhaseType type;
  final Key key;
  final TextEditingController labelCtrl;
  final TextEditingController minCtrl;
  final TextEditingController secCtrl;

  bool get isValid {
    final m = int.tryParse(minCtrl.text) ?? 0;
    final s = int.tryParse(secCtrl.text) ?? 0;
    return m * 60 + s > 0;
  }

  TimerPhase toPhase() {
    final label = labelCtrl.text.trim();
    return TimerPhase(
      type: type,
      label: label.isEmpty ? _defaultLabel(type) : label,
      duration: Duration(
        minutes: int.tryParse(minCtrl.text) ?? 0,
        seconds: int.tryParse(secCtrl.text) ?? 0,
      ),
    );
  }

  void dispose() {
    labelCtrl.dispose();
    minCtrl.dispose();
    secCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Tela principal
// ---------------------------------------------------------------------------

class CustomTimerScreen extends StatefulWidget {
  const CustomTimerScreen({super.key});

  @override
  State<CustomTimerScreen> createState() => _CustomTimerScreenState();
}

class _CustomTimerScreenState extends State<CustomTimerScreen> {
  final PresetRepository _repo = LocalPresetRepository();
  final _nameCtrl = TextEditingController(text: 'My timer');
  final List<_PhaseData> _phases = [
    _PhaseData(type: PhaseType.work, label: 'Work', min: 1, sec: 0),
    _PhaseData(type: PhaseType.rest, label: 'Rest', min: 0, sec: 30),
  ];

  @override
  void initState() {
    super.initState();
    // Rebuild quando o nome muda (afeta _isValid → opacidade do botão)
    _nameCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phases.isNotEmpty &&
      _phases.every((p) => p.isValid);

  @override
  void dispose() {
    _nameCtrl.removeListener(_rebuild);
    _nameCtrl.dispose();
    for (final p in _phases) {
      p.dispose();
    }
    super.dispose();
  }

  void _addPhase() {
    setState(() {
      _phases.add(_PhaseData(type: PhaseType.work, min: 1));
    });
  }

  void _deletePhase(_PhaseData phase) {
    setState(() {
      phase.dispose();
      _phases.remove(phase);
    });
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      _phases.insert(newIndex, _phases.removeAt(oldIndex));
    });
  }

  void _setPhaseType(_PhaseData phase, PhaseType type) {
    setState(() {
      phase.type = type;
    });
  }

  void _phaseChanged() => setState(() {});

  TimerConfig _buildConfig() => TimerConfig(
        name: _nameCtrl.text.trim(),
        phases: _phases.map((p) => p.toPhase()).toList(),
      );

  Future<void> _save() async {
    if (!_isValid) return;
    await _repo.save(_buildConfig());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to your presets')),
    );
  }

  void _start() {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one phase with duration > 0')),
      );
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => TimerScreen(config: _buildConfig()),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Custom timer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
        ),
        actions: [
          AnimatedOpacity(
            opacity: _isValid ? 1.0 : 0.35,
            duration: AppAnimations.durationMedium,
            child: IconButton(
              onPressed: _isValid ? _save : null,
              icon:
                  const Icon(Icons.bookmark_add_outlined, color: Colors.white),
              tooltip: 'Save preset',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AnimatedOpacity(
              opacity: _isValid ? 1.0 : 0.35,
              duration: AppAnimations.durationMedium,
              child: PressableCard(
                onTap: _isValid ? _start : null,
                color: AppColors.work,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Start',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo do nome
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: TextField(
              controller: _nameCtrl,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
              decoration: InputDecoration(
                labelText: 'Timer name',
                labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 6, vertical: AppSpacing.sm),
              ),
            ),
          ),
          // Lista de fases reordenável
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              onReorderItem: _onReorderItem,
              children: [
                for (final phase in _phases)
                  Padding(
                    key: phase.key,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PhaseCard(
                      index: _phases.indexOf(phase),
                      data: phase,
                      onDelete: () => _deletePhase(phase),
                      onTypeChanged: (t) => _setPhaseType(phase, t),
                      onDurationChanged: _phaseChanged,
                    ),
                  ),
              ],
            ),
          ),
          // Botão adicionar fase
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            child: PressableCard(
              onTap: _addPhase,
              color: AppColors.surface,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      color: Colors.white.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Add phase',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de fase
// ---------------------------------------------------------------------------

class _PhaseCard extends StatefulWidget {
  const _PhaseCard({
    required this.index,
    required this.data,
    required this.onDelete,
    required this.onTypeChanged,
    required this.onDurationChanged,
  });

  final int index;
  final _PhaseData data;
  final VoidCallback onDelete;
  final void Function(PhaseType) onTypeChanged;
  final VoidCallback onDurationChanged;

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard> {
  bool _durationTouched = false;

  void _clampSeconds() {
    final raw = int.tryParse(widget.data.secCtrl.text) ?? 0;
    final clamped = raw.clamp(0, 59);
    if (raw != clamped) {
      widget.data.secCtrl.text = clamped.toString().padLeft(2, '0');
      widget.data.secCtrl.selection =
          TextSelection.collapsed(offset: widget.data.secCtrl.text.length);
    }
    setState(() => _durationTouched = true);
    widget.onDurationChanged();
  }

  void _onDurationChanged() {
    setState(() => _durationTouched = true);
    widget.onDurationChanged();
  }

  bool get _showDurationError => _durationTouched && !widget.data.isValid;

  @override
  Widget build(BuildContext context) {
    final phase = widget.data;
    final accentColor = AppColors.forPhase(phase.type);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: _showDurationError
            ? Border.all(color: Colors.red.withValues(alpha: 0.6), width: 1)
            : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle de drag
          ReorderableDragStartListener(
            index: widget.index,
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 2, left: AppSpacing.xs, right: AppSpacing.xs),
              child: Icon(
                Icons.drag_handle_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
            ),
          ),
          // Conteúdo editável
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha: type toggle + delete
                Row(
                  children: [
                    _TypeToggle(
                      selected: phase.type,
                      accentColor: accentColor,
                      onChanged: widget.onTypeChanged,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Campo label
                TextField(
                  controller: phase.labelCtrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                  decoration: InputDecoration(
                    hintText: 'Phase name (e.g. Round 1, Chest)',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2, vertical: AppSpacing.xs),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Duração
                Row(
                  children: [
                    _DurationField(
                      controller: phase.minCtrl,
                      hint: '0',
                      label: 'min',
                      onChanged: _onDurationChanged,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _DurationField(
                      controller: phase.secCtrl,
                      hint: '00',
                      label: 'sec',
                      maxValue: 59,
                      onChanged: _onDurationChanged,
                      onEditingComplete: _clampSeconds,
                    ),
                    if (_showDurationError) ...[
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Duration must be > 0',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.red.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle de tipo (Trabalho / Descanso)
// ---------------------------------------------------------------------------

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.selected,
    required this.accentColor,
    required this.onChanged,
  });

  final PhaseType selected;
  final Color accentColor;
  final void Function(PhaseType) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeChip(
          label: 'Work',
          active: selected == PhaseType.work,
          activeColor: AppColors.work,
          onTap: () => onChanged(PhaseType.work),
        ),
        const SizedBox(width: 6),
        _TypeChip(
          label: 'Rest',
          active: selected == PhaseType.rest,
          activeColor: AppColors.rest,
          onTap: () => onChanged(PhaseType.rest),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.durationFast,
        curve: AppAnimations.curveDefault,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 1),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                    active ? activeColor : Colors.white.withValues(alpha: 0.4),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de duração (min ou seg)
// ---------------------------------------------------------------------------

class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.hint,
    required this.label,
    required this.onChanged,
    this.maxValue,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final String hint;
  final String label;
  final int? maxValue;
  final VoidCallback onChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            ),
            onChanged: (_) => onChanged(),
            onEditingComplete: onEditingComplete,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
        ),
      ],
    );
  }
}

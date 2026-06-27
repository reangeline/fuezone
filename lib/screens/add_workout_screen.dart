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
// Estado mutável de uma seção em edição
// ---------------------------------------------------------------------------

class _SectionData {
  _SectionData({
    String label = '',
    int min = 1,
    int sec = 0,
    int restMin = 1,
    int restSec = 0,
  })  : key = UniqueKey(),
        labelCtrl = TextEditingController(text: label),
        minCtrl = TextEditingController(text: min.toString()),
        secCtrl = TextEditingController(text: sec.toString().padLeft(2, '0')),
        restMinCtrl = TextEditingController(text: restMin.toString()),
        restSecCtrl =
            TextEditingController(text: restSec.toString().padLeft(2, '0'));

  final Key key;
  final TextEditingController labelCtrl;
  final TextEditingController minCtrl;
  final TextEditingController secCtrl;
  final TextEditingController restMinCtrl;
  final TextEditingController restSecCtrl;

  // Duração zero é permitida — significa execução manual.
  bool get isValid => true;

  bool get isManual {
    final m = int.tryParse(minCtrl.text) ?? 0;
    final s = int.tryParse(secCtrl.text) ?? 0;
    return m * 60 + s == 0;
  }

  Duration get restDuration => Duration(
        minutes: int.tryParse(restMinCtrl.text) ?? 0,
        seconds: int.tryParse(restSecCtrl.text) ?? 0,
      );

  TimerPhase toPhase(int index) {
    final raw = labelCtrl.text.trim();
    return TimerPhase(
      type: PhaseType.work,
      label: raw.isEmpty ? 'Section ${index + 1}' : raw,
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
    restMinCtrl.dispose();
    restSecCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Tela principal
// ---------------------------------------------------------------------------

class AddWorkoutScreen extends StatefulWidget {
  const AddWorkoutScreen({super.key, this.editPreset});

  /// Quando fornecido, a tela opera em modo edição.
  final SavedPreset? editPreset;

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  final PresetRepository _repo = LocalPresetRepository();
  late final TextEditingController _nameCtrl;

  late int _prepSec;
  late WorkoutType _workoutType;
  late final List<_SectionData> _sections;

  bool get _isEditing => widget.editPreset != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _initFromPreset(widget.editPreset!.config);
    } else {
      _nameCtrl = TextEditingController(text: 'My workout');
      _prepSec = 10;
      _workoutType = WorkoutType.workout;
      _sections = [
        _SectionData(label: 'Section 1', min: 1, sec: 0, restMin: 1, restSec: 0),
      ];
    }
    _nameCtrl.addListener(_rebuild);
  }

  /// Reconstrói o formulário a partir de um [TimerConfig] existente.
  /// Estrutura esperada: [prepare?] [work, rest?]* 
  void _initFromPreset(TimerConfig config) {
    final phases = config.phases;
    int prepSec = 0;
    final sections = <_SectionData>[];

    int i = 0;
    // Fase de preparação opcional no início
    if (phases.isNotEmpty && phases[0].type == PhaseType.prepare) {
      prepSec = phases[0].duration.inSeconds;
      i = 1;
    }

    while (i < phases.length) {
      final phase = phases[i];
      if (phase.type == PhaseType.work) {
        final workMin = phase.duration.inMinutes;
        final workSec = phase.duration.inSeconds % 60;
        int restMin = 0;
        int restSec = 0;
        // Próxima fase de descanso pertence a esta seção
        if (i + 1 < phases.length && phases[i + 1].type == PhaseType.rest) {
          i++;
          restMin = phases[i].duration.inMinutes;
          restSec = phases[i].duration.inSeconds % 60;
        }
        sections.add(_SectionData(
          label: phase.label,
          min: workMin,
          sec: workSec,
          restMin: restMin,
          restSec: restSec,
        ));
      }
      i++;
    }

    _nameCtrl = TextEditingController(text: config.name);
    _prepSec = prepSec;
    _workoutType = config.workoutType;
    _sections = sections.isEmpty
        ? [_SectionData(label: 'Section 1', min: 1, restMin: 1)]
        : sections;
  }

  void _rebuild() => setState(() {});

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty && _sections.isNotEmpty;

  @override
  void dispose() {
    _nameCtrl.removeListener(_rebuild);
    _nameCtrl.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    setState(() {
      _sections.add(_SectionData(
        label: 'Section ${_sections.length + 1}',
        min: 1,
        restMin: 1,
      ));
    });
  }

  void _deleteSection(_SectionData section) {
    setState(() {
      section.dispose();
      _sections.remove(section);
    });
  }

  void _duplicateSection(_SectionData section) {
    final copy = _SectionData(
      label: section.labelCtrl.text.trim(),
      min: int.tryParse(section.minCtrl.text) ?? 0,
      sec: int.tryParse(section.secCtrl.text) ?? 0,
      restMin: int.tryParse(section.restMinCtrl.text) ?? 0,
      restSec: int.tryParse(section.restSecCtrl.text) ?? 0,
    );
    setState(() => _sections.insert(_sections.indexOf(section) + 1, copy));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() => _sections.insert(newIndex, _sections.removeAt(oldIndex)));
  }

  TimerConfig _buildConfig() {
    final phases = <TimerPhase>[];

    if (_prepSec > 0) {
      phases.add(TimerPhase(
        type: PhaseType.prepare,
        label: 'Prepare-se',
        duration: Duration(seconds: _prepSec),
      ));
    }

    for (var i = 0; i < _sections.length; i++) {
      phases.add(_sections[i].toPhase(i));
      final rest = _sections[i].restDuration;
      if (rest.inSeconds > 0) {
        phases.add(TimerPhase(
          type: PhaseType.rest,
          label: 'Rest',
          duration: rest,
        ));
      }
    }

    return TimerConfig(
      name: _nameCtrl.text.trim(),
      workoutType: _workoutType,
      phases: phases,
    );
  }

  Future<void> _save() async {
    if (!_isValid) return;
    final config = _buildConfig();
    if (_isEditing) {
      await _repo.update(widget.editPreset!.id, config);
    } else {
      await _repo.save(config);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Workout updated!' : 'Workout saved!')),
    );
    Navigator.pop(context);
  }

  void _start() {
    if (!_isValid) return;
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
          _isEditing ? 'Edit workout' : 'New workout',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          AnimatedOpacity(
            opacity: _isValid ? 1.0 : 0.35,
            duration: AppAnimations.durationMedium,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
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
                            fontWeight: FontWeight.w700,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nome ────────────────────────────────────────────────
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                    decoration: InputDecoration(
                      labelText: 'Workout name',
                      labelStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Tipo de treino ──────────────────────────────────────
                  _WorkoutTypePicker(
                    selected: _workoutType,
                    onChanged: (t) => setState(() => _workoutType = t),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Preparação ──────────────────────────────────────────
                  _SettingsCard(children: [
                    _TimeSettingRow(
                      icon: Icons.timer_outlined,
                      iconColor: AppColors.prepare,
                      label: 'Warm-up',
                      description: 'Time before starting',
                      child: _PrepStepper(
                        value: _prepSec,
                        onChanged: (v) => setState(() => _prepSec = v),
                      ),
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Header seções ───────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'SECTIONS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${_sections.length} section(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white30,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Lista de seções (reordenável) ───────────────────────
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: _onReorder,
                    children: [
                      for (final (i, section) in _sections.indexed)
                        Dismissible(
                          key: section.key,
                          direction: _sections.length > 1
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: AppSpacing.lg),
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white, size: 22),
                          ),
                          background: const SizedBox.shrink(),
                          onDismissed: (_) => _deleteSection(section),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _SectionCard(
                              index: i,
                              data: section,
                              onDuplicate: () => _duplicateSection(section),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // ── Adicionar seção ─────────────────────────────────────
                  PressableCard(
                    onTap: _addSection,
                    color: AppColors.surface,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md - 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white.withValues(alpha: 0.6), size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Add section',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),

          // ── Barra inferior: Salvar ──────────────────────────────────────
          _SaveBar(
            isValid: _isValid,
            onSave: _save,
            label: _isEditing ? 'Save changes' : 'Save workout',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker de tipo de treino
// ---------------------------------------------------------------------------

class _WorkoutTypePicker extends StatelessWidget {
  const _WorkoutTypePicker({
    required this.selected,
    required this.onChanged,
  });

  final WorkoutType selected;
  final void Function(WorkoutType) onChanged;

  static const _options = [
    (type: WorkoutType.fight,   emoji: '🥋', label: 'Fight'),
    (type: WorkoutType.hiit,    emoji: '⚡', label: 'HIIT'),
    (type: WorkoutType.workout, emoji: '💪', label: 'Workout'),
  ];

  Color _accentFor(WorkoutType t) => switch (t) {
        WorkoutType.fight   => AppColors.work,
        WorkoutType.hiit    => AppColors.prepare,
        WorkoutType.workout => AppColors.rest,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TYPE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _options.map((opt) {
            final isSelected = selected == opt.type;
            final accent = _accentFor(opt.type);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: opt.type != WorkoutType.workout ? AppSpacing.sm : 0,
                ),
                child: GestureDetector(
                  onTap: () => onChanged(opt.type),
                  child: AnimatedContainer(
                    duration: AppAnimations.durationFast,
                    curve: AppAnimations.curveDefault,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md - 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.18)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? accent.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.06),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          opt.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.label,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? accent
                                    : Colors.white.withValues(alpha: 0.5),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de configurações (prep + descanso)
// ---------------------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _TimeSettingRow extends StatelessWidget {
  const _TimeSettingRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stepper para preparação (segundos, múltiplos de 5)
// ---------------------------------------------------------------------------

class _PrepStepper extends StatelessWidget {
  const _PrepStepper({required this.value, required this.onChanged});

  final int value;
  final void Function(int) onChanged;

  static const _step = 5;
  static const _max = 60;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          onTap: value > 0 ? () => onChanged((value - _step).clamp(0, _max)) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 42,
          child: Text(
            '${value}s',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _StepButton(
          icon: Icons.add_rounded,
          onTap: value < _max ? () => onChanged((value + _step).clamp(0, _max)) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.durationFast,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de seção
// ---------------------------------------------------------------------------

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.index,
    required this.data,
    required this.onDuplicate,
    required this.onChanged,
  });

  final int index;
  final _SectionData data;
  final VoidCallback onDuplicate;
  final VoidCallback onChanged;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  void _clampSec() {
    final raw = int.tryParse(widget.data.secCtrl.text) ?? 0;
    final clamped = raw.clamp(0, 59);
    if (raw != clamped) {
      widget.data.secCtrl.text = clamped.toString().padLeft(2, '0');
      widget.data.secCtrl.selection =
          TextSelection.collapsed(offset: widget.data.secCtrl.text.length);
    }
    widget.onChanged();
  }

  void _clampRestSec() {
    final raw = int.tryParse(widget.data.restSecCtrl.text) ?? 0;
    final clamped = raw.clamp(0, 59);
    if (raw != clamped) {
      widget.data.restSecCtrl.text = clamped.toString().padLeft(2, '0');
      widget.data.restSecCtrl.selection =
          TextSelection.collapsed(offset: widget.data.restSecCtrl.text.length);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: widget.index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(
                Icons.drag_handle_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Número da seção
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.work.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.work,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Campos editáveis
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome
                TextField(
                  controller: widget.data.labelCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => widget.onChanged(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                  decoration: InputDecoration(
                    hintText: 'Name (e.g. Round 1, Sprint)',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs + 2,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                // Duração (trabalho)
                Row(
                  children: [
                    _DurationField(
                      controller: widget.data.minCtrl,
                      hint: '0',
                      label: 'min',
                      onChanged: widget.onChanged,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _DurationField(
                      controller: widget.data.secCtrl,
                      hint: '00',
                      label: 'sec',
                      maxValue: 59,
                      onChanged: widget.onChanged,
                      onEditingComplete: _clampSec,
                    ),
                    if (widget.data.isManual) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.work.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.work.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Manual',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.work,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Divider de descanso
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Descanso após esta seção
                Row(
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 13,
                      color: AppColors.rest.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rest',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.rest.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _DurationField(
                      controller: widget.data.restMinCtrl,
                      hint: '0',
                      label: 'min',
                      onChanged: widget.onChanged,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _DurationField(
                      controller: widget.data.restSecCtrl,
                      hint: '00',
                      label: 'sec',
                      maxValue: 59,
                      onChanged: widget.onChanged,
                      onEditingComplete: _clampRestSec,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Duplicar
          GestureDetector(
            onTap: widget.onDuplicate,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.copy_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de duração (min ou seg) — mesmo estilo do custom_timer_screen
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
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
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

// ---------------------------------------------------------------------------
// Barra inferior de salvar
// ---------------------------------------------------------------------------

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isValid,
    required this.onSave,
    this.label = 'Save workout',
  });

  final bool isValid;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        bottom + AppSpacing.sm + 4,
      ),
      child: AnimatedOpacity(
        opacity: isValid ? 1.0 : 0.4,
        duration: AppAnimations.durationMedium,
        child: PressableCard(
          onTap: isValid ? onSave : null,
          color: AppColors.surfaceHigh,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_add_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

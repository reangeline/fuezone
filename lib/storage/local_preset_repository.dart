import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../timer/timer_models.dart';
import 'preset_repository.dart';

class LocalPresetRepository implements PresetRepository {
  static const _key = 'custom_presets_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<List<SavedPreset>> list() async {
    try {
      final raw = (await _instance).getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(TimerConfig config) async {
    try {
      final presets = await list();
      presets.add(SavedPreset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        savedAt: DateTime.now(),
        config: config,
      ));
      await _write(presets);
    } catch (_) {}
  }

  @override
  Future<void> update(String id, TimerConfig config) async {
    try {
      final presets = await list();
      final idx = presets.indexWhere((p) => p.id == id);
      if (idx == -1) return;
      presets[idx] = SavedPreset(
        id: id,
        savedAt: presets[idx].savedAt,
        config: config,
      );
      await _write(presets);
    } catch (_) {}
  }

  @override
  Future<void> delete(String id) async {
    try {
      final presets = await list();
      presets.removeWhere((p) => p.id == id);
      await _write(presets);
    } catch (_) {}
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    try {
      final presets = await list();
      final map = {for (final p in presets) p.id: p};
      final reordered = orderedIds
          .map((id) => map[id])
          .whereType<SavedPreset>()
          .toList();
      await _write(reordered);
    } catch (_) {}
  }

  Future<void> _write(List<SavedPreset> presets) async {
    final prefs = await _instance;
    await prefs.setString(
      _key,
      jsonEncode(presets.map(_toJson).toList()),
    );
  }
}

// ---------------------------------------------------------------------------
// Serialização (privada ao arquivo)
// ---------------------------------------------------------------------------

SavedPreset _fromJson(Map<String, dynamic> json) => SavedPreset(
      id: json['id'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      config: _configFromJson(json['config'] as Map<String, dynamic>),
    );

Map<String, dynamic> _toJson(SavedPreset p) => {
      'id': p.id,
      'savedAt': p.savedAt.toIso8601String(),
      'config': _configToJson(p.config),
    };

TimerConfig _configFromJson(Map<String, dynamic> json) => TimerConfig(
      name: json['name'] as String,
      workoutType: WorkoutType.values.byName(
        (json['workoutType'] as String?) ?? WorkoutType.workout.name,
      ),
      warningSeconds: (json['warningSeconds'] as num?)?.toInt() ?? 5,
      phases: (json['phases'] as List)
          .map((p) => _phaseFromJson(p as Map<String, dynamic>))
          .toList(),
      groups: ((json['groups'] as List?) ?? [])
          .map((g) => _groupFromJson(g as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _configToJson(TimerConfig c) => {
      'name': c.name,
      'workoutType': c.workoutType.name,
      'warningSeconds': c.warningSeconds,
      'phases': c.phases.map(_phaseToJson).toList(),
      'groups': c.groups.map(_groupToJson).toList(),
    };

WorkoutGroup _groupFromJson(Map<String, dynamic> json) => WorkoutGroup(
      name: json['name'] as String,
      note: json['note'] as String?,
    );

Map<String, dynamic> _groupToJson(WorkoutGroup g) => {
      'name': g.name,
      if (g.note != null) 'note': g.note,
    };

TimerPhase _phaseFromJson(Map<String, dynamic> json) => TimerPhase(
      type: PhaseType.values.byName(json['type'] as String),
      label: json['label'] as String,
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      groupIndex: json['groupIndex'] as int?,
      seriesNote: json['seriesNote'] as String?,
    );

Map<String, dynamic> _phaseToJson(TimerPhase p) => {
      'type': p.type.name,
      'label': p.label,
      'durationMs': p.duration.inMilliseconds,
      if (p.groupIndex != null) 'groupIndex': p.groupIndex,
      if (p.seriesNote != null && p.seriesNote!.isNotEmpty)
        'seriesNote': p.seriesNote,
    };

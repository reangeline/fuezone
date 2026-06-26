import '../timer/timer_models.dart';

class SavedPreset {
  const SavedPreset({
    required this.id,
    required this.savedAt,
    required this.config,
  });

  final String id;
  final DateTime savedAt;
  final TimerConfig config;
}

abstract class PresetRepository {
  Future<List<SavedPreset>> list();
  Future<void> save(TimerConfig config);
  Future<void> update(String id, TimerConfig config);
  Future<void> delete(String id);
  Future<void> reorder(List<String> orderedIds);
}

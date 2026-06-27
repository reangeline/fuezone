// Princípio central: todo modo de treino é apenas uma sequência de fases
// diferente. O motor não conhece "BJJ" ou "Tabata" — só percorre fases.

/// Tipo visual do treino. Usado apenas pela UI para adaptar a exibição
/// do timer — não afeta a lógica do motor.
enum WorkoutType {
  fight,   // luta — mostra "Round X / Y"
  hiit,    // HIIT / Tabata — mostra "Interval X / Y"
  workout, // força / condicionamento geral — mostra o nome da seção
}

/// Tipo da fase. Usado pela UI pra decidir cor/som, não pela lógica do motor.
enum PhaseType {
  prepare, // contagem inicial antes de começar ("prepare-se")
  work, // round / esforço / exercício
  rest, // descanso entre rounds/séries
  cooldown, // opcional, ao final
}

/// Grupo de exercício dentro de um workout (ex: "Supino reto").
/// Agrupa visualmente as fases de trabalho/descanso que pertencem
/// ao mesmo exercício. Opcional — presets sem grupos funcionam normalmente.
class WorkoutGroup {
  final String name; // ex: "Supino reto"
  final String? note; // anotação opcional no nível do grupo

  const WorkoutGroup({required this.name, this.note});
}

/// Uma fase única e cronometrada dentro da sequência.
class TimerPhase {
  final PhaseType type;

  /// Nome editável pela pessoa ("Peito", "Round 1", "Sprint").
  final String label;

  final Duration duration;

  /// Índice em [TimerConfig.groups] ao qual esta fase pertence.
  /// null = fase de preset legado ou sem grupos (fight/HIIT/etc.).
  final int? groupIndex;

  /// Referência de planejamento por série ("80kg", "12 reps").
  /// Preenchido na criação do treino; exibido como leitura durante execução.
  final String? seriesNote;

  const TimerPhase({
    required this.type,
    required this.label,
    required this.duration,
    this.groupIndex,
    this.seriesNote,
  });

  TimerPhase copyWith({
    PhaseType? type,
    String? label,
    Duration? duration,
    int? groupIndex,
    String? seriesNote,
  }) {
    return TimerPhase(
      type: type ?? this.type,
      label: label ?? this.label,
      duration: duration ?? this.duration,
      groupIndex: groupIndex ?? this.groupIndex,
      seriesNote: seriesNote ?? this.seriesNote,
    );
  }
}

/// Configuração completa de um timer: a lista de fases já "achatada"
/// na ordem de execução. Um helper (buildPhases) gera essa lista a
/// partir de parâmetros amigáveis (rounds, trabalho, descanso).
class TimerConfig {
  /// Nome do preset ("BJJ 5x5", "Tabata", "Peito - descanso 3min").
  final String name;

  /// Tipo visual — controla como o timer é exibido na tela.
  final WorkoutType workoutType;

  /// Fases na ordem exata de execução.
  final List<TimerPhase> phases;

  /// Aviso sonoro nos últimos N segundos de uma fase (ex: 10s pro fim
  /// do round). Zero desliga.
  final int warningSeconds;

  /// Grupos de exercício (ex: "Supino reto", "Supino inclinado").
  /// Lista vazia = preset sem grupos — comportamento legado inalterado.
  final List<WorkoutGroup> groups;

  const TimerConfig({
    required this.name,
    required this.phases,
    this.workoutType = WorkoutType.workout,
    this.warningSeconds = 10,
    this.groups = const [],
  });

  /// Duração total somando todas as fases.
  Duration get totalDuration =>
      phases.fold(Duration.zero, (sum, p) => sum + p.duration);

  int get phaseCount => phases.length;
}

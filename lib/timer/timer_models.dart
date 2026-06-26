// Princípio central: todo modo de treino é apenas uma sequência de fases
// diferente. O motor não conhece "BJJ" ou "Tabata" — só percorre fases.

/// Tipo da fase. Usado pela UI pra decidir cor/som, não pela lógica do motor.
enum PhaseType {
  prepare, // contagem inicial antes de começar ("prepare-se")
  work, // round / esforço / exercício
  rest, // descanso entre rounds/séries
  cooldown, // opcional, ao final
}

/// Uma fase única e cronometrada dentro da sequência.
class TimerPhase {
  final PhaseType type;

  /// Nome editável pela pessoa ("Peito", "Round 1", "Sprint").
  /// Resolve a reclamação real: poder nomear as fases em vez de só
  /// "trabalho/descanso".
  final String label;

  final Duration duration;

  const TimerPhase({
    required this.type,
    required this.label,
    required this.duration,
  });

  TimerPhase copyWith({PhaseType? type, String? label, Duration? duration}) {
    return TimerPhase(
      type: type ?? this.type,
      label: label ?? this.label,
      duration: duration ?? this.duration,
    );
  }
}

/// Configuração completa de um timer: a lista de fases já "achatada"
/// na ordem de execução. Um helper (buildPhases) gera essa lista a
/// partir de parâmetros amigáveis (rounds, trabalho, descanso).
class TimerConfig {
  /// Nome do preset ("BJJ 5x5", "Tabata", "Peito - descanso 3min").
  final String name;

  /// Fases na ordem exata de execução.
  final List<TimerPhase> phases;

  /// Aviso sonoro nos últimos N segundos de uma fase (ex: 10s pro fim
  /// do round). Zero desliga.
  final int warningSeconds;

  const TimerConfig({
    required this.name,
    required this.phases,
    this.warningSeconds = 10,
  });

  /// Duração total somando todas as fases. Útil pra UI mostrar
  /// "treino de 32min" antes de começar.
  Duration get totalDuration =>
      phases.fold(Duration.zero, (sum, p) => sum + p.duration);

  int get phaseCount => phases.length;
}

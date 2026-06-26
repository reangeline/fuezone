import 'timer_models.dart';

/// Fábrica de presets. A prova de que "um motor cobre tudo": cada modo
/// abaixo é só uma forma diferente de montar a lista de fases. O
/// TimerEngine não sabe qual é qual — só executa a sequência.
class TimerPresets {
  /// Fase de preparação padrão no início de qualquer treino.
  static TimerPhase _prepare([int seconds = 10]) => TimerPhase(
        type: PhaseType.prepare,
        label: 'Get ready',
        duration: Duration(seconds: seconds),
      );

  /// LUTA (BJJ, boxe, muay thai, wrestling).
  /// Rounds longos + descanso curto, repetidos.
  static TimerConfig fight({
    required String name,
    required int rounds,
    required Duration roundDuration,
    required Duration restDuration,
  }) {
    final phases = <TimerPhase>[_prepare()];
    for (var i = 1; i <= rounds; i++) {
      phases.add(TimerPhase(
        type: PhaseType.work,
        label: 'Round $i',
        duration: roundDuration,
      ));
      // Sem descanso depois do último round.
      if (i < rounds) {
        phases.add(TimerPhase(
          type: PhaseType.rest,
          label: 'Rest',
          duration: restDuration,
        ));
      }
    }
    return TimerConfig(name: name, phases: phases);
  }

  /// Atalhos de luta prontos (resolvem a reclamação "não tem preset pronto").
  static TimerConfig bjj() => fight(
        name: 'BJJ 5 x 5min',
        rounds: 5,
        roundDuration: const Duration(minutes: 5),
        restDuration: const Duration(minutes: 1),
      );

  static TimerConfig boxing() => fight(
        name: 'Boxing 12 x 3min',
        rounds: 12,
        roundDuration: const Duration(minutes: 3),
        restDuration: const Duration(minutes: 1),
      );

  /// HIIT / TABATA. Trabalho curto / descanso curto, muitos ciclos.
  static TimerConfig hiit({
    String name = 'Tabata',
    int rounds = 8,
    Duration work = const Duration(seconds: 20),
    Duration rest = const Duration(seconds: 10),
  }) {
    final phases = <TimerPhase>[_prepare(5)];
    for (var i = 1; i <= rounds; i++) {
      phases.add(TimerPhase(
        type: PhaseType.work,
        label: 'Work',
        duration: work,
      ));
      if (i < rounds) {
        phases.add(TimerPhase(
          type: PhaseType.rest,
          label: 'Rest',
          duration: rest,
        ));
      }
    }
    return TimerConfig(name: name, phases: phases, warningSeconds: 3);
  }

  /// EMOM (every minute on the minute). Só trabalho, intervalo fixo.
  static TimerConfig emom({
    int minutes = 10,
    Duration interval = const Duration(minutes: 1),
  }) {
    final phases = <TimerPhase>[_prepare(5)];
    for (var i = 1; i <= minutes; i++) {
      phases.add(TimerPhase(
        type: PhaseType.work,
        label: 'Minute $i',
        duration: interval,
      ));
    }
    return TimerConfig(name: 'EMOM $minutes min', phases: phases);
  }

  /// MOBILIDADE. Segura cada posição X segundos, troca.
  static TimerConfig mobility({
    required List<String> positions,
    Duration hold = const Duration(seconds: 30),
  }) {
    final phases = <TimerPhase>[_prepare(5)];
    for (final pos in positions) {
      phases.add(TimerPhase(
        type: PhaseType.work,
        label: pos,
        duration: hold,
      ));
    }
    return TimerConfig(
      name: 'Mobility',
      phases: phases,
      warningSeconds: 5,
    );
  }

  /// DESCANSO DE SÉRIE. Uma fase só — o caso mais simples,
  /// e ainda assim o mesmo motor. (Ex: "Peito - 3min".)
  static TimerConfig restTimer({
    required String exercise,
    required Duration rest,
  }) {
    return TimerConfig(
      name: '$exercise - descanso',
      phases: [
        TimerPhase(
          type: PhaseType.rest,
          label: exercise,
          duration: rest,
        ),
      ],
    );
  }
}

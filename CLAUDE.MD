# CLAUDE.md — Fuezone

> Instruções persistentes do projeto. Carregadas automaticamente em toda
> sessão do Claude Code. Mantenha enxuto e atualizado.

## O que é o Fuezone

Timer de treino para esportes de luta, HIIT e condicionamento. App mobile
(iOS + Android) em Flutter. **Solo dev.**

**Visão de produto (importante para decisões de arquitetura):** o app NASCE
como timer (v1), mas vai EVOLUIR para um app completo de força e
condicionamento (S&C) para atletas de combate (v2: geração de programa por
IA, progressão, periodização, HealthKit). O timer será a feature de
execução dentro do app maior. **Não tome decisões que prendam o produto ao
timer** (ex: nomes, navegação, modelo de dados rígido demais).

## Stack

- **Flutter** (Dart 3.4+), iOS + Android.
- **Estado:** manter simples na v1. Sem framework pesado a menos que
  justificado. `setState` / `ValueNotifier` / streams bastam para o timer.
  (Riverpod só se a complexidade crescer — não adicionar por reflexo.)
- **Áudio:** just_audio + audio_session.
- **Tela ligada:** wakelock_plus.
- **Vibração:** vibration.
- **Persistência local:** shared_preferences na v1 (presets custom).
  Trocar por Isar/sqflite só se a estrutura pedir.
- **Ads:** google_mobile_ads.
- **Backend:** NENHUM na v1. Tudo roda no device. Go + AWS entram só na v2
  (geração de programa, assinatura, histórico). Firebase Auth/Firestore
  podem entrar antes, só para "conta leve" de reconversão — não agora.

## Arquitetura de pastas

```
lib/
  timer/      # motor do timer (models, engine, presets) — JÁ EXISTE
  audio/      # serviço que escuta eventos do engine e toca sons
  storage/    # persistência de presets custom (camada repository)
  ads/        # AdMob (interstitial fim de sessão)
  screens/    # telas
  widgets/    # componentes reutilizáveis
assets/sounds/
```

## O motor de timer (núcleo — já implementado)

Arquivos em `lib/timer/`:
- **timer_models.dart** — `TimerPhase` (type, label editável, duration),
  `TimerConfig` (name, lista de phases, warningSeconds), `PhaseType`.
- **timer_engine.dart** — `TimerEngine`: máquina de estados. Dois streams:
  `snapshots` (UI) e `events` (áudio). Status: idle/running/paused/finished.
- **timer_presets.dart** — `TimerPresets`: builders que viram fases.

**Princípio central — NÃO QUEBRAR:** existe UM motor só. Todo modo (luta,
HIIT, EMOM, mobilidade, descanso de série, custom) é apenas uma SEQUÊNCIA
DE FASES diferente. O engine não conhece "BJJ" nem "Tabata" — só percorre
fases. Ao adicionar um modo novo, adicione um builder de preset, NUNCA
lógica especial dentro do engine.

**Decisões técnicas do engine que devem ser preservadas:**
- Tempo ABSOLUTO (wall-clock), não decremento de contador. Mantém correto
  com app em background / ticks irregulares.
- O engine NÃO toca som e NÃO conhece AdMob. Só emite eventos. A camada de
  áudio e a de ads escutam os streams. Manter esse desacoplamento.

## Modos da v1

Luta (BJJ, boxe, muay thai, wrestling), HIIT/Tabata, EMOM, mobilidade,
descanso de série, e timer custom. Apresentação puxa para LUTA (é a
vitrine e a distribuição orgânica), mas o motor cobre todos.

## Features anti-reclamação (vieram de pesquisa real de usuários — priorizar)

1. **Áudio sobrepõe a música, não corta.** É o item nº1 que faz timer ser
   ruim. Usar audio_session com mixWithOthers (iOS) / sonification
   (Android). Ver setup nativo.
2. **Funciona com tela bloqueada.** UIBackgroundModes audio (iOS).
3. **Presets prontos** (não obrigar a configurar do zero).
4. **Nomear as fases** ("Peito", "Round 1") — campo label já existe.
5. **Cor de fundo / tela configurável** (alto contraste, legível de longe
   no tatame; modo escuro).
6. **Favoritos / presets salvos ordenáveis.**
7. **Aviso sonoro nos últimos segundos** (warningSeconds, já no engine).

## Monetização (v1)

- **Grátis com ads.** Objetivo da v1 é crescer base e validar uso, não
  receita.
- **Anúncio APENAS ao encerrar a sessão** (status `finished` / `stop()`).
  NUNCA durante um round ou descanso ativo — isso mata o app. Banner
  pequeno só na tela de configuração é aceitável; interstitial só no fim.
- **Sem assinatura na v1.** O mercado de timer tem aversão a assinatura e
  prefere compra única. Assinatura entra na v2, paga pelo valor recorrente
  do S&C (programa + progressão), não pelo timer.
- Reaproveitar setup AdMob/app-ads.txt do app anterior do dev (Holy
  Messages). Domínio do app-ads.txt agora é fuezone.com.

## Princípios de trabalho neste projeto

- **Não inche o escopo.** v1 é timer. Recursos de S&C (programa, progressão,
  periodização, HealthKit, histórico, social) são v2+ — não implementar
  agora, mesmo que pareçam fáceis. Se um pedido cresce além da v1-timer,
  sinalize antes de codar.
- **Simplicidade > robustez prematura.** Não montar backend, auth, ou
  arquitetura "para escalar" antes da feature pedir.
- **Camada de abstração nos dados:** repository para presets, para que a
  troca de storage local → API (v2) não exija reescrever a lógica.
- Rodar `flutter analyze` após mudanças (pegar imports não usados /
  dependências faltando).
- Usar Plan Mode para tarefas que tocam vários arquivos; revisar o plano
  antes de executar.

## Ordem de desenvolvimento

1. Motor de timer ✅ (pronto)
2. Camada de áudio (escuta `events`, toca sons com sobreposição) ← PRÓXIMO
3. Tela de execução (prova visual: número grande, cor muda no descanso)
4. Seleção de modo + presets prontos
5. Persistência de presets custom (repository + shared_preferences)
6. AdMob no fim de sessão
7. (Opcional) Conta leve para reconversão na v2

## Arquitetura e boas práticas de código

Objetivo: código limpo e testável SEM over-engineering. Aplicar os
princípios de Clean Architecture que dão retorno real, e cortar o
cerimonial que infla um app pequeno. **Para a v1, simplicidade pragmática
vence pureza arquitetural.**

### Princípios que SEGUIMOS (valem o esforço)

- **Dependências apontam para dentro.** UI depende da lógica; a lógica
  (engine, regras) NÃO depende de Flutter, de plugins, nem de UI. O
  `TimerEngine` já segue isso: é Dart puro, sem import de Flutter. Manter.
- **Separação em 3 camadas leves:**
  - *Domínio:* models + lógica pura (timer/, regras). Sem Flutter, sem I/O.
  - *Dados:* repositories que escondem a fonte (shared_preferences hoje,
    API amanhã). A camada acima não sabe de onde vem o dado.
  - *Apresentação:* widgets/telas. Só renderiza e captura input.
- **Repository com interface SÓ onde a fonte vai mudar.** Presets terão
  storage local → API na v2: vale a interface (`PresetRepository` abstrata
  + `LocalPresetRepository`). Para o resto, NÃO criar interface por reflexo.
- **Lógica de negócio fora dos widgets.** Um widget nunca calcula
  progressão de fase nem decide quando tocar som — isso é do engine/serviço.
- **Imutabilidade nos models.** Campos `final`, `copyWith` para alterar
  (já feito em TimerPhase). Facilita raciocínio e testes.
- **Nomes explícitos** > comentários. Código que se explica.

### O que NÃO fazer (over-engineering a evitar)

- **NÃO** criar use-case/interactor para cada ação trivial. "IniciarTimer"
  não precisa de uma classe UseCase só para chamar `engine.start()`.
- **NÃO** criar interface (abstract class) para algo com uma só
  implementação que não vai mudar. Interface sem segunda implementação
  prevista = ruído.
- **NÃO** adicionar gerenciador de estado pesado (Riverpod/Bloc) na v1 se
  streams + ValueNotifier resolvem. Reavaliar só quando o estado crescer.
- **NÃO** criar camadas de mapeamento (DTO ↔ entity) enquanto não há API.
  Quando o backend Go entrar (v2), aí sim os DTOs ganham sentido.
- **NÃO** abstrair "para o caso de precisar depois". Resolver o problema de
  hoje; refatorar quando a necessidade real aparecer (YAGNI).
- **NÃO** generalizar prematuramente. Se um padrão aparece 1-2 vezes,
  duplique; extraia abstração só na 3ª repetição (regra prática).

### Qualidade contínua

- Rodar `dart format .` e `flutter analyze` antes de considerar pronto;
  zero warnings.
- **Testes onde o risco mora:** o `TimerEngine` é o coração e tem lógica de
  tempo/transições — merece testes unitários (avanço de fase, pausa/retoma,
  disparo de warning, fim de sequência). UI não precisa de teste exaustivo
  na v1.
- Funções curtas, uma responsabilidade. Se um método passa de ~30-40
  linhas ou faz duas coisas, dividir.
- Tratar erros de I/O (storage, áudio) com try/catch e degradação suave —
  o timer NUNCA deve travar porque um som falhou ao carregar.
- Sem números mágicos espalhados; constantes nomeadas (durações padrão,
  IDs de ad, chaves de storage) em um lugar.

### Regra de ouro para este projeto

Antes de criar uma abstração, classe ou camada nova, pergunte: "isso
resolve um problema que EXISTE agora, ou um que IMAGINO que vai existir?"
Se for imaginado, não crie — anote como possibilidade e siga. A v1 precisa
ser enviada, não perfeita.

## Setup nativo crítico (não esquecer)

- iOS Info.plist: `UIBackgroundModes` → `audio`; `GADApplicationIdentifier`.
- Android Manifest: permissões VIBRATE, WAKE_LOCK; meta-data do AdMob App ID.
- Configurar AudioSession (ambient + mixWithOthers) antes de tocar sons.
- Durante o dev, usar SEMPRE os IDs de teste do AdMob.
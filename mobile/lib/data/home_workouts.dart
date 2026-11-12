import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../widgets/exercise_figure.dart';

/// Treinos para fazer em casa, sem equipamento: exercícios desenhados, tempo de cada um e
/// quatro níveis de intensidade.

enum HomeLevel {
  leve('Leve', 'Para começar ou voltar ao ritmo', 3.5, 50, Icons.spa_rounded, AppTheme.freshGradient),
  medio('Médio', 'Desafio na medida para o dia a dia', 5.0, 80, Icons.bolt_rounded, AppTheme.oceanGradient),
  alto('Alto', 'Ritmo forte, pouco descanso', 7.0, 120, Icons.local_fire_department_rounded, AppTheme.fireGradient),
  extremo('Extremo', 'HIIT e Tabata: só para quem aguenta', 9.0, 180, Icons.whatshot_rounded, AppTheme.berryGradient);

  const HomeLevel(this.label, this.blurb, this.met, this.baseXp, this.icon, this.gradient);

  final String label;
  final String blurb;

  /// Equivalente metabólico (MET) durante o esforço.
  final double met;

  /// XP ganho só por concluir um treino deste nível.
  final int baseXp;
  final IconData icon;
  final Gradient gradient;

  Color get color => AppTheme.glowOf(gradient);
}

/// MET durante o descanso entre exercícios (em pé, respirando).
const double restMet = 2.0;

class HomeExercise {
  const HomeExercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.how,
    required this.figure,
    required this.color,
  });

  final String id;
  final String name;
  final String muscle;

  /// Como executar, em uma frase curta.
  final String how;
  final FigureAnimation figure;
  final Color color;
}

class HomeStep {
  const HomeStep(this.exerciseId, this.workSeconds, this.restSeconds);

  final String exerciseId;
  final int workSeconds;

  /// Descanso depois do exercício (0 no último passo do treino).
  final int restSeconds;

  HomeExercise get exercise => homeExerciseById(exerciseId);
}

class HomeWorkout {
  const HomeWorkout({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.focus,
    required this.steps,
  });

  final String id;
  final String title;
  final String subtitle;
  final HomeLevel level;
  final String focus;
  final List<HomeStep> steps;

  int get totalSeconds => steps.fold(0, (a, s) => a + s.workSeconds + s.restSeconds);
  int get workSeconds => steps.fold(0, (a, s) => a + s.workSeconds);
  int get minutes => (totalSeconds / 60).round();

  /// Quantidade de exercícios diferentes.
  int get distinctExercises => steps.map((s) => s.exerciseId).toSet().length;

  /// Calorias estimadas: MET do nível durante o esforço e [restMet] durante o descanso.
  int estimateKcal(double weightKg) => kcalFor(level, workSeconds, totalSeconds - workSeconds, weightKg);
}

int kcalFor(HomeLevel level, int workSeconds, int restSeconds, double weightKg) {
  final metSeconds = level.met * workSeconds + restMet * restSeconds;
  return (metSeconds / 3600 * weightKg).round();
}

// ---------------------------------------------------------------------------------------------
// Poses (ângulos em graus: 0 baixo, 90 frente, 180 cima, 270/-90 trás).

const _stand = FigurePose(arm: [8, 12], arm2: [-6, 6], leg: [0, 0], leg2: [-5, -4]);
const _plankUp = FigurePose(torso: 115, arm: [0, 0], arm2: [2, 2], leg: [-65, -65], leg2: [-67, -67]);
const _crouchHands = FigurePose(torso: 110, arm: [0, 0], arm2: [3, 3], leg: [75, -20], leg2: [70, -22]);
const _lying = FigurePose(torso: 270, arm: [90, 90], arm2: [92, 92], leg: [130, 50], leg2: [135, 52]);

const _squatBottom = FigurePose(torso: 148, arm: [95, 95], arm2: [90, 92], leg: [80, -22], leg2: [75, -25]);

const _jumpUp = FigurePose(arm: [172, 176], arm2: [168, 172], leg: [2, -8], leg2: [-3, -10], lift: 0.1);

/// Exercícios, cada um com o desenho do movimento.
const homeExercises = <HomeExercise>[
  HomeExercise(
    id: 'polichinelo',
    name: 'Polichinelo',
    muscle: 'Corpo todo',
    how: 'Salte abrindo pernas e braços, depois feche. Pouse na ponta dos pés, sem travar os joelhos.',
    color: AppTheme.orange,
    figure: FigureAnimation([
      _stand,
      FigurePose(arm: [170, 175], arm2: [175, 180], leg: [22, 14], leg2: [-22, -14], lift: 0.05),
    ], cycleMs: 900),
  ),
  HomeExercise(
    id: 'marcha',
    name: 'Marcha no lugar',
    muscle: 'Aquecimento',
    how: 'Suba os joelhos alternando, balançando os braços em ritmo de caminhada.',
    color: AppTheme.teal,
    figure: FigureAnimation([
      FigurePose(arm: [-45, 35], arm2: [45, 100], leg: [88, 5], leg2: [0, 0]),
      FigurePose(arm: [45, 100], arm2: [-45, 35], leg: [0, 0], leg2: [88, 5]),
    ], cycleMs: 1200),
  ),
  HomeExercise(
    id: 'alongamento',
    name: 'Alongamento de braços',
    muscle: 'Mobilidade',
    how: 'Estique os braços para cima, alongando o corpo todo, e solte devagar respirando fundo.',
    color: AppTheme.cyan,
    figure: FigureAnimation([
      _stand,
      FigurePose(arm: [172, 176], arm2: [168, 175]),
    ], cycleMs: 2800),
  ),
  HomeExercise(
    id: 'agachamento',
    name: 'Agachamento',
    muscle: 'Pernas e glúteos',
    how: 'Pés na largura dos ombros. Leve o quadril para trás e para baixo, joelhos alinhados com os pés.',
    color: AppTheme.violet,
    figure: FigureAnimation([
      FigurePose(arm: [85, 88], arm2: [80, 85], leg: [0, 0], leg2: [-4, -3]),
      _squatBottom,
    ], cycleMs: 2200),
  ),
  HomeExercise(
    id: 'afundo',
    name: 'Afundo',
    muscle: 'Pernas e glúteos',
    how: 'Dê um passo à frente e desça até o joelho de trás quase tocar o chão. Troque de perna a cada repetição.',
    color: AppTheme.violet,
    figure: FigureAnimation([
      FigurePose(arm: [10, 40], arm2: [-10, 30], leg: [0, 0], leg2: [-5, -4]),
      FigurePose(arm: [10, 40], arm2: [-10, 30], leg: [85, -5], leg2: [-40, -75]),
    ], cycleMs: 2400),
  ),
  HomeExercise(
    id: 'flexao',
    name: 'Flexão de braço',
    muscle: 'Peito e braços',
    how: 'Corpo reto da cabeça aos pés. Desça o peito perto do chão e empurre de volta.',
    color: AppTheme.pink,
    figure: FigureAnimation([
      _plankUp,
      FigurePose(torso: 102, arm: [-60, 60], arm2: [-58, 58], leg: [-78, -78], leg2: [-80, -80]),
    ], cycleMs: 2200),
  ),
  HomeExercise(
    id: 'flexao_joelhos',
    name: 'Flexão com joelhos no chão',
    muscle: 'Peito e braços',
    how: 'Apoie os joelhos no chão, mantenha o tronco reto e faça a flexão. Boa versão para começar.',
    color: AppTheme.pink,
    figure: FigureAnimation([
      FigurePose(torso: 125, arm: [0, 0], arm2: [2, 2], leg: [-55, -120], leg2: [-57, -122]),
      FigurePose(torso: 107, arm: [-60, 60], arm2: [-58, 58], leg: [-73, -120], leg2: [-75, -122]),
    ], cycleMs: 2200),
  ),
  HomeExercise(
    id: 'prancha',
    name: 'Prancha',
    muscle: 'Abdômen',
    how: 'Apoie os antebraços no chão e segure o corpo reto. Não deixe o quadril cair nem subir demais.',
    color: AppTheme.amber,
    figure: FigureAnimation([
      FigurePose(torso: 102, arm: [0, 90], arm2: [2, 88], leg: [-78, -78], leg2: [-80, -80]),
      FigurePose(torso: 104, arm: [0, 90], arm2: [2, 88], leg: [-76, -76], leg2: [-78, -78]),
    ], cycleMs: 2400),
  ),
  HomeExercise(
    id: 'abdominal',
    name: 'Abdominal',
    muscle: 'Abdômen',
    how: 'Deitado, joelhos dobrados. Suba o tronco contraindo a barriga, sem puxar o pescoço.',
    color: AppTheme.amber,
    figure: FigureAnimation([
      _lying,
      FigurePose(torso: 245, arm: [105, 105], arm2: [100, 100], leg: [130, 50], leg2: [135, 52]),
    ], cycleMs: 1800),
  ),
  HomeExercise(
    id: 'ponte',
    name: 'Ponte de glúteo',
    muscle: 'Glúteos',
    how: 'Deitado, pés no chão. Suba o quadril até o corpo formar uma reta e contraia o glúteo.',
    color: AppTheme.green,
    figure: FigureAnimation([
      _lying,
      FigurePose(torso: 300, arm: [90, 90], arm2: [92, 92], leg: [90, 40], leg2: [92, 42]),
    ], cycleMs: 2200),
  ),
  HomeExercise(
    id: 'escalador',
    name: 'Escalador',
    muscle: 'Cardio e core',
    how: 'Em posição de flexão, leve os joelhos ao peito alternadamente, em ritmo de corrida.',
    color: AppTheme.red,
    figure: FigureAnimation([
      FigurePose(torso: 115, arm: [0, 0], arm2: [2, 2], leg: [45, -75], leg2: [-65, -65]),
      FigurePose(torso: 115, arm: [0, 0], arm2: [2, 2], leg: [-65, -65], leg2: [45, -75]),
    ], cycleMs: 800),
  ),
  HomeExercise(
    id: 'burpee',
    name: 'Burpee',
    muscle: 'Corpo todo',
    how: 'Agache, apoie as mãos, jogue as pernas para trás, volte e salte com os braços para cima.',
    color: AppTheme.red,
    figure: FigureAnimation([
      _stand,
      _crouchHands,
      _plankUp,
      _crouchHands,
      _jumpUp,
    ], cycleMs: 3000),
  ),
  HomeExercise(
    id: 'joelhos_altos',
    name: 'Joelhos altos',
    muscle: 'Cardio',
    how: 'Corra no lugar levando os joelhos à altura do quadril, braços acompanhando o ritmo.',
    color: AppTheme.orange,
    figure: FigureAnimation([
      FigurePose(arm: [-45, 35], arm2: [45, 100], leg: [100, -10], leg2: [0, 2], lift: 0.03),
      FigurePose(arm: [45, 100], arm2: [-45, 35], leg: [0, 2], leg2: [100, -10], lift: 0.03),
    ], cycleMs: 700),
  ),
  HomeExercise(
    id: 'salto_agachado',
    name: 'Agachamento com salto',
    muscle: 'Pernas e cardio',
    how: 'Agache e exploda para cima com os braços. Pouse suave, já descendo para o próximo.',
    color: AppTheme.violet,
    figure: FigureAnimation([
      FigurePose(torso: 150, arm: [-40, -30], arm2: [-35, -25], leg: [80, -22], leg2: [75, -25]),
      _jumpUp,
    ], cycleMs: 1000),
  ),
  HomeExercise(
    id: 'bicicleta',
    name: 'Abdominal bicicleta',
    muscle: 'Abdômen',
    how: 'Mãos atrás da cabeça. Leve o cotovelo ao joelho oposto enquanto estica a outra perna.',
    color: AppTheme.amber,
    figure: FigureAnimation([
      FigurePose(torso: 248, arm: [190, 250], arm2: [200, 255], leg: [100, 105], leg2: [150, 25]),
      FigurePose(torso: 248, arm: [190, 250], arm2: [200, 255], leg: [150, 25], leg2: [100, 105]),
    ], cycleMs: 1400),
  ),
  HomeExercise(
    id: 'elevacao_pernas',
    name: 'Elevação de pernas',
    muscle: 'Abdômen',
    how: 'Deitado, suba as pernas esticadas até a vertical e desça devagar sem encostar no chão.',
    color: AppTheme.amber,
    figure: FigureAnimation([
      FigurePose(torso: 270, arm: [90, 90], arm2: [92, 92], leg: [92, 92], leg2: [90, 90]),
      FigurePose(torso: 270, arm: [90, 90], arm2: [92, 92], leg: [178, 178], leg2: [176, 176]),
    ], cycleMs: 2400),
  ),
  HomeExercise(
    id: 'superman',
    name: 'Superman',
    muscle: 'Costas',
    how: 'De bruços, estique os braços à frente e erga braços e pernas ao mesmo tempo. Segure 1 segundo.',
    color: AppTheme.cyan,
    figure: FigureAnimation([
      FigurePose(torso: 90, arm: [90, 90], arm2: [92, 92], leg: [270, 270], leg2: [268, 268]),
      FigurePose(torso: 98, arm: [118, 120], arm2: [114, 118], leg: [256, 256], leg2: [258, 258]),
    ], cycleMs: 2200),
  ),
  HomeExercise(
    id: 'coice',
    name: 'Coice de glúteo',
    muscle: 'Glúteos',
    how: 'Em quatro apoios, leve uma perna para trás e para cima, com o joelho dobrado, e volte sem apoiar.',
    color: AppTheme.green,
    figure: FigureAnimation([
      FigurePose(torso: 108, arm: [0, 0], arm2: [2, 2], leg: [0, 270], leg2: [0, 270]),
      FigurePose(torso: 108, arm: [0, 0], arm2: [2, 2], leg: [-110, 180], leg2: [0, 270]),
    ], cycleMs: 2000),
  ),
  HomeExercise(
    id: 'socos',
    name: 'Socos (boxe)',
    muscle: 'Cardio e braços',
    how: 'Base firme, guarda alta. Solte socos rápidos alternando os braços, girando o tronco.',
    color: AppTheme.red,
    figure: FigureAnimation([
      FigurePose(torso: 176, arm: [50, 145], arm2: [30, 150], leg: [25, 8], leg2: [-30, -10]),
      FigurePose(torso: 168, arm: [90, 90], arm2: [30, 150], leg: [25, 8], leg2: [-30, -10]),
      FigurePose(torso: 176, arm: [50, 145], arm2: [30, 150], leg: [25, 8], leg2: [-30, -10]),
      FigurePose(torso: 184, arm: [50, 145], arm2: [92, 92], leg: [25, 8], leg2: [-30, -10]),
    ], cycleMs: 1600),
  ),
  HomeExercise(
    id: 'cadeirinha',
    name: 'Cadeirinha na parede',
    muscle: 'Pernas',
    how: 'Costas na parede, joelhos a 90°, como se estivesse sentado numa cadeira. Segure a posição.',
    color: AppTheme.violet,
    figure: FigureAnimation([
      FigurePose(arm: [10, 20], arm2: [6, 18], leg: [90, 0], leg2: [88, 2]),
      FigurePose(torso: 179, arm: [14, 30], arm2: [10, 26], leg: [90, 0], leg2: [88, 2]),
    ], wall: true, cycleMs: 2400),
  ),
  HomeExercise(
    id: 'pular_corda',
    name: 'Pular corda (sem corda)',
    muscle: 'Cardio',
    how: 'Pule leve na ponta dos pés, girando os punhos como se segurasse a corda.',
    color: AppTheme.orange,
    figure: FigureAnimation([
      FigurePose(arm: [20, 70], arm2: [15, 65], leg: [0, 0], leg2: [-3, -3]),
      FigurePose(arm: [20, 70], arm2: [15, 65], leg: [0, -25], leg2: [-3, -28], lift: 0.05),
    ], cycleMs: 600),
  ),
];

final Map<String, HomeExercise> _exerciseIndex = {for (final e in homeExercises) e.id: e};

HomeExercise homeExerciseById(String id) {
  final e = _exerciseIndex[id];
  if (e == null) throw ArgumentError('Exercício de treino em casa desconhecido: $id');
  return e;
}

// ---------------------------------------------------------------------------------------------
// Treinos

/// Circuito: cada exercício por [work] s com [rest] s de descanso, repetido [rounds] vezes.
/// O último passo não tem descanso.
List<HomeStep> _circuit(int work, int rest, List<String> ids, {int rounds = 1}) {
  final steps = <HomeStep>[
    for (var r = 0; r < rounds; r++)
      for (final id in ids) HomeStep(id, work, rest),
  ];
  final last = steps.removeLast();
  steps.add(HomeStep(last.exerciseId, last.workSeconds, 0));
  return steps;
}

/// Tabata: pares de exercícios alternando 20 s de esforço e 10 s de descanso, 4 vezes cada.
List<HomeStep> _tabata(List<(String, String)> pairs) {
  final steps = <HomeStep>[];
  for (final (a, b) in pairs) {
    for (var i = 0; i < 4; i++) {
      steps
        ..add(HomeStep(a, 20, 10))
        ..add(HomeStep(b, 20, 10));
    }
  }
  final last = steps.removeLast();
  steps.add(HomeStep(last.exerciseId, last.workSeconds, 0));
  return steps;
}

final homeWorkouts = <HomeWorkout>[
  // ---- Leve
  HomeWorkout(
    id: 'leve-corpo',
    title: 'Despertar do corpo',
    subtitle: 'Movimentos simples para o corpo todo',
    level: HomeLevel.leve,
    focus: 'Corpo todo',
    steps: _circuit(30, 30, ['marcha', 'agachamento', 'ponte', 'flexao_joelhos', 'abdominal', 'alongamento'], rounds: 2),
  ),
  HomeWorkout(
    id: 'leve-pernas',
    title: 'Pernas e glúteos leve',
    subtitle: 'Fortalece sem impacto nenhum',
    level: HomeLevel.leve,
    focus: 'Pernas e glúteos',
    steps: _circuit(30, 30, ['marcha', 'agachamento', 'ponte', 'afundo', 'coice', 'cadeirinha'], rounds: 2),
  ),
  HomeWorkout(
    id: 'leve-abdomen',
    title: 'Barriga em movimento',
    subtitle: 'Abdômen e postura, no seu ritmo',
    level: HomeLevel.leve,
    focus: 'Abdômen',
    steps: _circuit(30, 30, ['abdominal', 'elevacao_pernas', 'prancha', 'ponte', 'bicicleta'], rounds: 2),
  ),
  // ---- Médio
  HomeWorkout(
    id: 'medio-corpo',
    title: 'Corpo todo',
    subtitle: 'Cardio, força e core em um circuito',
    level: HomeLevel.medio,
    focus: 'Corpo todo',
    steps: _circuit(
      40,
      20,
      ['polichinelo', 'agachamento', 'flexao', 'afundo', 'prancha', 'joelhos_altos', 'abdominal', 'superman'],
      rounds: 2,
    ),
  ),
  HomeWorkout(
    id: 'medio-pernas',
    title: 'Pernas de aço',
    subtitle: 'Agachamentos, afundos e glúteos',
    level: HomeLevel.medio,
    focus: 'Pernas e glúteos',
    steps: _circuit(40, 20, ['agachamento', 'afundo', 'ponte', 'coice', 'cadeirinha', 'pular_corda'], rounds: 2),
  ),
  HomeWorkout(
    id: 'medio-core',
    title: 'Core firme',
    subtitle: 'Abdômen e lombar trabalhando juntos',
    level: HomeLevel.medio,
    focus: 'Abdômen',
    steps: _circuit(40, 20, ['prancha', 'bicicleta', 'elevacao_pernas', 'escalador', 'superman', 'abdominal'], rounds: 2),
  ),
  // ---- Alto
  HomeWorkout(
    id: 'alto-hiit',
    title: 'HIIT queima-gordura',
    subtitle: 'Alta intensidade, descanso curto',
    level: HomeLevel.alto,
    focus: 'Cardio',
    steps: _circuit(40, 15, ['polichinelo', 'salto_agachado', 'escalador', 'joelhos_altos', 'burpee'], rounds: 3),
  ),
  HomeWorkout(
    id: 'alto-superiores',
    title: 'Peito, braços e core',
    subtitle: 'Flexões, prancha e boxe',
    level: HomeLevel.alto,
    focus: 'Parte de cima',
    steps: _circuit(45, 15, ['flexao', 'prancha', 'escalador', 'superman', 'socos'], rounds: 3),
  ),
  HomeWorkout(
    id: 'alto-pernas',
    title: 'Pernas explosivas',
    subtitle: 'Saltos e força para as pernas',
    level: HomeLevel.alto,
    focus: 'Pernas e glúteos',
    steps: _circuit(45, 15, ['salto_agachado', 'afundo', 'agachamento', 'cadeirinha', 'pular_corda', 'coice'], rounds: 3),
  ),
  // ---- Extremo
  HomeWorkout(
    id: 'extremo-tabata',
    title: 'Tabata inferno',
    subtitle: '20 s de esforço total, 10 s de descanso',
    level: HomeLevel.extremo,
    focus: 'Cardio',
    steps: _tabata([('burpee', 'escalador'), ('salto_agachado', 'joelhos_altos'), ('polichinelo', 'flexao')]),
  ),
  HomeWorkout(
    id: 'extremo-burpee',
    title: 'Desafio burpee',
    subtitle: 'Burpees, flexões e saltos sem trégua',
    level: HomeLevel.extremo,
    focus: 'Corpo todo',
    steps: _circuit(45, 15, ['burpee', 'flexao', 'salto_agachado', 'escalador', 'burpee', 'joelhos_altos'], rounds: 3),
  ),
  HomeWorkout(
    id: 'extremo-total',
    title: 'Full power 30',
    subtitle: '30 minutos para testar seu limite',
    level: HomeLevel.extremo,
    focus: 'Corpo todo',
    steps: _circuit(
      45,
      15,
      [
        'polichinelo',
        'burpee',
        'afundo',
        'flexao',
        'salto_agachado',
        'escalador',
        'prancha',
        'joelhos_altos',
        'bicicleta',
        'superman',
      ],
      rounds: 3,
    ),
  ),
];

HomeWorkout homeWorkoutById(String id) => homeWorkouts.firstWhere((w) => w.id == id);

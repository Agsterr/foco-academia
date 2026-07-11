import type { WeekDay } from "./api";

export type MuscleTag =
  | "PEITO"
  | "COSTAS"
  | "PERNAS"
  | "PANTURRILHA"
  | "GLUTEOS"
  | "OMBROS"
  | "BICEPS"
  | "TRICEPS"
  | "ABDOMEN"
  | "CARDIO"
  | "FUNCIONAL";

/** Objetivo do exercício — facilita filtrar na montagem. */
export type ExerciseGoal = "FORCA" | "HIPERTROFIA" | "CARDIO" | "CORE" | "FUNCIONAL";

export interface LibraryExercise {
  id: string;
  name: string;
  muscle: MuscleTag;
  goal: ExerciseGoal;
  description: string;
  sets: string;
  reps: string;
  duration?: string;
  variationNotes?: string;
  /** Observação / dica para o aluno */
  notes: string;
}

export const muscleLabels: Record<MuscleTag, string> = {
  PEITO: "Peito",
  COSTAS: "Costas",
  PERNAS: "Pernas",
  PANTURRILHA: "Panturrilha",
  GLUTEOS: "Glúteos",
  OMBROS: "Ombros",
  BICEPS: "Bíceps",
  TRICEPS: "Tríceps",
  ABDOMEN: "Abdômen",
  CARDIO: "Cardio",
  FUNCIONAL: "Funcional",
};

/** Ordem de exibição na biblioteca (do que o instrutor mais usa). */
export const muscleOrder: MuscleTag[] = [
  "PEITO",
  "COSTAS",
  "PERNAS",
  "PANTURRILHA",
  "GLUTEOS",
  "OMBROS",
  "BICEPS",
  "TRICEPS",
  "ABDOMEN",
  "CARDIO",
  "FUNCIONAL",
];

export const goalLabels: Record<ExerciseGoal, string> = {
  FORCA: "Força",
  HIPERTROFIA: "Hipertrofia",
  CARDIO: "Cardio",
  CORE: "Core",
  FUNCIONAL: "Funcional",
};

function ex(
  id: string,
  name: string,
  muscle: MuscleTag,
  goal: ExerciseGoal,
  description: string,
  sets: string,
  reps: string,
  notes: string,
  extra?: { duration?: string; variationNotes?: string }
): LibraryExercise {
  return {
    id,
    name,
    muscle,
    goal,
    description,
    sets,
    reps,
    notes,
    duration: extra?.duration,
    variationNotes: extra?.variationNotes,
  };
}

export const EXERCISE_LIBRARY: LibraryExercise[] = [
  // ——— Peito ———
  ex("peito-supino-reto", "Supino reto com barra", "PEITO", "HIPERTROFIA",
    "Deitado no banco, desça a barra até o peito e empurre até quase estender os cotovelos.",
    "4", "8-10", "Escápulas retraídas; não quicar a barra no peito."),
  ex("peito-supino-inclinado", "Supino inclinado com halteres", "PEITO", "HIPERTROFIA",
    "Banco a ~30–45°. Empurre os halteres para cima alinhados ao peito superior.",
    "4", "10", "Controle a descida em 2–3 segundos."),
  ex("peito-supino-declinado", "Supino declinado", "PEITO", "HIPERTROFIA",
    "Banco declinado; desça a barra até a parte inferior do peito e empurre.",
    "3", "10", "Trave os pés bem no apoio do banco."),
  ex("peito-crucifixo", "Crucifixo no banco", "PEITO", "HIPERTROFIA",
    "Abra os braços em arco amplo e feche acima do peito sem bater os pesos.",
    "3", "12", "Cotovelos levemente flexionados o tempo todo."),
  ex("peito-crossover", "Crossover na polia", "PEITO", "HIPERTROFIA",
    "Puxe as alças de cima para baixo cruzando à frente do tronco.",
    "3", "12-15", "Foque no peitoral, não nos ombros."),
  ex("peito-peck-deck", "Peck deck (voador)", "PEITO", "HIPERTROFIA",
    "Una os braços à frente do peito na máquina e volte com controle.",
    "3", "12-15", "Não bata as alças no fechamento."),
  ex("peito-flexao", "Flexão de braço", "PEITO", "FORCA",
    "Corpo alinhado; desça o peito perto do chão e suba empurrando o solo.",
    "3", "12-15", "Joelho no chão se precisar manter a forma."),
  ex("peito-supino-maquina", "Supino na máquina", "PEITO", "HIPERTROFIA",
    "Empurre as alças à frente do peito com amplitude confortável.",
    "3", "10-12", "Bom para iniciantes — trajetória guiada."),
  ex("peito-pullover", "Pullover com halter", "PEITO", "HIPERTROFIA",
    "Deitado, desça o peso atrás da cabeça e volte até acima do peito.",
    "3", "12", "Cotovelos semiflexionados; não arqueie demais a lombar."),

  // ——— Costas ———
  ex("costas-puxada", "Puxada frontal", "COSTAS", "HIPERTROFIA",
    "Puxe a barra até a clavícula, cotovelos para baixo e para trás.",
    "4", "10", "Peito aberto; não incline demais o tronco."),
  ex("costas-remada-curvada", "Remada curvada", "COSTAS", "HIPERTROFIA",
    "Tronco inclinado ~45°. Puxe a barra/halteres até o umbigo.",
    "4", "8-10", "Coluna neutra; sem balanço."),
  ex("costas-remada-unilateral", "Remada unilateral com halter", "COSTAS", "HIPERTROFIA",
    "Apoie um joelho no banco e puxe o peso até o quadril.",
    "3", "10-12", "Evite girar o tronco."),
  ex("costas-pulldown", "Pulldown com triângulo", "COSTAS", "HIPERTROFIA",
    "Pegada neutra; puxe até o peito superior.",
    "3", "12", "Sinta as escápulas se aproximarem."),
  ex("costas-barra-fixa", "Barra fixa (assistida se precisar)", "COSTAS", "FORCA",
    "Puxe o corpo até o queixo passar a barra; desça controlado.",
    "3", "6-10", "Use elástico ou máquina assistida se necessário."),
  ex("costas-remada-baixa", "Remada baixa no cabo", "COSTAS", "HIPERTROFIA",
    "Sentado, puxe o cabo até o umbigo mantendo o tronco estável.",
    "3", "12", "Peito aberto; não arredonde as costas."),
  ex("costas-levantamento-terra", "Levantamento terra", "COSTAS", "FORCA",
    "Barra próxima às canelas; suba empurrando o chão com os pés.",
    "4", "6-8", "Coluna neutra; comece leve se for iniciante."),
  ex("costas-puxada-aberta", "Puxada aberta", "COSTAS", "HIPERTROFIA",
    "Pegada mais larga que os ombros; puxe até o peito.",
    "3", "10-12", "Cotovelos para baixo, não para trás demais."),
  ex("costas-remada-cavalinho", "Remada cavalinho (T-bar)", "COSTAS", "HIPERTROFIA",
    "Tronco inclinado; puxe a barra em direção ao peito/umbigo.",
    "3", "10", "Peito aberto; sem balançar o tronco."),

  // ——— Pernas (quadríceps / posterior) ———
  ex("pernas-agachamento", "Agachamento livre", "PERNAS", "FORCA",
    "Desça até coxas paralelas ao chão, joelhos alinhados aos pés.",
    "4", "8-10", "Peso nos calcanhares; peito erguido."),
  ex("pernas-leg-press", "Leg press 45°", "PERNAS", "HIPERTROFIA",
    "Desça controlado até ~90° nos joelhos e empurre sem travar.",
    "4", "12", "Não deixe o quadril levantar do assento."),
  ex("pernas-extensora", "Cadeira extensora", "PERNAS", "HIPERTROFIA",
    "Estenda os joelhos até quase travar e desça devagar.",
    "3", "12-15", "Útil no final para queimar o quadríceps."),
  ex("pernas-flexora", "Mesa flexora", "PERNAS", "HIPERTROFIA",
    "Flexione os joelhos trazendo os calcanhares em direção ao glúteo.",
    "3", "12", "Quadril fixo no banco."),
  ex("pernas-afundo", "Afundo caminhando", "PERNAS", "HIPERTROFIA",
    "Passo longo à frente, joelho de trás quase toca o chão.",
    "3", "10", "10 por perna. Tronco ereto."),
  ex("pernas-stiff", "Stiff (terra romeno)", "PERNAS", "HIPERTROFIA",
    "Quadril para trás, barra próxima às pernas; sinta o posterior.",
    "3", "10-12", "Joelhos levemente flexionados; sem arredondar a lombar."),
  ex("pernas-hack", "Hack squat", "PERNAS", "HIPERTROFIA",
    "Desça na máquina até profundidade confortável e empurre pelos calcanhares.",
    "3", "10-12", "Joelho alinhado ao pé; não trave no topo."),
  ex("pernas-agachamento-goblet", "Agachamento goblet", "PERNAS", "FORCA",
    "Segure um halter no peito e agache mantendo o tronco ereto.",
    "3", "12", "Ótimo para iniciantes e mobilidade."),
  ex("pernas-passada", "Passada no lugar", "PERNAS", "HIPERTROFIA",
    "Alterne as pernas no afundo estático.",
    "3", "10", "10 por perna. Joelho da frente sobre o tornozelo."),
  ex("pernas-adutora", "Cadeira adutora", "PERNAS", "HIPERTROFIA",
    "Una as pernas contra a resistência da máquina.",
    "3", "12-15", "Movimento controlado; sem balanço."),
  ex("pernas-abdutora", "Cadeira abdutora", "PERNAS", "HIPERTROFIA",
    "Abra as pernas contra a resistência da máquina.",
    "3", "12-15", "Tronco estável no encosto."),

  // ——— Panturrilha ———
  ex("pant-em-pe", "Panturrilha em pé", "PANTURRILHA", "HIPERTROFIA",
    "Suba na ponta dos pés até contrair e desça completo.",
    "4", "15-20", "Amplitude total; pause 1s no topo."),
  ex("pant-sentado", "Panturrilha sentado", "PANTURRILHA", "HIPERTROFIA",
    "Na máquina sentada, estenda os tornozelos e desça com controle.",
    "4", "15-20", "Foca o sóleo; amplitude completa."),
  ex("pant-leg-press", "Panturrilha no leg press", "PANTURRILHA", "HIPERTROFIA",
    "Só a ponta dos pés na plataforma; empurre e desça.",
    "3", "15-20", "Não trave o joelho."),
  ex("pant-unilateral", "Panturrilha unilateral", "PANTURRILHA", "HIPERTROFIA",
    "Uma perna de cada vez, subindo na ponta do pé.",
    "3", "12-15", "12–15 por perna. Equilíbrio firme."),

  // ——— Glúteos ———
  ex("gluteo-hip-thrust", "Elevação de quadril (hip thrust)", "GLUTEOS", "HIPERTROFIA",
    "Costas no banco, empurre o quadril para cima contraído o glúteo.",
    "3", "12", "Queixo neutro; não hiperextenda a lombar."),
  ex("gluteo-ponte", "Ponte de glúteo", "GLUTEOS", "HIPERTROFIA",
    "Deitado, pés no chão; eleve o quadril e contraia.",
    "3", "15", "Bom aquecimento ou finalizador."),
  ex("gluteo-abducao", "Abdução de quadril (cabo/elástico)", "GLUTEOS", "HIPERTROFIA",
    "Afaste a perna lateralmente contra a resistência.",
    "3", "12-15", "Tronco estável; movimento no quadril."),
  ex("gluteo-coice", "Coice no cabo", "GLUTEOS", "HIPERTROFIA",
    "Estenda o quadril para trás com a perna no cabo.",
    "3", "12", "12 por perna. Sem arquear a lombar."),

  // ——— Ombros ———
  ex("ombros-desenvolvimento", "Desenvolvimento com halteres", "OMBROS", "HIPERTROFIA",
    "Empurre os pesos acima da cabeça sem arquear a lombar.",
    "4", "8-10", "Core firme; não bata os pesos no topo."),
  ex("ombros-elevacao-lateral", "Elevação lateral", "OMBROS", "HIPERTROFIA",
    "Eleve os braços até a linha dos ombros, leve flexão nos cotovelos.",
    "3", "12-15", "Polegares levemente para baixo (jarro)."),
  ex("ombros-elevacao-frontal", "Elevação frontal", "OMBROS", "HIPERTROFIA",
    "Levante o peso à frente até a altura dos ombros.",
    "3", "12", "Alternado ou com barra — sem balanço."),
  ex("ombros-face-pull", "Face pull", "OMBROS", "FORCA",
    "Puxe a corda em direção ao rosto, cotovelos altos.",
    "3", "15", "Ótimo para saúde do ombro e postura."),
  ex("ombros-arnold", "Desenvolvimento Arnold", "OMBROS", "HIPERTROFIA",
    "Comece com palmas à frente do rosto e gire ao empurrar para cima.",
    "3", "10-12", "Movimento fluido; carga moderada."),
  ex("ombros-remada-alta", "Remada alta", "OMBROS", "HIPERTROFIA",
    "Puxe a barra até a altura do peito, cotovelos altos.",
    "3", "12", "Não suba além da linha dos ombros se houver desconforto."),
  ex("ombros-desenvolvimento-maquina", "Desenvolvimento na máquina", "OMBROS", "HIPERTROFIA",
    "Empurre as alças para cima na máquina de ombros.",
    "3", "10-12", "Bom para iniciantes."),
  ex("ombros-crucifixo-inverso", "Crucifixo inverso", "OMBROS", "HIPERTROFIA",
    "Abra os braços para trás trabalhando o deltoide posterior.",
    "3", "12-15", "Peito apoiado se for no banco; sem balanço."),

  // ——— Bíceps ———
  ex("biceps-rosca-direta", "Rosca direta com barra", "BICEPS", "HIPERTROFIA",
    "Cotovelos fixos ao lado do corpo; suba e desça controlado.",
    "3", "10-12", "Não balance o tronco."),
  ex("biceps-rosca-alternada", "Rosca alternada com halteres", "BICEPS", "HIPERTROFIA",
    "Alterne os braços com leve rotação do punho no topo.",
    "3", "12", "Cotovelos estáveis."),
  ex("biceps-rosca-martelo", "Rosca martelo", "BICEPS", "HIPERTROFIA",
    "Pegada neutra (polegares para cima) durante todo o movimento.",
    "3", "12", "Trabalha também o braquial."),
  ex("biceps-rosca-scott", "Rosca Scott", "BICEPS", "HIPERTROFIA",
    "Braços apoiados no banco Scott; amplitude completa sem esticar demais.",
    "3", "10", "Evite hiperextensão no fundo."),
  ex("biceps-rosca-concentrada", "Rosca concentrada", "BICEPS", "HIPERTROFIA",
    "Cotovelo apoiado na coxa; suba o halter até o peito.",
    "3", "10-12", "Isolamento — sem balanço."),

  // ——— Tríceps ———
  ex("triceps-pulley", "Tríceps na polia (corda)", "TRICEPS", "HIPERTROFIA",
    "Estenda os cotovelos para baixo abrindo a corda no final.",
    "3", "12-15", "Cotovelos colados ao tronco."),
  ex("triceps-testa", "Tríceps testa", "TRICEPS", "HIPERTROFIA",
    "Deitado, flexione os cotovelos levando a barra à testa e estenda.",
    "3", "10-12", "Cotovelos apontando para o teto."),
  ex("triceps-frances", "Tríceps francês", "TRICEPS", "HIPERTROFIA",
    "Halter atrás da cabeça; estenda os cotovelos sem abrir demais.",
    "3", "12", "Cotovelos próximos à orelha."),
  ex("triceps-banco", "Tríceps no banco", "TRICEPS", "HIPERTROFIA",
    "Mãos no banco atrás do corpo; flexione e estenda os cotovelos.",
    "3", "12", "Quadril próximo ao banco."),
  ex("triceps-coice", "Tríceps coice", "TRICEPS", "HIPERTROFIA",
    "Tronco inclinado; estenda o cotovelo para trás com o halter.",
    "3", "12", "Cotovelo fixo ao lado do tronco."),

  // ——— Abdômen ———
  ex("abd-prancha", "Prancha", "ABDOMEN", "CORE",
    "Corpo reto apoiado nos antebraços; contraia o abdômen.",
    "3", "0", "Não deixe o quadril cair.", { duration: "40-60s" }),
  ex("abd-crunch", "Abdominal crunch", "ABDOMEN", "CORE",
    "Eleve o tronco enrolando a coluna, sem puxar o pescoço.",
    "3", "15-20", "Expire na subida."),
  ex("abd-elevacao-pernas", "Elevação de pernas", "ABDOMEN", "CORE",
    "Deitado ou pendurado, eleve as pernas até ~90° sem balançar.",
    "3", "12-15", "Lombar pressionada no chão se for no solo."),
  ex("abd-bicicleta", "Abdominal bicicleta", "ABDOMEN", "CORE",
    "Cotovelo ao joelho oposto em movimento alternado.",
    "3", "20", "20 no total (10 por lado). Ritmo controlado."),
  ex("abd-russian-twist", "Russian twist", "ABDOMEN", "CORE",
    "Sentado, incline o tronco e gire de um lado para o outro.",
    "3", "16", "16 toques no chão (8 por lado). Pode usar anilha."),
  ex("abd-prancha-lateral", "Prancha lateral", "ABDOMEN", "CORE",
    "Apoiado em um antebraço, corpo alinhado de lado.",
    "3", "0", "20–40s por lado.", { duration: "20-40s" }),

  // ——— Cardio ———
  ex("cardio-esteira", "Esteira — caminhada inclinada", "CARDIO", "CARDIO",
    "Caminhada em ritmo constante com inclinação moderada.",
    "1", "0", "Mantenha conversa possível (zona aeróbica).", { duration: "20-30 min" }),
  ex("cardio-bike", "Bike ergométrica", "CARDIO", "CARDIO",
    "Pedale em cadência estável com resistência confortável.",
    "1", "0", "Ajuste o banco para joelho quase estendido.", { duration: "20-25 min" }),
  ex("cardio-eliptico", "Elíptico", "CARDIO", "CARDIO",
    "Movimento contínuo de pernas e braços sem impacto.",
    "1", "0", "Postura ereta; sem apoiar o peso nos braços.", { duration: "20 min" }),
  ex("cardio-intervalado", "Intervalado caminhada/corrida", "CARDIO", "CARDIO",
    "2 min caminhada + 1 min corrida leve, repetir.",
    "1", "0", "Ajuste o ritmo ao condicionamento do aluno.", { duration: "20-25 min" }),
  ex("cardio-escada", "Escada / stairclimber", "CARDIO", "CARDIO",
    "Suba em ritmo constante sem apoiar o peso nos braços.",
    "1", "0", "Postura ereta; passos completos.", { duration: "10-15 min" }),
  ex("cardio-remada", "Remo ergômetro", "CARDIO", "CARDIO",
    "Puxe com as pernas primeiro, depois tronco e braços.",
    "1", "0", "Sequência: pernas → tronco → braços.", { duration: "10-15 min" }),
  ex("cardio-corda", "Pular corda", "CARDIO", "CARDIO",
    "Saltos leves e ritmados; pouso na ponta dos pés.",
    "3", "0", "Intervalos curtos se for iniciante.", { duration: "1-2 min" }),

  // ——— Funcional ———
  ex("func-burpee", "Burpee (adaptado)", "FUNCIONAL", "FUNCIONAL",
    "Agache, apoie as mãos, estenda as pernas e volte.",
    "3", "8-10", "Pode remover o salto se necessário."),
  ex("func-farmers", "Farmers walk", "FUNCIONAL", "FUNCIONAL",
    "Caminhe com pesos nas mãos mantendo tronco ereto.",
    "3", "0", "Ombros para baixo; passos curtos.", { duration: "30-40s" }),
  ex("func-kettlebell-swing", "Kettlebell swing", "FUNCIONAL", "FUNCIONAL",
    "Quadril para trás e para frente; o peso sobe pelo impulso do quadril.",
    "3", "12-15", "Não levante com os braços — use o quadril."),
  ex("func-mountain-climber", "Mountain climber", "FUNCIONAL", "FUNCIONAL",
    "Em prancha, alterne os joelhos em direção ao peito.",
    "3", "20", "Quadril estável; 20 no total."),
];

/** Alias legado: ids antigos ainda usados em fichas salvas/templates. */
const LEGACY_ID_ALIASES: Record<string, string> = {
  "pernas-panturrilha": "pant-em-pe",
  "pernas-gluteo-ponte": "gluteo-hip-thrust",
};

export interface WeekTemplate {
  id: string;
  name: string;
  description: string;
  /** Observação geral da ficha para o aluno */
  studentNotes: string;
  kind: "FORCA" | "CARDIO" | "MISTO";
  /** WEEK = troca a semana inteira; DAY = aplica só no dia selecionado */
  scope: "WEEK" | "DAY";
  days: Partial<Record<WeekDay, { muscleGroup: string; notes: string; restDay?: boolean; exerciseIds: string[] }>>;
}

function byId(id: string): LibraryExercise {
  const resolved = LEGACY_ID_ALIASES[id] ?? id;
  const found = EXERCISE_LIBRARY.find((e) => e.id === resolved);
  if (!found) throw new Error(`Exercício não encontrado: ${id}`);
  return found;
}

function dayModel(
  id: string,
  name: string,
  muscleGroup: string,
  notes: string,
  exerciseIds: string[],
  studentNotes?: string
): WeekTemplate {
  return {
    id,
    name,
    description: `4–6 exercícios de ${muscleGroup.toLowerCase()} — aplica no dia atual.`,
    studentNotes:
      studentNotes ??
      "Aqueça 5 min. Descanse 60–90s entre séries. Priorize a execução.",
    kind: "FORCA",
    scope: "DAY",
    days: {
      MONDAY: { muscleGroup, notes, exerciseIds },
    },
  };
}

/** Fichas prontas da semana + modelos de dia por músculo. */
export const WEEK_TEMPLATES: WeekTemplate[] = [
  {
    id: "forca-abc",
    name: "Força — 2 músculos/dia",
    description: "Seg–Sex com 2 grupos e 4 exercícios cada. Sáb cardio, Dom descanso.",
    studentNotes:
      "Descanse 60–90s entre séries. Priorize a execução. Se doer articulação (não músculo), pare e avise o instrutor.",
    kind: "FORCA",
    scope: "WEEK",
    days: {
      MONDAY: {
        muscleGroup: "Peito + Tríceps",
        notes: "Foque no peito primeiro; tríceps no final com carga moderada.",
        exerciseIds: [
          "peito-supino-reto",
          "peito-supino-inclinado",
          "peito-crucifixo",
          "peito-crossover",
          "triceps-pulley",
          "triceps-testa",
          "triceps-frances",
          "triceps-banco",
        ],
      },
      TUESDAY: {
        muscleGroup: "Costas + Bíceps",
        notes: "Puxe com as costas, não com os braços. Bíceps depois das puxadas.",
        exerciseIds: [
          "costas-puxada",
          "costas-remada-curvada",
          "costas-remada-unilateral",
          "costas-pulldown",
          "biceps-rosca-direta",
          "biceps-rosca-alternada",
          "biceps-rosca-martelo",
          "biceps-rosca-scott",
        ],
      },
      WEDNESDAY: {
        muscleGroup: "Pernas + Abdômen",
        notes: "Agachamento com profundidade confortável. Finalize com core.",
        exerciseIds: [
          "pernas-agachamento",
          "pernas-leg-press",
          "pernas-extensora",
          "pernas-flexora",
          "pernas-afundo",
          "abd-prancha",
          "abd-crunch",
          "func-farmers",
        ],
      },
      THURSDAY: {
        muscleGroup: "Ombros + Abdômen",
        notes: "Evite carga excessiva no desenvolvimento se houver desconforto no ombro.",
        exerciseIds: [
          "ombros-desenvolvimento",
          "ombros-elevacao-lateral",
          "ombros-elevacao-frontal",
          "ombros-face-pull",
          "abd-prancha",
          "abd-crunch",
          "func-farmers",
          "peito-flexao",
        ],
      },
      FRIDAY: {
        muscleGroup: "Bíceps + Tríceps (braços)",
        notes: "Dia de braços: controle a negativa. Não precisa de carga máxima.",
        exerciseIds: [
          "biceps-rosca-direta",
          "biceps-rosca-martelo",
          "biceps-rosca-alternada",
          "biceps-rosca-scott",
          "triceps-pulley",
          "triceps-testa",
          "triceps-frances",
          "triceps-banco",
        ],
      },
      SATURDAY: {
        muscleGroup: "Cardio",
        notes: "Zona aeróbica — ritmo conversável.",
        exerciseIds: ["cardio-esteira", "cardio-bike", "cardio-intervalado", "cardio-eliptico"],
      },
      SUNDAY: {
        muscleGroup: "",
        notes: "Descanso completo. Hidrate-se e durma bem.",
        restDay: true,
        exerciseIds: [],
      },
    },
  },
  {
    id: "forca-ppl",
    name: "Push / Pull / Legs",
    description: "Empurrar, puxar e pernas — clássico de hipertrofia (2x na semana).",
    studentNotes:
      "Seg/Qui push, Ter/Sex pull, Qua/Sáb pernas. Dom descanso. Aumente carga quando completar as reps com folga.",
    kind: "FORCA",
    scope: "WEEK",
    days: {
      MONDAY: {
        muscleGroup: "Push (peito, ombro, tríceps)",
        notes: "Ordem: peito → ombros → tríceps.",
        exerciseIds: [
          "peito-supino-reto",
          "peito-supino-inclinado",
          "peito-peck-deck",
          "ombros-desenvolvimento",
          "ombros-elevacao-lateral",
          "triceps-pulley",
          "triceps-testa",
        ],
      },
      TUESDAY: {
        muscleGroup: "Pull (costas, bíceps)",
        notes: "Puxe com as costas antes de isolar o bíceps.",
        exerciseIds: [
          "costas-barra-fixa",
          "costas-puxada",
          "costas-remada-curvada",
          "costas-remada-baixa",
          "biceps-rosca-direta",
          "biceps-rosca-martelo",
          "ombros-face-pull",
        ],
      },
      WEDNESDAY: {
        muscleGroup: "Pernas + glúteo",
        notes: "Priorize profundidade e estabilidade do joelho.",
        exerciseIds: [
          "pernas-agachamento",
          "pernas-leg-press",
          "pernas-stiff",
          "pernas-extensora",
          "pernas-flexora",
          "gluteo-hip-thrust",
          "pant-em-pe",
        ],
      },
      THURSDAY: {
        muscleGroup: "Push (variação)",
        notes: "Incline e declinado para variar o estímulo.",
        exerciseIds: [
          "peito-supino-inclinado",
          "peito-supino-declinado",
          "peito-crossover",
          "ombros-arnold",
          "ombros-elevacao-frontal",
          "triceps-frances",
          "triceps-banco",
        ],
      },
      FRIDAY: {
        muscleGroup: "Pull (variação)",
        notes: "Mais remadas unilaterais e braço.",
        exerciseIds: [
          "costas-remada-unilateral",
          "costas-pulldown",
          "costas-levantamento-terra",
          "biceps-rosca-alternada",
          "biceps-rosca-scott",
          "abd-prancha",
        ],
      },
      SATURDAY: {
        muscleGroup: "Pernas (volume)",
        notes: "Volume moderado; panturrilha no final.",
        exerciseIds: [
          "pernas-hack",
          "pernas-afundo",
          "pernas-stiff",
          "pernas-flexora",
          "pant-em-pe",
          "abd-elevacao-pernas",
        ],
      },
      SUNDAY: {
        muscleGroup: "",
        notes: "Descanso.",
        restDay: true,
        exerciseIds: [],
      },
    },
  },
  {
    id: "forca-upper-lower",
    name: "Upper / Lower",
    description: "Superior e inferior alternados — bom para intermediários.",
    studentNotes:
      "4 dias de treino: Seg/Qui upper, Ter/Sex lower. Qua e Dom descanso ou cardio leve.",
    kind: "FORCA",
    scope: "WEEK",
    days: {
      MONDAY: {
        muscleGroup: "Upper A",
        notes: "Peito, costas e ombros com volume equilibrado.",
        exerciseIds: [
          "peito-supino-reto",
          "costas-puxada",
          "ombros-desenvolvimento",
          "peito-crucifixo",
          "costas-remada-curvada",
          "triceps-pulley",
          "biceps-rosca-direta",
        ],
      },
      TUESDAY: {
        muscleGroup: "Lower A",
        notes: "Quadríceps em foco + posterior.",
        exerciseIds: [
          "pernas-agachamento",
          "pernas-leg-press",
          "pernas-extensora",
          "pernas-stiff",
          "pant-em-pe",
          "abd-prancha",
        ],
      },
      WEDNESDAY: {
        muscleGroup: "Cardio leve / core",
        notes: "Recuperação ativa.",
        exerciseIds: ["cardio-bike", "abd-crunch", "abd-bicicleta", "func-farmers"],
      },
      THURSDAY: {
        muscleGroup: "Upper B",
        notes: "Ênfase em puxadas e ombro lateral.",
        exerciseIds: [
          "peito-supino-inclinado",
          "costas-barra-fixa",
          "ombros-elevacao-lateral",
          "costas-remada-baixa",
          "peito-crossover",
          "biceps-rosca-martelo",
          "triceps-testa",
        ],
      },
      FRIDAY: {
        muscleGroup: "Lower B",
        notes: "Posterior e glúteo em foco.",
        exerciseIds: [
          "pernas-hack",
          "pernas-afundo",
          "pernas-flexora",
          "gluteo-hip-thrust",
          "pant-em-pe",
          "abd-elevacao-pernas",
        ],
      },
      SATURDAY: {
        muscleGroup: "",
        notes: "Descanso ou caminhada livre.",
        restDay: true,
        exerciseIds: [],
      },
      SUNDAY: {
        muscleGroup: "",
        notes: "Descanso.",
        restDay: true,
        exerciseIds: [],
      },
    },
  },
  {
    id: "cardio-semana",
    name: "Cardio / condicionamento",
    description: "Semana focada em cardio e funcional, com 1 dia de força leve.",
    studentNotes:
      "Use tênis adequado. Pare se sentir tontura ou dor no peito. Hidrate a cada 10–15 min.",
    kind: "CARDIO",
    scope: "WEEK",
    days: {
      MONDAY: {
        muscleGroup: "Cardio intervalado",
        notes: "Aquecimento 5 min caminhando antes dos intervalos.",
        exerciseIds: ["cardio-intervalado", "cardio-esteira", "abd-prancha", "func-burpee"],
      },
      TUESDAY: {
        muscleGroup: "Bike + core",
        notes: "Cadência constante; core no final.",
        exerciseIds: ["cardio-bike", "abd-crunch", "abd-prancha", "func-farmers"],
      },
      WEDNESDAY: {
        muscleGroup: "Força leve full body",
        notes: "Carga leve a moderada — foco em movimento.",
        exerciseIds: [
          "pernas-agachamento",
          "peito-flexao",
          "costas-remada-unilateral",
          "ombros-elevacao-lateral",
        ],
      },
      THURSDAY: {
        muscleGroup: "Elíptico + funcional",
        notes: "Sem impacto; finalize com farmers walk.",
        exerciseIds: ["cardio-eliptico", "func-farmers", "abd-prancha", "func-burpee"],
      },
      FRIDAY: {
        muscleGroup: "Cardio contínuo",
        notes: "20–30 min contínuos na zona confortável.",
        exerciseIds: ["cardio-esteira", "cardio-bike", "abd-crunch", "abd-prancha"],
      },
      SATURDAY: {
        muscleGroup: "Caminhada livre / ativo",
        notes: "Pode ser ao ar livre se preferir.",
        exerciseIds: ["cardio-esteira", "func-farmers"],
      },
      SUNDAY: {
        muscleGroup: "",
        notes: "Descanso.",
        restDay: true,
        exerciseIds: [],
      },
    },
  },
  // Modelos de dia — um músculo por vez (aplica no dia selecionado)
  dayModel(
    "dia-peito",
    "Dia — Peito",
    "Peito",
    "4 exercícios clássicos de peito.",
    [
      "peito-supino-reto",
      "peito-supino-inclinado",
      "peito-crucifixo",
      "peito-crossover",
      "peito-peck-deck",
    ]
  ),
  dayModel(
    "dia-costas",
    "Dia — Costas",
    "Costas",
    "Puxadas e remadas; foque nas escápulas.",
    [
      "costas-barra-fixa",
      "costas-puxada",
      "costas-remada-curvada",
      "costas-remada-unilateral",
      "costas-pulldown",
      "costas-remada-baixa",
    ]
  ),
  dayModel(
    "dia-pernas",
    "Dia — Pernas",
    "Pernas",
    "Quadríceps, posterior, glúteo e panturrilha.",
    [
      "pernas-agachamento",
      "pernas-leg-press",
      "pernas-stiff",
      "pernas-extensora",
      "pernas-flexora",
      "gluteo-hip-thrust",
      "pant-em-pe",
    ]
  ),
  dayModel(
    "dia-ombros",
    "Dia — Ombros",
    "Ombros",
    "Desenvolvimento + isoladores; face pull no final.",
    [
      "ombros-desenvolvimento",
      "ombros-elevacao-lateral",
      "ombros-elevacao-frontal",
      "ombros-arnold",
      "ombros-face-pull",
      "ombros-remada-alta",
    ]
  ),
  dayModel(
    "dia-panturrilha",
    "Dia — Panturrilha",
    "Panturrilha",
    "Em pé, sentado e unilateral.",
    ["pant-em-pe", "pant-sentado", "pant-leg-press", "pant-unilateral"]
  ),
  dayModel(
    "dia-gluteos",
    "Dia — Glúteos",
    "Glúteos",
    "Hip thrust, ponte e abdução.",
    ["gluteo-hip-thrust", "gluteo-ponte", "gluteo-abducao", "gluteo-coice"]
  ),
  dayModel(
    "dia-biceps",
    "Dia — Bíceps",
    "Bíceps",
    "Varie pegadas (supinada, neutra, Scott).",
    [
      "biceps-rosca-direta",
      "biceps-rosca-alternada",
      "biceps-rosca-martelo",
      "biceps-rosca-scott",
    ]
  ),
  dayModel(
    "dia-triceps",
    "Dia — Tríceps",
    "Tríceps",
    "Polia, testa, francês e banco.",
    [
      "triceps-pulley",
      "triceps-testa",
      "triceps-frances",
      "triceps-banco",
    ]
  ),
  dayModel(
    "dia-abdomen",
    "Dia — Abdômen",
    "Abdômen",
    "Core estável + movimento dinâmico.",
    [
      "abd-prancha",
      "abd-crunch",
      "abd-elevacao-pernas",
      "abd-bicicleta",
      "abd-russian-twist",
    ]
  ),
  dayModel(
    "dia-peito-triceps",
    "Dia — Peito + Tríceps",
    "Peito + Tríceps",
    "Empurradores juntos.",
    [
      "peito-supino-reto",
      "peito-supino-inclinado",
      "peito-crucifixo",
      "triceps-pulley",
      "triceps-testa",
      "triceps-frances",
    ]
  ),
  dayModel(
    "dia-costas-biceps",
    "Dia — Costas + Bíceps",
    "Costas + Bíceps",
    "Puxadores juntos.",
    [
      "costas-puxada",
      "costas-remada-curvada",
      "costas-remada-unilateral",
      "biceps-rosca-direta",
      "biceps-rosca-martelo",
      "biceps-rosca-alternada",
    ]
  ),
  dayModel(
    "dia-pernas-abdomen",
    "Dia — Pernas + Abdômen",
    "Pernas + Abdômen",
    "Membros inferiores + core no final.",
    [
      "pernas-agachamento",
      "pernas-leg-press",
      "pernas-stiff",
      "pernas-afundo",
      "abd-prancha",
      "abd-elevacao-pernas",
    ]
  ),
  dayModel(
    "dia-ombro-abdomen",
    "Dia — Ombros + Abdômen",
    "Ombros + Abdômen",
    "Ombros com volume + core.",
    [
      "ombros-desenvolvimento",
      "ombros-elevacao-lateral",
      "ombros-face-pull",
      "ombros-elevacao-frontal",
      "abd-prancha",
      "abd-bicicleta",
    ]
  ),
  dayModel(
    "dia-bracos",
    "Dia — Braços (bíceps + tríceps)",
    "Bíceps + Tríceps",
    "Dia de braços: controle a negativa.",
    [
      "biceps-rosca-direta",
      "biceps-rosca-martelo",
      "biceps-rosca-scott",
      "triceps-pulley",
      "triceps-testa",
      "triceps-frances",
    ]
  ),
  dayModel(
    "dia-full-body",
    "Dia — Full body",
    "Full body",
    "Um exercício por padrão de movimento.",
    [
      "pernas-agachamento",
      "peito-supino-reto",
      "costas-remada-curvada",
      "ombros-desenvolvimento",
      "abd-prancha",
      "func-farmers",
    ],
    "Carga moderada. Bom para iniciantes ou dias corridos."
  ),
];

export function libraryExerciseToForm(ex: LibraryExercise) {
  return {
    name: ex.name,
    description: ex.description,
    sets: ex.sets,
    reps: ex.reps === "0" ? "" : ex.reps,
    duration: ex.duration ?? "",
    videoUrl: "",
    mediaType: "NONE" as const,
    variationNotes: ex.variationNotes ?? "",
    notes: ex.notes,
  };
}

export function getExercisesByMuscle(muscle: MuscleTag | "TODOS") {
  if (muscle === "TODOS") return EXERCISE_LIBRARY;
  return EXERCISE_LIBRARY.filter((e) => e.muscle === muscle);
}

export function getExercisesByGoal(goal: ExerciseGoal | "TODOS") {
  if (goal === "TODOS") return EXERCISE_LIBRARY;
  return EXERCISE_LIBRARY.filter((e) => e.goal === goal);
}

export function resolveTemplateExercises(ids: string[]) {
  return ids.map(byId).map(libraryExerciseToForm);
}

export const WEEK_SCOPE_TEMPLATES = WEEK_TEMPLATES.filter((t) => t.scope === "WEEK");
export const DAY_SCOPE_TEMPLATES = WEEK_TEMPLATES.filter((t) => t.scope === "DAY");

/** Contagem por músculo — útil na UI. */
export function countByMuscle(): Record<MuscleTag, number> {
  const counts = Object.fromEntries(muscleOrder.map((m) => [m, 0])) as Record<
    MuscleTag,
    number
  >;
  for (const e of EXERCISE_LIBRARY) {
    counts[e.muscle] += 1;
  }
  return counts;
}

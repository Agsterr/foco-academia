import type { WeekDay } from "./api";

export type MuscleTag =
  | "PEITO"
  | "COSTAS"
  | "PERNAS"
  | "OMBROS"
  | "BICEPS"
  | "TRICEPS"
  | "ABDOMEN"
  | "CARDIO"
  | "FUNCIONAL";

export interface LibraryExercise {
  id: string;
  name: string;
  muscle: MuscleTag;
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
  OMBROS: "Ombros",
  BICEPS: "Bíceps",
  TRICEPS: "Tríceps",
  ABDOMEN: "Abdômen",
  CARDIO: "Cardio",
  FUNCIONAL: "Funcional",
};

export const EXERCISE_LIBRARY: LibraryExercise[] = [
  // Peito
  {
    id: "peito-supino-reto",
    name: "Supino reto com barra",
    muscle: "PEITO",
    description: "Deitado no banco, desça a barra até o peito e empurre até quase estender os cotovelos.",
    sets: "4",
    reps: "8-10",
    notes: "Escápulas retraídas; não quicar a barra no peito.",
  },
  {
    id: "peito-supino-inclinado",
    name: "Supino inclinado com halteres",
    muscle: "PEITO",
    description: "Banco a ~30–45°. Empurre os halteres para cima alinhados ao peito superior.",
    sets: "4",
    reps: "10",
    notes: "Controle a descida em 2–3 segundos.",
  },
  {
    id: "peito-crucifixo",
    name: "Crucifixo no banco",
    muscle: "PEITO",
    description: "Abra os braços em arco amplo e feche acima do peito sem bater os pesos.",
    sets: "3",
    reps: "12",
    notes: "Cotovelos levemente flexionados o tempo todo.",
  },
  {
    id: "peito-crossover",
    name: "Crossover na polia",
    muscle: "PEITO",
    description: "Puxe as alças de cima para baixo cruzando à frente do tronco.",
    sets: "3",
    reps: "12-15",
    notes: "Foque no peitoral, não nos ombros.",
  },
  {
    id: "peito-flexao",
    name: "Flexão de braço",
    muscle: "PEITO",
    description: "Corpo alinhado; desça o peito perto do chão e suba empurrando o solo.",
    sets: "3",
    reps: "12-15",
    notes: "Joelho no chão se precisar manter a forma.",
  },
  // Costas
  {
    id: "costas-puxada",
    name: "Puxada frontal",
    muscle: "COSTAS",
    description: "Puxe a barra até a clavícula, cotovelos para baixo e para trás.",
    sets: "4",
    reps: "10",
    notes: "Peito aberto; não incline demais o tronco.",
  },
  {
    id: "costas-remada-curvada",
    name: "Remada curvada",
    muscle: "COSTAS",
    description: "Tronco inclinado ~45°. Puxe a barra/halteres até o umbigo.",
    sets: "4",
    reps: "8-10",
    notes: "Coluna neutra; sem balanço.",
  },
  {
    id: "costas-remada-unilateral",
    name: "Remada unilateral com halter",
    muscle: "COSTAS",
    description: "Apoie um joelho no banco e puxe o peso até o quadril.",
    sets: "3",
    reps: "10-12",
    notes: "Evite girar o tronco.",
  },
  {
    id: "costas-pulldown",
    name: "Pulldown com triângulo",
    muscle: "COSTAS",
    description: "Pegada neutra; puxe até o peito superior.",
    sets: "3",
    reps: "12",
    notes: "Sinta as escápulas se aproximarem.",
  },
  // Pernas
  {
    id: "pernas-agachamento",
    name: "Agachamento livre",
    muscle: "PERNAS",
    description: "Desça até coxas paralelas ao chão, joelhos alinhados aos pés.",
    sets: "4",
    reps: "8-10",
    notes: "Peso nos calcanhares; peito erguido.",
  },
  {
    id: "pernas-leg-press",
    name: "Leg press 45°",
    muscle: "PERNAS",
    description: "Desça controlado até ~90° nos joelhos e empurre sem travar.",
    sets: "4",
    reps: "12",
    notes: "Não deixe o quadril levantar do assento.",
  },
  {
    id: "pernas-extensora",
    name: "Cadeira extensora",
    muscle: "PERNAS",
    description: "Estenda os joelhos até quase travar e desça devagar.",
    sets: "3",
    reps: "12-15",
    notes: "Útil no final para queimar o quadríceps.",
  },
  {
    id: "pernas-flexora",
    name: "Mesa flexora",
    muscle: "PERNAS",
    description: "Flexione os joelhos trazendo os calcanhares em direção ao glúteo.",
    sets: "3",
    reps: "12",
    notes: "Quadril fixo no banco.",
  },
  {
    id: "pernas-afundo",
    name: "Afundo caminhando",
    muscle: "PERNAS",
    description: "Passo longo à frente, joelho de trás quase toca o chão.",
    sets: "3",
    reps: "10",
    notes: "10 por perna. Tronco ereto.",
  },
  // Ombros
  {
    id: "ombros-desenvolvimento",
    name: "Desenvolvimento com halteres",
    muscle: "OMBROS",
    description: "Empurre os pesos acima da cabeça sem arquear a lombar.",
    sets: "4",
    reps: "8-10",
    notes: "Core firme; não bata os pesos no topo.",
  },
  {
    id: "ombros-elevacao-lateral",
    name: "Elevação lateral",
    muscle: "OMBROS",
    description: "Eleve os braços até a linha dos ombros, leve flexão nos cotovelos.",
    sets: "3",
    reps: "12-15",
    notes: "Polegares levemente para baixo (jarro).",
  },
  {
    id: "ombros-elevacao-frontal",
    name: "Elevação frontal",
    muscle: "OMBROS",
    description: "Levante o peso à frente até a altura dos ombros.",
    sets: "3",
    reps: "12",
    notes: "Alternado ou com barra — sem balanço.",
  },
  {
    id: "ombros-face-pull",
    name: "Face pull",
    muscle: "OMBROS",
    description: "Puxe a corda em direção ao rosto, cotovelos altos.",
    sets: "3",
    reps: "15",
    notes: "Ótimo para saúde do ombro e postura.",
  },
  // Bíceps
  {
    id: "biceps-rosca-direta",
    name: "Rosca direta com barra",
    muscle: "BICEPS",
    description: "Cotovelos fixos ao lado do corpo; suba e desça controlado.",
    sets: "3",
    reps: "10-12",
    notes: "Não balance o tronco.",
  },
  {
    id: "biceps-rosca-alternada",
    name: "Rosca alternada com halteres",
    muscle: "BICEPS",
    description: "Alterne os braços com leve rotação do punho no topo.",
    sets: "3",
    reps: "12",
    notes: "Cotovelos estáveis.",
  },
  {
    id: "biceps-rosca-martelo",
    name: "Rosca martelo",
    muscle: "BICEPS",
    description: "Pegada neutra (polegares para cima) durante todo o movimento.",
    sets: "3",
    reps: "12",
    notes: "Trabalha também o braquial.",
  },
  {
    id: "biceps-rosca-scott",
    name: "Rosca Scott",
    muscle: "BICEPS",
    description: "Braços apoiados no banco Scott; amplitude completa sem esticar demais.",
    sets: "3",
    reps: "10",
    notes: "Evite hiperextensão no fundo.",
  },
  // Tríceps
  {
    id: "triceps-pulley",
    name: "Tríceps na polia (corda)",
    muscle: "TRICEPS",
    description: "Estenda os cotovelos para baixo abrindo a corda no final.",
    sets: "3",
    reps: "12-15",
    notes: "Cotovelos colados ao tronco.",
  },
  {
    id: "triceps-testa",
    name: "Tríceps testa",
    muscle: "TRICEPS",
    description: "Deitado, flexione os cotovelos levando a barra à testa e estenda.",
    sets: "3",
    reps: "10-12",
    notes: "Cotovelos apontando para o teto.",
  },
  {
    id: "triceps-frances",
    name: "Tríceps francês",
    muscle: "TRICEPS",
    description: "Halter atrás da cabeça; estenda os cotovelos sem abrir demais.",
    sets: "3",
    reps: "12",
    notes: "Cotovelos próximos à orelha.",
  },
  {
    id: "triceps-banco",
    name: "Tríceps no banco",
    muscle: "TRICEPS",
    description: "Mãos no banco atrás do corpo; flexione e estenda os cotovelos.",
    sets: "3",
    reps: "12",
    notes: "Quadril próximo ao banco.",
  },
  // Abdômen
  {
    id: "abd-prancha",
    name: "Prancha",
    muscle: "ABDOMEN",
    description: "Corpo reto apoiado nos antebraços; contraia o abdômen.",
    sets: "3",
    reps: "0",
    duration: "40-60s",
    notes: "Não deixe o quadril cair.",
  },
  {
    id: "abd-crunch",
    name: "Abdominal crunch",
    muscle: "ABDOMEN",
    description: "Eleve o tronco enrolando a coluna, sem puxar o pescoço.",
    sets: "3",
    reps: "15-20",
    notes: "Expire na subida.",
  },
  // Cardio / funcional
  {
    id: "cardio-esteira",
    name: "Esteira — caminhada inclinada",
    muscle: "CARDIO",
    description: "Caminhada em ritmo constante com inclinação moderada.",
    sets: "1",
    reps: "0",
    duration: "20-30 min",
    notes: "Mantenha conversa possível (zona aeróbica).",
  },
  {
    id: "cardio-bike",
    name: "Bike ergométrica",
    muscle: "CARDIO",
    description: "Pedale em cadência estável com resistência confortável.",
    sets: "1",
    reps: "0",
    duration: "20-25 min",
    notes: "Ajuste o banco para joelho quase estendido.",
  },
  {
    id: "cardio-eliptico",
    name: "Elíptico",
    muscle: "CARDIO",
    description: "Movimento contínuo de pernas e braços sem impacto.",
    sets: "1",
    reps: "0",
    duration: "20 min",
    notes: "Postura ereta; sem apoiar o peso nos braços.",
  },
  {
    id: "cardio-intervalado",
    name: "Intervalado caminhada/corrida",
    muscle: "CARDIO",
    description: "2 min caminhada + 1 min corrida leve, repetir.",
    sets: "1",
    reps: "0",
    duration: "20-25 min",
    notes: "Ajuste o ritmo ao condicionamento do aluno.",
  },
  {
    id: "func-burpee",
    name: "Burpee (adaptado)",
    muscle: "FUNCIONAL",
    description: "Agache, apoie as mãos, estenda as pernas e volte.",
    sets: "3",
    reps: "8-10",
    notes: "Pode remover o salto se necessário.",
  },
  {
    id: "func-farmers",
    name: "Farmers walk",
    muscle: "FUNCIONAL",
    description: "Caminhe com pesos nas mãos mantendo tronco ereto.",
    sets: "3",
    reps: "0",
    duration: "30-40s",
    notes: "Ombros para baixo; passos curtos.",
  },
];

export interface WeekTemplate {
  id: string;
  name: string;
  description: string;
  /** Observação geral da ficha para o aluno */
  studentNotes: string;
  kind: "FORCA" | "CARDIO" | "MISTO";
  days: Partial<Record<WeekDay, { muscleGroup: string; notes: string; restDay?: boolean; exerciseIds: string[] }>>;
}

function byId(id: string): LibraryExercise {
  const found = EXERCISE_LIBRARY.find((e) => e.id === id);
  if (!found) throw new Error(`Exercício não encontrado: ${id}`);
  return found;
}

/** Fichas prontas: 2 grupos musculares/dia com 4 exercícios cada (8 no total). */
export const WEEK_TEMPLATES: WeekTemplate[] = [
  {
    id: "forca-abc",
    name: "Força — 2 músculos/dia",
    description: "Seg–Sex com 2 grupos e 4 exercícios cada. Sáb cardio, Dom descanso.",
    studentNotes:
      "Descanse 60–90s entre séries. Priorize a execução. Se doer articulação (não músculo), pare e avise o instrutor.",
    kind: "FORCA",
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
    id: "cardio-semana",
    name: "Cardio / condicionamento",
    description: "Semana focada em cardio e funcional, com 1 dia de força leve.",
    studentNotes:
      "Use tênis adequado. Pare se sentir tontura ou dor no peito. Hidrate a cada 10–15 min.",
    kind: "CARDIO",
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
  {
    id: "peito-foco",
    name: "Só peito (modelo de dia)",
    description: "4 exercícios de peito prontos — use para preencher um dia ou como base.",
    studentNotes: "Aqueça com 1–2 séries leves de flexão ou crucifixo antes da carga de trabalho.",
    kind: "FORCA",
    days: {
      MONDAY: {
        muscleGroup: "Peito",
        notes: "4 exercícios clássicos de peito com dicas de execução.",
        exerciseIds: [
          "peito-supino-reto",
          "peito-supino-inclinado",
          "peito-crucifixo",
          "peito-crossover",
        ],
      },
    },
  },
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

export function resolveTemplateExercises(ids: string[]) {
  return ids.map(byId).map(libraryExerciseToForm);
}

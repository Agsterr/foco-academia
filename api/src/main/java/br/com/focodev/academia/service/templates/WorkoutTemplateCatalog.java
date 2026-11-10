package br.com.focodev.academia.service.templates;

import br.com.focodev.academia.domain.WeekDay;
import br.com.focodev.academia.dto.CardioDtos.CardioIntervalDto;
import br.com.focodev.academia.dto.ExerciseRequest;
import br.com.focodev.academia.dto.StudentProgramRequest;
import br.com.focodev.academia.dto.WorkoutDayRequest;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Kind;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Level;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Modality;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.TemplateSummary;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

/**
 * Treinos prontos por modalidade e nível para quem treina sem instrutor.
 * Musculação, spinning e bike viram uma ficha semanal (cada bloco da aula é um item
 * com tempo e intensidade); corrida vira um treino outdoor com fases de corrida e caminhada.
 */
public final class WorkoutTemplateCatalog {

    private WorkoutTemplateCatalog() {}

    public record Template(
            TemplateSummary summary,
            StudentProgramRequest program,
            String cardioType,
            List<CardioIntervalDto> intervals
    ) {}

    private static final List<Template> ALL = List.of(
            // ---------------- Musculação ----------------
            program("musculacao-iniciante", "Corpo inteiro 3x por semana", Modality.MUSCULACAO, Level.INICIANTE,
                    "Para quem está começando: o corpo todo em cada treino, com cargas leves e foco na execução.", 45,
                    days(
                            day(WeekDay.MONDAY, "Corpo inteiro A", ex("Leg press", 3, 12), ex("Supino máquina", 3, 12),
                                    ex("Puxada frontal", 3, 12), ex("Elevação lateral", 3, 12), ex("Prancha", 3, 0, "30 s")),
                            rest(WeekDay.TUESDAY),
                            day(WeekDay.WEDNESDAY, "Corpo inteiro B", ex("Agachamento no smith", 3, 12), ex("Remada baixa", 3, 12),
                                    ex("Supino inclinado com halteres", 3, 12), ex("Rosca direta", 3, 12), ex("Abdominal crunch", 3, 15)),
                            rest(WeekDay.THURSDAY),
                            day(WeekDay.FRIDAY, "Corpo inteiro C", ex("Cadeira extensora", 3, 12), ex("Mesa flexora", 3, 12),
                                    ex("Crucifixo máquina", 3, 12), ex("Remada unilateral", 3, 12), ex("Tríceps corda", 3, 12)),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),
            program("musculacao-intermediario", "Divisão ABC 5x por semana", Modality.MUSCULACAO, Level.INTERMEDIARIO,
                    "A: peito, ombro e tríceps · B: costas e bíceps · C: pernas. Mais volume e progressão de carga.", 60,
                    days(
                            day(WeekDay.MONDAY, "A — Peito, ombro e tríceps", ex("Supino reto", 4, 10), ex("Supino inclinado com halteres", 3, 10),
                                    ex("Desenvolvimento com halteres", 4, 10), ex("Elevação lateral", 3, 12), ex("Tríceps testa", 3, 12)),
                            day(WeekDay.TUESDAY, "B — Costas e bíceps", ex("Puxada frontal", 4, 10), ex("Remada curvada", 4, 10),
                                    ex("Remada unilateral", 3, 10), ex("Rosca direta", 3, 10), ex("Rosca martelo", 3, 12)),
                            day(WeekDay.WEDNESDAY, "C — Pernas", ex("Agachamento livre", 4, 10), ex("Leg press", 4, 12),
                                    ex("Stiff", 3, 10), ex("Cadeira extensora", 3, 12), ex("Panturrilha em pé", 4, 15)),
                            day(WeekDay.THURSDAY, "A — Peito, ombro e tríceps", ex("Supino com halteres", 4, 10), ex("Crucifixo", 3, 12),
                                    ex("Desenvolvimento máquina", 3, 10), ex("Elevação frontal", 3, 12), ex("Tríceps corda", 3, 12)),
                            day(WeekDay.FRIDAY, "B — Costas e bíceps", ex("Barra fixa (ou graviton)", 4, 8), ex("Remada baixa", 4, 10),
                                    ex("Pulldown braço reto", 3, 12), ex("Rosca scott", 3, 10), ex("Abdominal infra", 3, 15)),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),
            program("musculacao-avancado", "Divisão ABCDE (um grupo por dia)", Modality.MUSCULACAO, Level.AVANCADO,
                    "Para quem já treina há mais de um ano: um grupo muscular por dia, mais séries e técnicas avançadas.", 75,
                    days(
                            day(WeekDay.MONDAY, "Peito", ex("Supino reto", 5, 8), ex("Supino inclinado", 4, 8),
                                    ex("Crucifixo inclinado", 4, 10), ex("Crossover", 3, 12), ex("Flexão de braço", 3, 0, "até a falha")),
                            day(WeekDay.TUESDAY, "Costas", ex("Levantamento terra", 4, 6), ex("Barra fixa", 4, 8),
                                    ex("Remada curvada", 4, 8), ex("Remada cavalinho", 3, 10), ex("Pulldown braço reto", 3, 12)),
                            day(WeekDay.WEDNESDAY, "Pernas", ex("Agachamento livre", 5, 6), ex("Leg press 45°", 4, 10),
                                    ex("Afundo com halteres", 3, 10), ex("Mesa flexora", 4, 10), ex("Panturrilha sentado", 4, 15)),
                            day(WeekDay.THURSDAY, "Ombros", ex("Desenvolvimento militar", 5, 8), ex("Elevação lateral", 4, 12),
                                    ex("Crucifixo invertido", 4, 12), ex("Encolhimento", 4, 12)),
                            day(WeekDay.FRIDAY, "Braços e core", ex("Rosca direta", 4, 10), ex("Tríceps testa", 4, 10),
                                    ex("Rosca concentrada", 3, 12), ex("Tríceps francês", 3, 12), ex("Prancha", 4, 0, "45 s")),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),

            // ---------------- Spinning (aula estruturada em blocos) ----------------
            program("spinning-iniciante", "Spinning 30 min — 3x por semana", Modality.SPINNING, Level.INICIANTE,
                    "Aula curta e leve para ganhar fôlego. Cadência confortável e carga baixa.", 30,
                    days(
                            day(WeekDay.MONDAY, "Aula base", spinningBase()),
                            rest(WeekDay.TUESDAY),
                            day(WeekDay.WEDNESDAY, "Aula com subidas leves", spinningSubidasLeves()),
                            rest(WeekDay.THURSDAY),
                            day(WeekDay.FRIDAY, "Aula base", spinningBase()),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),
            program("spinning-intermediario", "Spinning 45 min — 4x por semana", Modality.SPINNING, Level.INTERMEDIARIO,
                    "Intervalos de sprint e subidas com carga moderada. Melhora resistência e queima calórica.", 45,
                    days(
                            day(WeekDay.MONDAY, "Intervalado", spinningIntervalado(6)),
                            day(WeekDay.TUESDAY, "Subidas", spinningSubidas(4)),
                            rest(WeekDay.WEDNESDAY),
                            day(WeekDay.THURSDAY, "Intervalado", spinningIntervalado(6)),
                            day(WeekDay.FRIDAY, "Resistência", spinningResistencia(25)),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),
            program("spinning-avancado", "Spinning 60 min — 5x por semana", Modality.SPINNING, Level.AVANCADO,
                    "HIIT, subidas pesadas e blocos longos em limiar. Para quem já pedala com frequência.", 60,
                    days(
                            day(WeekDay.MONDAY, "HIIT", spinningIntervalado(10)),
                            day(WeekDay.TUESDAY, "Subidas pesadas", spinningSubidas(6)),
                            day(WeekDay.WEDNESDAY, "Resistência longa", spinningResistencia(40)),
                            day(WeekDay.THURSDAY, "HIIT", spinningIntervalado(10)),
                            day(WeekDay.FRIDAY, "Subidas pesadas", spinningSubidas(6)),
                            rest(WeekDay.SATURDAY),
                            rest(WeekDay.SUNDAY)
                    )),

            // ---------------- Bike (rua ou ergométrica) ----------------
            program("bike-iniciante", "Bike 30–40 min — 3x por semana", Modality.BIKE, Level.INICIANTE,
                    "Pedal leve e contínuo (dá para conversar pedalando). Rua ou bike ergométrica.", 40,
                    days(
                            day(WeekDay.TUESDAY, "Pedal leve", bikeBlocks(30, null)),
                            rest(WeekDay.WEDNESDAY),
                            day(WeekDay.THURSDAY, "Pedal leve", bikeBlocks(30, null)),
                            day(WeekDay.SATURDAY, "Pedal um pouco mais longo", bikeBlocks(40, null)),
                            rest(WeekDay.MONDAY),
                            rest(WeekDay.FRIDAY),
                            rest(WeekDay.SUNDAY)
                    )),
            program("bike-intermediario", "Bike 45–90 min — 4x por semana", Modality.BIKE, Level.INTERMEDIARIO,
                    "Base aeróbica, um treino de ritmo forte e um longão no fim de semana.", 60,
                    days(
                            day(WeekDay.TUESDAY, "Ritmo", bikeBlocks(25, "4 × 5 min forte / 3 min leve")),
                            day(WeekDay.WEDNESDAY, "Base leve", bikeBlocks(45, null)),
                            day(WeekDay.THURSDAY, "Subidas", bikeBlocks(20, "5 × 3 min subida / 3 min leve")),
                            day(WeekDay.SUNDAY, "Longão", bikeBlocks(90, null)),
                            rest(WeekDay.MONDAY),
                            rest(WeekDay.FRIDAY),
                            rest(WeekDay.SATURDAY)
                    )),
            program("bike-avancado", "Bike 1–2,5 h — 5x por semana", Modality.BIKE, Level.AVANCADO,
                    "Intervalados no limiar, subidas, recuperação ativa e longão de até 2h30.", 90,
                    days(
                            day(WeekDay.TUESDAY, "Limiar", bikeBlocks(30, "3 × 10 min no limiar / 5 min leve")),
                            day(WeekDay.WEDNESDAY, "Recuperação ativa", bikeBlocks(45, null)),
                            day(WeekDay.THURSDAY, "VO2 máx", bikeBlocks(25, "6 × 3 min muito forte / 3 min leve")),
                            day(WeekDay.SATURDAY, "Subidas", bikeBlocks(60, "4 × 8 min subida")),
                            day(WeekDay.SUNDAY, "Longão", bikeBlocks(150, null)),
                            rest(WeekDay.MONDAY),
                            rest(WeekDay.FRIDAY)
                    )),

            // ---------------- Corrida (treino outdoor com GPS) ----------------
            cardio("corrida-iniciante", "Caminhada e corrida — Iniciante", Level.INICIANTE,
                    "Começa caminhando e alterna 1 min de corrida leve com 2 min de caminhada.", 34,
                    concat(phase("WALK", 5), repeat(8, phase("RUN", 1), phase("WALK", 2)), phase("WALK", 5))),
            cardio("corrida-intermediario", "Rumo aos 5 km — Intermediário", Level.INTERMEDIARIO,
                    "Blocos de 5 min correndo com 1 min de caminhada para recuperar.", 40,
                    concat(phase("WALK", 5), repeat(5, phase("RUN", 5), phase("WALK", 1)), phase("WALK", 5))),
            cardio("corrida-avancado", "Intervalado para 10 km — Avançado", Level.AVANCADO,
                    "Corrida contínua com tiros mais longos. Para quem já corre 5 km sem parar.", 55,
                    concat(phase("WALK", 3), phase("RUN", 10), repeat(4, phase("RUN", 8), phase("WALK", 1)), phase("WALK", 5)))
    );

    public static List<Template> all() {
        return ALL;
    }

    public static List<TemplateSummary> summaries(Modality modality, Level level) {
        return ALL.stream()
                .map(Template::summary)
                .filter(s -> modality == null || s.modality() == modality)
                .filter(s -> level == null || s.level() == level)
                .toList();
    }

    public static Optional<Template> find(String key) {
        return ALL.stream().filter(t -> t.summary().key().equals(key)).findFirst();
    }

    // ---------------- Blocos de spinning e bike ----------------

    private static ExerciseRequest[] spinningBase() {
        return new ExerciseRequest[]{
                block("Aquecimento", "5 min", "Cadência 80–90 rpm, carga leve."),
                block("Pedal plano", "8 min", "Cadência 90 rpm, carga leve a moderada."),
                block("Pedal em pé", "3 × 1 min", "Levante do banco com carga moderada; 1 min sentado entre as repetições."),
                block("Pedal plano", "6 min", "Cadência 85–90 rpm."),
                block("Volta à calma", "5 min", "Carga mínima e alongamento no final.")
        };
    }

    private static ExerciseRequest[] spinningSubidasLeves() {
        return new ExerciseRequest[]{
                block("Aquecimento", "5 min", "Cadência 80–90 rpm, carga leve."),
                block("Subida leve", "3 × 2 min", "Carga moderada, cadência 70 rpm; 1 min leve entre as subidas."),
                block("Pedal plano", "8 min", "Cadência 90 rpm."),
                block("Volta à calma", "5 min", "Carga mínima.")
        };
    }

    private static ExerciseRequest[] spinningIntervalado(int sprints) {
        return new ExerciseRequest[]{
                block("Aquecimento", "8 min", "Aumente a cadência aos poucos até 95 rpm."),
                block("Sprint", sprints + " × 30 s", "Cadência acima de 110 rpm com carga moderada; 1 min 30 s leve entre os sprints."),
                block("Pedal em pé", "4 × 1 min", "Carga moderada a alta."),
                block("Pedal plano", "8 min", "Cadência 90 rpm, recupere o fôlego."),
                block("Volta à calma", "5 min", "Carga mínima e alongamento.")
        };
    }

    private static ExerciseRequest[] spinningSubidas(int climbs) {
        return new ExerciseRequest[]{
                block("Aquecimento", "8 min", "Cadência 85–90 rpm."),
                block("Subida", climbs + " × 3 min", "Carga alta, cadência 60–70 rpm, alternando sentado e em pé; 2 min leve entre as subidas."),
                block("Pedal plano", "6 min", "Cadência 90 rpm."),
                block("Volta à calma", "5 min", "Carga mínima.")
        };
    }

    private static ExerciseRequest[] spinningResistencia(int minutes) {
        return new ExerciseRequest[]{
                block("Aquecimento", "8 min", "Cadência 85–90 rpm."),
                block("Resistência", minutes + " min", "Carga moderada constante, esforço 7 de 10 (fala frases curtas)."),
                block("Volta à calma", "6 min", "Carga mínima e alongamento.")
        };
    }

    private static ExerciseRequest[] bikeBlocks(int mainMinutes, String intervals) {
        List<ExerciseRequest> blocks = new ArrayList<>();
        blocks.add(block("Aquecimento", "10 min", "Pedal leve, aumentando a cadência aos poucos."));
        if (intervals != null) {
            blocks.add(block("Intervalos", intervals, "Mantenha a postura e respire fundo na parte leve."));
        }
        blocks.add(block("Pedal contínuo", mainMinutes + " min", "Ritmo confortável (dá para conversar)."));
        blocks.add(block("Volta à calma", "5 min", "Pedal bem leve e alongamento."));
        return blocks.toArray(ExerciseRequest[]::new);
    }

    // ---------------- Montagem ----------------

    private static Template program(String key, String title, Modality modality, Level level,
                                    String description, int sessionMinutes, List<WorkoutDayRequest> days) {
        int daysPerWeek = (int) days.stream().filter(d -> !d.restDay()).count();
        List<WorkoutDayRequest> ordered = days.stream()
                .sorted((a, b) -> Integer.compare(a.weekDay().ordinal(), b.weekDay().ordinal()))
                .toList();
        List<WorkoutDayRequest> numbered = new ArrayList<>();
        for (int i = 0; i < ordered.size(); i++) {
            WorkoutDayRequest d = ordered.get(i);
            numbered.add(new WorkoutDayRequest(d.weekDay(), d.muscleGroup(), d.notes(), d.restDay(), i + 1, d.exercises()));
        }
        return new Template(
                new TemplateSummary(key, title, modality, level, Kind.PROGRAM, description, daysPerWeek, sessionMinutes),
                new StudentProgramRequest(title, description, numbered),
                null,
                null
        );
    }

    private static Template cardio(String key, String title, Level level, String description,
                                   int sessionMinutes, List<CardioIntervalDto> intervals) {
        return new Template(
                new TemplateSummary(key, title, Modality.CORRIDA, level, Kind.CARDIO, description, 3, sessionMinutes),
                null,
                "INTERVAL",
                intervals
        );
    }

    private static List<WorkoutDayRequest> days(WorkoutDayRequest... days) {
        return Arrays.asList(days);
    }

    private static WorkoutDayRequest day(WeekDay weekDay, String group, ExerciseRequest... exercises) {
        List<ExerciseRequest> list = new ArrayList<>();
        for (int i = 0; i < exercises.length; i++) {
            ExerciseRequest e = exercises[i];
            list.add(new ExerciseRequest(e.name(), e.description(), e.sets(), e.reps(), e.duration(), null, null,
                    e.variationNotes(), e.notes(), i + 1));
        }
        return new WorkoutDayRequest(weekDay, group, null, false, 0, list);
    }

    private static WorkoutDayRequest rest(WeekDay weekDay) {
        return new WorkoutDayRequest(weekDay, "Descanso", null, true, 0, List.of());
    }

    private static ExerciseRequest ex(String name, int sets, int reps) {
        return new ExerciseRequest(name, null, sets, reps > 0 ? reps : null, null, null, null, null, null, 0);
    }

    private static ExerciseRequest ex(String name, int sets, int reps, String duration) {
        return new ExerciseRequest(name, null, sets, reps > 0 ? reps : null, duration, null, null, null, null, 0);
    }

    private static ExerciseRequest block(String name, String duration, String howTo) {
        return new ExerciseRequest(name, howTo, 1, null, duration, null, null, null, null, 0);
    }

    private static CardioIntervalDto phase(String phase, int minutes) {
        return new CardioIntervalDto(phase, minutes * 60);
    }

    private static List<CardioIntervalDto> repeat(int times, CardioIntervalDto... phases) {
        List<CardioIntervalDto> out = new ArrayList<>();
        for (int i = 0; i < times; i++) out.addAll(Arrays.asList(phases));
        return out;
    }

    private static List<CardioIntervalDto> concat(Object... parts) {
        List<CardioIntervalDto> out = new ArrayList<>();
        for (Object part : parts) {
            if (part instanceof CardioIntervalDto dto) out.add(dto);
            else if (part instanceof List<?> list) list.forEach(item -> out.add((CardioIntervalDto) item));
        }
        return out;
    }
}

"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import MediaPicker from "@/components/MediaPicker";
import {
  MediaType,
  User,
  WeekDay,
  api,
  getToken,
  uploadMedia,
  weekDayLabels,
  weekDayOrder,
} from "@/lib/api";
import { addRecentMedia } from "@/lib/recent-media";
import {
  EXERCISE_LIBRARY,
  LibraryExercise,
  MuscleTag,
  WEEK_TEMPLATES,
  WeekTemplate,
  getExercisesByMuscle,
  libraryExerciseToForm,
  muscleLabels,
  resolveTemplateExercises,
} from "@/lib/exercise-library";

interface ExerciseForm {
  name: string;
  description: string;
  sets: string;
  reps: string;
  duration: string;
  videoUrl: string;
  mediaType: MediaType;
  variationNotes: string;
  notes: string;
}

interface DayForm {
  muscleGroup: string;
  notes: string;
  restDay: boolean;
  exercises: ExerciseForm[];
}

const emptyExercise = (): ExerciseForm => ({
  name: "",
  description: "",
  sets: "3",
  reps: "12",
  duration: "",
  videoUrl: "",
  mediaType: "NONE",
  variationNotes: "",
  notes: "",
});

const defaultDay = (muscleGroup: string, restDay = false): DayForm => ({
  muscleGroup,
  notes: "",
  restDay,
  exercises: restDay ? [] : [emptyExercise()],
});

const emptyWeek = (): Record<WeekDay, DayForm> => ({
  MONDAY: defaultDay(""),
  TUESDAY: defaultDay(""),
  WEDNESDAY: defaultDay(""),
  THURSDAY: defaultDay(""),
  FRIDAY: defaultDay(""),
  SATURDAY: defaultDay(""),
  SUNDAY: defaultDay("", true),
});

function applyTemplate(template: WeekTemplate): {
  title: string;
  description: string;
  days: Record<WeekDay, DayForm>;
} {
  const days = emptyWeek();
  for (const weekDay of weekDayOrder) {
    const t = template.days[weekDay];
    if (!t) continue;
    days[weekDay] = {
      muscleGroup: t.muscleGroup,
      notes: t.notes,
      restDay: Boolean(t.restDay),
      exercises: t.restDay ? [] : resolveTemplateExercises(t.exerciseIds),
    };
  }
  return {
    title: template.name,
    description: `${template.description}\n\n${template.studentNotes}`,
    days,
  };
}

export default function NovaFichaPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [title, setTitle] = useState("Ficha semanal");
  const [description, setDescription] = useState("");
  const [studentId, setStudentId] = useState("");
  const [days, setDays] = useState(emptyWeek);
  const [activeDay, setActiveDay] = useState<WeekDay>("MONDAY");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [uploadingKey, setUploadingKey] = useState<string | null>(null);
  const [muscleFilter, setMuscleFilter] = useState<MuscleTag | "TODOS">("TODOS");
  const [libraryQuery, setLibraryQuery] = useState("");
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<User[]>("/api/instructor/students").then((list) => {
      setStudents(list);
      if (list[0]) setStudentId(list[0].id);
    });
  }, [router]);

  const libraryItems = useMemo(() => {
    const base = getExercisesByMuscle(muscleFilter);
    const q = libraryQuery.trim().toLowerCase();
    if (!q) return base;
    return base.filter(
      (e) =>
        e.name.toLowerCase().includes(q) ||
        e.description.toLowerCase().includes(q) ||
        muscleLabels[e.muscle].toLowerCase().includes(q)
    );
  }, [muscleFilter, libraryQuery]);

  function updateDay(weekDay: WeekDay, patch: Partial<DayForm>) {
    setDays((prev) => ({ ...prev, [weekDay]: { ...prev[weekDay], ...patch } }));
  }

  function updateExercise(weekDay: WeekDay, index: number, patch: Partial<ExerciseForm>) {
    setDays((prev) => ({
      ...prev,
      [weekDay]: {
        ...prev[weekDay],
        exercises: prev[weekDay].exercises.map((ex, i) =>
          i === index ? { ...ex, ...patch } : ex
        ),
      },
    }));
  }

  function addLibraryExercise(ex: LibraryExercise, atIndex?: number) {
    const form = libraryExerciseToForm(ex);
    setDays((prev) => {
      const day = prev[activeDay];
      if (day.restDay) return prev;
      const exercises = [...day.exercises];
      const emptyIdx = exercises.findIndex((e) => !e.name.trim());
      if (atIndex != null && atIndex >= 0 && atIndex <= exercises.length) {
        exercises.splice(atIndex, 0, form);
      } else if (emptyIdx >= 0) {
        exercises[emptyIdx] = form;
      } else {
        exercises.push(form);
      }
      return { ...prev, [activeDay]: { ...day, exercises } };
    });
    setMessage(`Adicionado: ${ex.name}`);
  }

  function moveExercise(from: number, to: number) {
    if (from === to) return;
    setDays((prev) => {
      const day = prev[activeDay];
      const exercises = [...day.exercises];
      const [item] = exercises.splice(from, 1);
      exercises.splice(to, 0, item);
      return { ...prev, [activeDay]: { ...day, exercises } };
    });
  }

  function removeExercise(index: number) {
    setDays((prev) => {
      const day = prev[activeDay];
      const exercises = day.exercises.filter((_, i) => i !== index);
      return {
        ...prev,
        [activeDay]: {
          ...day,
          exercises: exercises.length ? exercises : [emptyExercise()],
        },
      };
    });
  }

  function handleApplyTemplate(template: WeekTemplate) {
    const applied = applyTemplate(template);
    setTitle(applied.title);
    setDescription(applied.description);
    setDays(applied.days);
    setActiveDay("MONDAY");
    setMessage(`Ficha "${template.name}" aplicada — revise e publique.`);
  }

  async function handleMediaUpload(weekDay: WeekDay, index: number, file: File) {
    const key = `${weekDay}-${index}`;
    setUploadingKey(key);
    try {
      const url = await uploadMedia(file);
      const mediaType: MediaType = file.type.startsWith("video/") ? "VIDEO" : "IMAGE";
      updateExercise(weekDay, index, { videoUrl: url, mediaType });
      addRecentMedia({ url, mediaType, name: file.name || "Mídia do exercício" });
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro no upload");
    } finally {
      setUploadingKey(null);
    }
  }

  function handleRecentMedia(
    weekDay: WeekDay,
    index: number,
    item: { url: string; mediaType: MediaType }
  ) {
    updateExercise(weekDay, index, { videoUrl: item.url, mediaType: item.mediaType });
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage("");
    try {
      await api("/api/instructor/programs", {
        method: "POST",
        body: JSON.stringify({
          title,
          description,
          studentId,
          days: weekDayOrder.map((weekDay, sortOrder) => {
            const day = days[weekDay];
            return {
              weekDay,
              muscleGroup: day.muscleGroup || undefined,
              notes: day.notes || undefined,
              restDay: day.restDay,
              sortOrder,
              exercises: day.restDay
                ? []
                : day.exercises
                    .filter((ex) => ex.name.trim())
                    .map((ex, index) => ({
                      name: ex.name,
                      description: ex.description || undefined,
                      sets: ex.sets ? Number(String(ex.sets).split("-")[0]) : undefined,
                      reps: ex.reps ? Number(String(ex.reps).split("-")[0]) || undefined : undefined,
                      duration: ex.duration || undefined,
                      videoUrl: ex.videoUrl || undefined,
                      mediaType: ex.mediaType !== "NONE" ? ex.mediaType : undefined,
                      variationNotes: ex.variationNotes || undefined,
                      notes: ex.notes || undefined,
                      sortOrder: index,
                    })),
            };
          }),
        }),
      });
      setMessage("Ficha semanal publicada!");
      setTimeout(() => router.push("/treinos"), 800);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro ao publicar");
    } finally {
      setSaving(false);
    }
  }

  const currentDay = days[activeDay];

  return (
    <AppShell>
      <h2 className="mb-2 text-xl font-semibold">Nova ficha semanal</h2>
      <p className="mb-4 text-sm text-slate-400">
        Use uma ficha pronta ou monte arrastando exercícios da biblioteca.
      </p>

      <div className="mb-4 space-y-2">
        <p className="text-sm font-medium text-slate-300">Fichas prontas</p>
        <div className="flex flex-wrap gap-2">
          {WEEK_TEMPLATES.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => handleApplyTemplate(t)}
              className="rounded-lg border border-violet-700/60 bg-violet-950/40 px-3 py-2 text-left text-sm hover:bg-violet-900/50"
            >
              <span className="font-medium text-violet-200">{t.name}</span>
              <span className="mt-0.5 block text-xs text-slate-400">{t.description}</span>
            </button>
          ))}
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Título da ficha"
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
          required
        />
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Descrição geral e observações para o aluno"
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
          rows={3}
        />
        <select
          value={studentId}
          onChange={(e) => setStudentId(e.target.value)}
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
          required
        >
          {students.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>

        <div className="flex gap-1 overflow-x-auto pb-1">
          {weekDayOrder.map((weekDay) => (
            <button
              key={weekDay}
              type="button"
              onClick={() => setActiveDay(weekDay)}
              className={`shrink-0 rounded-full px-3 py-1.5 text-sm ${
                activeDay === weekDay
                  ? "bg-violet-600 text-white"
                  : "bg-slate-800 text-slate-300"
              }`}
            >
              {weekDayLabels[weekDay].slice(0, 3)}
              {!days[weekDay].restDay && days[weekDay].exercises.some((e) => e.name) ? " ·" : ""}
            </button>
          ))}
        </div>

        <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <h3 className="font-medium text-violet-300">{weekDayLabels[activeDay]}</h3>

            <label className="mt-3 flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={currentDay.restDay}
                onChange={(e) =>
                  updateDay(activeDay, {
                    restDay: e.target.checked,
                    exercises: e.target.checked ? [] : [emptyExercise()],
                  })
                }
              />
              Dia de descanso
            </label>

            {!currentDay.restDay && (
              <>
                <input
                  value={currentDay.muscleGroup}
                  onChange={(e) => updateDay(activeDay, { muscleGroup: e.target.value })}
                  placeholder="Grupos (ex: Peito + Tríceps)"
                  className="mt-3 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                />
                <textarea
                  value={currentDay.notes}
                  onChange={(e) => updateDay(activeDay, { notes: e.target.value })}
                  placeholder="Observações do dia para o aluno"
                  className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  rows={2}
                />

                <div
                  className="mt-4 min-h-[120px] space-y-3 rounded-lg border border-dashed border-slate-700 p-2"
                  onDragOver={(e) => {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = "copy";
                  }}
                  onDrop={(e) => {
                    e.preventDefault();
                    const libId = e.dataTransfer.getData("application/x-exercise-id");
                    const fromIdx = e.dataTransfer.getData("application/x-exercise-index");
                    if (libId) {
                      const ex = EXERCISE_LIBRARY.find((item) => item.id === libId);
                      if (ex) addLibraryExercise(ex, dragOverIndex ?? undefined);
                    } else if (fromIdx !== "") {
                      const from = Number(fromIdx);
                      if (!Number.isNaN(from) && dragOverIndex != null) {
                        moveExercise(from, dragOverIndex);
                      }
                    }
                    setDragOverIndex(null);
                  }}
                >
                  <p className="px-1 text-xs text-slate-500">
                    Arraste da biblioteca ou reordene os exercícios abaixo
                  </p>
                  {currentDay.exercises.map((exercise, index) => (
                    <div
                      key={`${activeDay}-${index}`}
                      draggable
                      onDragStart={(e) => {
                        e.dataTransfer.setData("application/x-exercise-index", String(index));
                        e.dataTransfer.effectAllowed = "move";
                      }}
                      onDragOver={(e) => {
                        e.preventDefault();
                        setDragOverIndex(index);
                      }}
                      onDragLeave={() => setDragOverIndex((v) => (v === index ? null : v))}
                      className={`rounded-lg border bg-slate-950 p-3 ${
                        dragOverIndex === index
                          ? "border-violet-500"
                          : "border-slate-800"
                      }`}
                    >
                      <div className="mb-2 flex items-center justify-between gap-2">
                        <p className="cursor-grab text-sm text-slate-400 active:cursor-grabbing">
                          ⋮⋮ Exercício {index + 1}
                        </p>
                        <button
                          type="button"
                          onClick={() => removeExercise(index)}
                          className="text-xs text-red-400"
                        >
                          Remover
                        </button>
                      </div>
                      <input
                        value={exercise.name}
                        onChange={(e) =>
                          updateExercise(activeDay, index, { name: e.target.value })
                        }
                        placeholder="Nome (ex: Supino reto)"
                        className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                      />
                      <textarea
                        value={exercise.description}
                        onChange={(e) =>
                          updateExercise(activeDay, index, { description: e.target.value })
                        }
                        placeholder="Descrição / execução"
                        className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                        rows={2}
                      />
                      <div className="mb-2 grid grid-cols-3 gap-2">
                        <input
                          value={exercise.sets}
                          onChange={(e) =>
                            updateExercise(activeDay, index, { sets: e.target.value })
                          }
                          placeholder="Séries"
                          className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                        />
                        <input
                          value={exercise.reps}
                          onChange={(e) =>
                            updateExercise(activeDay, index, { reps: e.target.value })
                          }
                          placeholder="Reps"
                          className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                        />
                        <input
                          value={exercise.duration}
                          onChange={(e) =>
                            updateExercise(activeDay, index, { duration: e.target.value })
                          }
                          placeholder="Duração"
                          className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                        />
                      </div>
                      <input
                        value={exercise.variationNotes}
                        onChange={(e) =>
                          updateExercise(activeDay, index, { variationNotes: e.target.value })
                        }
                        placeholder="Variação"
                        className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                      />
                      <MediaPicker
                        onSelectFile={(file) => handleMediaUpload(activeDay, index, file)}
                        onSelectRecent={(item) => handleRecentMedia(activeDay, index, item)}
                        onRemove={() =>
                          updateExercise(activeDay, index, { videoUrl: "", mediaType: "NONE" })
                        }
                        uploading={uploadingKey === `${activeDay}-${index}`}
                        attached={Boolean(exercise.videoUrl)}
                        mediaType={exercise.mediaType}
                        videoUrl={exercise.videoUrl}
                      />
                      <input
                        value={exercise.notes}
                        onChange={(e) =>
                          updateExercise(activeDay, index, { notes: e.target.value })
                        }
                        placeholder="Observações / dicas para o aluno"
                        className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                      />
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={() =>
                      updateDay(activeDay, {
                        exercises: [...currentDay.exercises, emptyExercise()],
                      })
                    }
                    className="text-sm text-violet-400"
                  >
                    + Adicionar exercício em branco
                  </button>
                </div>
              </>
            )}
          </div>

          <aside className="rounded-xl border border-slate-800 bg-slate-900 p-3 lg:sticky lg:top-4 lg:max-h-[80vh] lg:overflow-y-auto">
            <h3 className="text-sm font-medium text-slate-200">Biblioteca</h3>
            <input
              value={libraryQuery}
              onChange={(e) => setLibraryQuery(e.target.value)}
              placeholder="Buscar exercício..."
              className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-2 py-1.5 text-sm"
            />
            <div className="mt-2 flex flex-wrap gap-1">
              <button
                type="button"
                onClick={() => setMuscleFilter("TODOS")}
                className={`rounded-full px-2 py-0.5 text-xs ${
                  muscleFilter === "TODOS" ? "bg-violet-600" : "bg-slate-800"
                }`}
              >
                Todos
              </button>
              {(Object.keys(muscleLabels) as MuscleTag[]).map((m) => (
                <button
                  key={m}
                  type="button"
                  onClick={() => setMuscleFilter(m)}
                  className={`rounded-full px-2 py-0.5 text-xs ${
                    muscleFilter === m ? "bg-violet-600" : "bg-slate-800"
                  }`}
                >
                  {muscleLabels[m]}
                </button>
              ))}
            </div>
            <ul className="mt-3 space-y-2">
              {libraryItems.map((ex) => (
                <li key={ex.id}>
                  <button
                    type="button"
                    draggable
                    onDragStart={(e) => {
                      e.dataTransfer.setData("application/x-exercise-id", ex.id);
                      e.dataTransfer.effectAllowed = "copy";
                    }}
                    onClick={() => addLibraryExercise(ex)}
                    disabled={currentDay.restDay}
                    className="w-full rounded-lg border border-slate-800 bg-slate-950 p-2 text-left text-sm hover:border-violet-600 disabled:opacity-40"
                  >
                    <span className="font-medium text-slate-100">{ex.name}</span>
                    <span className="mt-0.5 block text-[11px] text-violet-300">
                      {muscleLabels[ex.muscle]} · {ex.sets}x{ex.reps || ex.duration}
                    </span>
                    <span className="mt-1 block text-[11px] text-slate-500 line-clamp-2">
                      {ex.notes}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </aside>
        </div>

        {message && <p className="text-sm text-green-400">{message}</p>}
        <button
          type="submit"
          disabled={saving || students.length === 0}
          className="w-full rounded-lg bg-violet-600 py-2.5 font-medium disabled:opacity-50"
        >
          {saving ? "Publicando..." : "Publicar ficha semanal"}
        </button>
      </form>
    </AppShell>
  );
}

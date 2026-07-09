"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
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

const defaultWeek = (): Record<WeekDay, DayForm> => ({
  MONDAY: defaultDay("Peito e Tríceps"),
  TUESDAY: defaultDay("Costas e Bíceps"),
  WEDNESDAY: defaultDay("Pernas"),
  THURSDAY: defaultDay("Ombros e Abdômen"),
  FRIDAY: defaultDay("Bíceps e Tríceps"),
  SATURDAY: defaultDay("Cardio / Funcional"),
  SUNDAY: defaultDay("", true),
});

export default function NovaFichaPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [title, setTitle] = useState("Ficha semanal");
  const [description, setDescription] = useState("");
  const [studentId, setStudentId] = useState("");
  const [days, setDays] = useState(defaultWeek());
  const [activeDay, setActiveDay] = useState<WeekDay>("MONDAY");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [uploadingKey, setUploadingKey] = useState<string | null>(null);

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

  async function handleMediaUpload(weekDay: WeekDay, index: number, file: File) {
    const key = `${weekDay}-${index}`;
    setUploadingKey(key);
    try {
      const url = await uploadMedia(file);
      const mediaType: MediaType = file.type.startsWith("video/") ? "VIDEO" : "IMAGE";
      updateExercise(weekDay, index, { videoUrl: url, mediaType });
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro no upload");
    } finally {
      setUploadingKey(null);
    }
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
                      sets: ex.sets ? Number(ex.sets) : undefined,
                      reps: ex.reps ? Number(ex.reps) : undefined,
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
      <h2 className="mb-4 text-xl font-semibold">Nova ficha semanal</h2>

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
          placeholder="Descrição geral (opcional)"
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
          rows={2}
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
            </button>
          ))}
        </div>

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
                placeholder="Grupo muscular (ex: Bíceps e Tríceps)"
                className="mt-3 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
              />
              <textarea
                value={currentDay.notes}
                onChange={(e) => updateDay(activeDay, { notes: e.target.value })}
                placeholder="Observações do dia"
                className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                rows={2}
              />

              <div className="mt-4 space-y-4">
                {currentDay.exercises.map((exercise, index) => (
                  <div
                    key={index}
                    className="rounded-lg border border-slate-800 bg-slate-950 p-3"
                  >
                    <p className="mb-2 text-sm text-slate-400">Exercício {index + 1}</p>
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
                        type="number"
                        className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                      />
                      <input
                        value={exercise.reps}
                        onChange={(e) =>
                          updateExercise(activeDay, index, { reps: e.target.value })
                        }
                        placeholder="Reps"
                        type="number"
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
                      placeholder="Variação (ex: pegada neutra, halteres...)"
                      className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm"
                    />
                    <label className="block">
                      <span className="mb-1 block text-sm text-slate-400">
                        Vídeo ou foto do exercício
                      </span>
                      <input
                        type="file"
                        accept="video/*,image/*"
                        capture="environment"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) handleMediaUpload(activeDay, index, file);
                        }}
                        className="w-full text-sm"
                      />
                      {uploadingKey === `${activeDay}-${index}` && (
                        <span className="text-xs text-violet-300">Enviando...</span>
                      )}
                      {exercise.videoUrl && (
                        <span className="text-xs text-green-400">
                          Mídia anexada ({exercise.mediaType === "IMAGE" ? "foto" : "vídeo"}) ✓
                        </span>
                      )}
                    </label>
                    <input
                      value={exercise.notes}
                      onChange={(e) =>
                        updateExercise(activeDay, index, { notes: e.target.value })
                      }
                      placeholder="Observações para o aluno"
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
                  + Adicionar exercício
                </button>
              </div>
            </>
          )}
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

"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { User, api, getToken, uploadMedia } from "@/lib/api";

interface ExerciseForm {
  name: string;
  description: string;
  sets: string;
  reps: string;
  duration: string;
  videoUrl: string;
  notes: string;
}

const emptyExercise = (): ExerciseForm => ({
  name: "",
  description: "",
  sets: "",
  reps: "",
  duration: "",
  videoUrl: "",
  notes: "",
});

export default function NovoTreinoPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [studentId, setStudentId] = useState("");
  const [scheduledDate, setScheduledDate] = useState("");
  const [exercises, setExercises] = useState<ExerciseForm[]>([emptyExercise()]);
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [uploadingIndex, setUploadingIndex] = useState<number | null>(null);

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

  function updateExercise(index: number, field: keyof ExerciseForm, value: string) {
    setExercises((prev) =>
      prev.map((ex, i) => (i === index ? { ...ex, [field]: value } : ex))
    );
  }

  async function handleVideoUpload(index: number, file: File) {
    setUploadingIndex(index);
    try {
      const url = await uploadMedia(file);
      updateExercise(index, "videoUrl", url);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro no upload");
    } finally {
      setUploadingIndex(null);
    }
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage("");
    try {
      await api("/api/instructor/workouts", {
        method: "POST",
        body: JSON.stringify({
          title,
          description,
          studentId,
          scheduledDate: scheduledDate || undefined,
          status: "ATIVO",
          exercises: exercises
            .filter((ex) => ex.name.trim())
            .map((ex, index) => ({
              name: ex.name,
              description: ex.description || undefined,
              sets: ex.sets ? Number(ex.sets) : undefined,
              reps: ex.reps ? Number(ex.reps) : undefined,
              duration: ex.duration || undefined,
              videoUrl: ex.videoUrl || undefined,
              notes: ex.notes || undefined,
              sortOrder: index,
            })),
        }),
      });
      setMessage("Treino criado com sucesso!");
      setTimeout(() => router.push("/treinos"), 800);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro ao criar treino");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Novo treino</h2>

      <form onSubmit={handleSubmit} className="space-y-4">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Título do treino"
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
          required
        />
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Descrição geral"
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
        <input
          type="date"
          value={scheduledDate}
          onChange={(e) => setScheduledDate(e.target.value)}
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2"
        />

        <div className="space-y-4">
          <h3 className="font-medium">Exercícios</h3>
          {exercises.map((exercise, index) => (
            <div key={index} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
              <p className="mb-2 text-sm text-violet-300">Exercício {index + 1}</p>
              <div className="grid gap-2">
                <input
                  value={exercise.name}
                  onChange={(e) => updateExercise(index, "name", e.target.value)}
                  placeholder="Nome do exercício"
                  className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  required
                />
                <textarea
                  value={exercise.description}
                  onChange={(e) => updateExercise(index, "description", e.target.value)}
                  placeholder="Descrição"
                  className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  rows={2}
                />
                <div className="grid grid-cols-3 gap-2">
                  <input
                    value={exercise.sets}
                    onChange={(e) => updateExercise(index, "sets", e.target.value)}
                    placeholder="Séries"
                    type="number"
                    className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  />
                  <input
                    value={exercise.reps}
                    onChange={(e) => updateExercise(index, "reps", e.target.value)}
                    placeholder="Reps"
                    type="number"
                    className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  />
                  <input
                    value={exercise.duration}
                    onChange={(e) => updateExercise(index, "duration", e.target.value)}
                    placeholder="Duração"
                    className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                  />
                </div>
                <label className="block">
                  <span className="mb-1 block text-sm text-slate-400">
                    Vídeo explicativo (galeria ou câmera)
                  </span>
                  <input
                    type="file"
                    accept="video/*,image/*"
                    capture="environment"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) handleVideoUpload(index, file);
                    }}
                    className="w-full text-sm"
                  />
                  {uploadingIndex === index && (
                    <span className="text-xs text-violet-300">Enviando...</span>
                  )}
                  {exercise.videoUrl && (
                    <span className="text-xs text-green-400">Vídeo anexado ✓</span>
                  )}
                </label>
                <input
                  value={exercise.notes}
                  onChange={(e) => updateExercise(index, "notes", e.target.value)}
                  placeholder="Observações para o aluno"
                  className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                />
              </div>
            </div>
          ))}
          <button
            type="button"
            onClick={() => setExercises((prev) => [...prev, emptyExercise()])}
            className="text-sm text-violet-400"
          >
            + Adicionar exercício
          </button>
        </div>

        {message && <p className="text-sm text-green-400">{message}</p>}
        <button
          type="submit"
          disabled={saving || students.length === 0}
          className="w-full rounded-lg bg-violet-600 py-2.5 font-medium disabled:opacity-50"
        >
          {saving ? "Salvando..." : "Publicar treino"}
        </button>
      </form>
    </AppShell>
  );
}

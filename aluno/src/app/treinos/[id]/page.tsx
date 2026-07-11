"use client";

import { FormEvent, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import ExerciseMedia from "@/components/ExerciseMedia";
import {
  RatingLevel,
  Workout,
  api,
  getToken,
  ratingLabels,
} from "@/lib/api";

const ratings: RatingLevel[] = ["MUITO_BOM", "BOM", "FACIL", "RUIM", "MUITO_RUIM"];

export default function TreinoDetalhePage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [workout, setWorkout] = useState<Workout | null>(null);
  const [rating, setRating] = useState<RatingLevel>("BOM");
  const [comment, setComment] = useState("");
  const [completed, setCompleted] = useState(false);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<Workout>(`/api/student/workouts/${id}`)
      .then(setWorkout)
      .catch(() => router.replace("/treinos"))
      .finally(() => setLoading(false));
  }, [id, router]);

  async function handleFeedback(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage("");
    try {
      await api(`/api/student/workouts/${id}/feedback`, {
        method: "POST",
        body: JSON.stringify({ rating, comment, completed }),
      });
      setMessage("Avaliação enviada com sucesso!");
      if (completed && workout) {
        setWorkout({ ...workout, status: "CONCLUIDO" });
      }
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro ao enviar");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <AppShell>
        <p className="text-slate-400">Carregando treino...</p>
      </AppShell>
    );
  }

  if (!workout) return null;

  return (
    <AppShell>
      <button onClick={() => router.back()} className="mb-4 text-sm text-blue-400">
        ← Voltar
      </button>
      <h2 className="text-xl font-semibold">{workout.title}</h2>
      {workout.description && (
        <p className="mt-2 text-slate-400">{workout.description}</p>
      )}

      <div className="mt-6 space-y-4">
        {workout.exercises.map((exercise, index) => (
          <div key={exercise.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-blue-400">Exercício {index + 1}</p>
            <h3 className="mt-1 font-medium">{exercise.name}</h3>
            {exercise.description && (
              <p className="mt-1 text-sm text-slate-400">{exercise.description}</p>
            )}
            <div className="mt-2 flex flex-wrap gap-3 text-sm text-slate-300">
              {exercise.sets && <span>{exercise.sets} séries</span>}
              {exercise.reps && <span>{exercise.reps} reps</span>}
              {exercise.duration && <span>{exercise.duration}</span>}
            </div>
            {exercise.videoUrl && (
              <ExerciseMedia
                url={exercise.videoUrl}
                mediaType={exercise.mediaType}
                name={exercise.name}
              />
            )}
            {exercise.notes && (
              <p className="mt-2 text-sm text-amber-300">{exercise.notes}</p>
            )}
          </div>
        ))}
      </div>

      <form onSubmit={handleFeedback} className="mt-8 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h3 className="font-medium">Como foi o treino?</h3>
        <div className="mt-3 flex flex-wrap gap-2">
          {ratings.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRating(r)}
              className={`rounded-full px-3 py-1.5 text-sm ${
                rating === r ? "bg-blue-600 text-white" : "bg-slate-800 text-slate-300"
              }`}
            >
              {ratingLabels[r]}
            </button>
          ))}
        </div>
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder="Comentário opcional..."
          className="mt-3 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
          rows={3}
        />
        <label className="mt-3 flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={completed}
            onChange={(e) => setCompleted(e.target.checked)}
          />
          Marquei o treino como concluído
        </label>
        {message && <p className="mt-2 text-sm text-green-400">{message}</p>}
        <button
          type="submit"
          disabled={saving}
          className="mt-4 w-full rounded-lg bg-blue-600 py-2 font-medium hover:bg-blue-500 disabled:opacity-50"
        >
          {saving ? "Enviando..." : "Enviar avaliação"}
        </button>
      </form>
    </AppShell>
  );
}

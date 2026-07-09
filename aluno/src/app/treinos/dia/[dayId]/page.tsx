"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import {
  RatingLevel,
  SessionComplete,
  WorkoutDay,
  WorkoutSession,
  api,
  formatDuration,
  formatElapsed,
  getToken,
  mediaUrl,
  ratingLabels,
  weekDayLabels,
} from "@/lib/api";

const ratings: RatingLevel[] = ["MUITO_BOM", "BOM", "FACIL", "RUIM", "MUITO_RUIM"];

function ExerciseMedia({ url, mediaType }: { url?: string; mediaType?: string }) {
  if (!url) return null;
  const src = mediaUrl(url);
  if (mediaType === "IMAGE") {
    return (
      <img
        src={src}
        alt="Referência do exercício"
        className="mt-3 max-h-48 w-full rounded-lg object-cover"
      />
    );
  }
  return (
    <video
      src={src}
      controls
      playsInline
      className="mt-3 w-full rounded-lg bg-black"
    />
  );
}

export default function TreinoDiaPage() {
  const { dayId } = useParams<{ dayId: string }>();
  const router = useRouter();
  const [day, setDay] = useState<WorkoutDay | null>(null);
  const [session, setSession] = useState<WorkoutSession | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showFinish, setShowFinish] = useState(false);
  const [rating, setRating] = useState<RatingLevel>("BOM");
  const [comment, setComment] = useState("");
  const [celebration, setCelebration] = useState<SessionComplete | null>(null);
  const [elapsed, setElapsed] = useState(0);

  const load = useCallback(async () => {
    const dayData = await api<WorkoutDay>(`/api/student/days/${dayId}`);
    setDay(dayData);
    const sessionData = await api<WorkoutSession>(`/api/student/days/${dayId}/sessions`, {
      method: "POST",
    });
    setSession(sessionData);
  }, [dayId]);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load()
      .catch(() => router.replace("/treinos"))
      .finally(() => setLoading(false));
  }, [load, router]);

  useEffect(() => {
    if (!session?.startedAt || session.completedAt) return;
    const start = new Date(session.startedAt).getTime();
    const tick = () => setElapsed(Math.floor((Date.now() - start) / 1000));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [session]);

  const completedSets = useMemo(() => {
    const map = new Map<string, Set<number>>();
    for (const log of session?.setLogs ?? []) {
      if (!map.has(log.exerciseId)) map.set(log.exerciseId, new Set());
      map.get(log.exerciseId)!.add(log.setNumber);
    }
    return map;
  }, [session]);

  const totalSets = useMemo(
    () => day?.exercises.reduce((acc, ex) => acc + (ex.sets ?? 1), 0) ?? 0,
    [day]
  );
  const doneSets = session?.setLogs.length ?? 0;
  const progress = totalSets > 0 ? Math.round((doneSets / totalSets) * 100) : 0;

  async function toggleSet(exerciseId: string, setNumber: number) {
    if (!session || saving) return;
    setSaving(true);
    try {
      const updated = await api<WorkoutSession>(
        `/api/student/sessions/${session.id}/sets`,
        {
          method: "POST",
          body: JSON.stringify({ exerciseId, setNumber }),
        }
      );
      setSession(updated);
    } finally {
      setSaving(false);
    }
  }

  async function handleFinish(e: FormEvent) {
    e.preventDefault();
    if (!session) return;
    setSaving(true);
    try {
      const result = await api<SessionComplete>(
        `/api/student/sessions/${session.id}/complete`,
        {
          method: "POST",
          body: JSON.stringify({ rating, comment }),
        }
      );
      setCelebration(result);
      setSession(result.session);
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

  if (!day || !session) return null;

  if (celebration) {
    return (
      <AppShell>
        <div className="rounded-2xl border border-green-700 bg-gradient-to-b from-green-950/50 to-slate-900 p-6 text-center">
          <p className="text-4xl">🎉</p>
          <h2 className="mt-3 text-xl font-bold text-green-300">Parabéns!</h2>
          <p className="mt-2 text-slate-300">{celebration.message}</p>
          <div className="mt-5 grid grid-cols-2 gap-3 text-left">
            <div className="rounded-lg bg-slate-900 p-3">
              <p className="text-xs text-slate-400">Tempo total</p>
              <p className="font-semibold">
                {formatDuration(celebration.session.totalDurationSeconds)}
              </p>
            </div>
            <div className="rounded-lg bg-slate-900 p-3">
              <p className="text-xs text-slate-400">Dias na semana</p>
              <p className="font-semibold">{celebration.stats.daysCompletedThisWeek}/7</p>
            </div>
            <div className="rounded-lg bg-slate-900 p-3">
              <p className="text-xs text-slate-400">Sequência</p>
              <p className="font-semibold">{celebration.stats.currentStreak} dias</p>
            </div>
            <div className="rounded-lg bg-slate-900 p-3">
              <p className="text-xs text-slate-400">Treinos totais</p>
              <p className="font-semibold">{celebration.stats.totalWorkoutsCompleted}</p>
            </div>
          </div>
          <button
            onClick={() => router.push("/treinos")}
            className="mt-6 w-full rounded-lg bg-green-600 py-2.5 font-medium"
          >
            Voltar à ficha semanal
          </button>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell>
      <button onClick={() => router.back()} className="mb-4 text-sm text-blue-400">
        ← Voltar
      </button>

      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <p className="text-sm text-blue-400">{weekDayLabels[day.weekDay]}</p>
          <h2 className="text-xl font-semibold">{day.muscleGroup}</h2>
          {day.notes && <p className="mt-1 text-sm text-slate-400">{day.notes}</p>}
        </div>
        <div className="rounded-lg bg-slate-900 px-3 py-2 text-center">
          <p className="text-xs text-slate-400">Cronômetro</p>
          <p className="font-mono text-lg text-amber-300">{formatDuration(elapsed)}</p>
        </div>
      </div>

      <div className="mb-5">
        <div className="mb-1 flex justify-between text-sm">
          <span className="text-slate-400">Progresso</span>
          <span className="text-blue-300">{doneSets}/{totalSets} séries ({progress}%)</span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-slate-800">
          <div
            className="h-full bg-blue-500 transition-all"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>

      <div className="space-y-4">
        {day.exercises.map((exercise, index) => {
          const sets = exercise.sets ?? 1;
          const done = completedSets.get(exercise.id) ?? new Set<number>();
          return (
            <div key={exercise.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
              <p className="text-sm text-blue-400">Exercício {index + 1}</p>
              <h3 className="mt-1 font-medium">{exercise.name}</h3>
              {exercise.description && (
                <p className="mt-1 text-sm text-slate-400">{exercise.description}</p>
              )}
              <div className="mt-2 flex flex-wrap gap-3 text-sm text-slate-300">
                <span>{sets} séries</span>
                {exercise.reps && <span>{exercise.reps} reps</span>}
                {exercise.duration && <span>{exercise.duration}</span>}
              </div>

              <ExerciseMedia url={exercise.videoUrl} mediaType={exercise.mediaType} />

              {exercise.variationNotes && (
                <p className="mt-2 rounded-lg bg-violet-950/40 px-3 py-2 text-sm text-violet-200">
                  Variação: {exercise.variationNotes}
                </p>
              )}
              {exercise.notes && (
                <p className="mt-2 text-sm text-amber-300">{exercise.notes}</p>
              )}

              <div className="mt-4">
                <p className="mb-2 text-sm text-slate-400">Marque cada série concluída:</p>
                <div className="flex flex-wrap gap-2">
                  {Array.from({ length: sets }, (_, i) => i + 1).map((setNumber) => {
                    const isDone = done.has(setNumber);
                    const log = session.setLogs.find(
                      (l) => l.exerciseId === exercise.id && l.setNumber === setNumber
                    );
                    return (
                      <button
                        key={setNumber}
                        type="button"
                        disabled={saving}
                        onClick={() => toggleSet(exercise.id, setNumber)}
                        className={`flex min-w-[4.5rem] flex-col items-center rounded-lg border px-3 py-2 text-sm transition ${
                          isDone
                            ? "border-green-600 bg-green-950/50 text-green-300"
                            : "border-slate-700 bg-slate-950 text-slate-300 hover:border-blue-500"
                        }`}
                      >
                        <span>{isDone ? "✓" : "○"} Série {setNumber}</span>
                        {log?.elapsedMs != null && (
                          <span className="mt-0.5 text-[10px] text-slate-500">
                            +{formatElapsed(log.elapsedMs)}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {!showFinish ? (
        <button
          onClick={() => setShowFinish(true)}
          disabled={doneSets === 0}
          className="mt-6 w-full rounded-lg bg-blue-600 py-3 font-medium disabled:opacity-40"
        >
          Finalizar treino
        </button>
      ) : (
        <form onSubmit={handleFinish} className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
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
            rows={2}
          />
          <button
            type="submit"
            disabled={saving}
            className="mt-4 w-full rounded-lg bg-green-600 py-2.5 font-medium disabled:opacity-50"
          >
            {saving ? "Salvando..." : "Confirmar e celebrar 🎉"}
          </button>
        </form>
      )}
    </AppShell>
  );
}

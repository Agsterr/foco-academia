"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import {
  StudentStats,
  WorkoutProgram,
  api,
  getToken,
  weekDayLabels,
  weekDayOrder,
  weekDayShort,
} from "@/lib/api";
import { getProfileStatus } from "@/lib/profile";

export default function TreinosPage() {
  const router = useRouter();
  const [program, setProgram] = useState<WorkoutProgram | null>(null);
  const [stats, setStats] = useState<StudentStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    void getProfileStatus()
      .then((s) => {
        if (!s.onboardingCompleted) {
          router.replace("/onboarding");
          return;
        }
        return Promise.all([
          api<WorkoutProgram>("/api/student/programs/active"),
          api<StudentStats>("/api/student/stats"),
        ]).then(([p, st]) => {
          setProgram(p);
          setStats(st);
        });
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Erro ao carregar"))
      .finally(() => setLoading(false));
  }, [router]);

  const daysByWeekDay = new Map(program?.days.map((d) => [d.weekDay, d]));

  return (
    <AppShell>
      <h2 className="mb-1 text-xl font-semibold">Minha ficha semanal</h2>
      {program && (
        <p className="mb-4 text-sm text-slate-400">{program.title}</p>
      )}

      {stats && (
        <div className="mb-5 grid grid-cols-3 gap-2">
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-2xl font-bold text-blue-400">{stats.daysCompletedThisWeek}</p>
            <p className="text-xs text-slate-400">dias esta semana</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-2xl font-bold text-green-400">{stats.currentStreak}</p>
            <p className="text-xs text-slate-400">sequência</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-2xl font-bold text-violet-400">{stats.totalWorkoutsCompleted}</p>
            <p className="text-xs text-slate-400">total</p>
          </div>
        </div>
      )}

      {loading && <p className="text-slate-400">Carregando...</p>}
      {error && (
        <p className="rounded-xl border border-dashed border-slate-700 p-6 text-center text-slate-400">
          {error}
        </p>
      )}

      {program && (
        <div className="space-y-2">
          {weekDayOrder.map((weekDay) => {
            const day = daysByWeekDay.get(weekDay);
            if (!day) return null;

            const isRest = day.restDay;
            const completed = day.completedThisWeek;
            const inProgress = !!day.activeSessionId;

            return (
              <Link
                key={day.id}
                href={isRest ? "#" : `/treinos/dia/${day.id}`}
                onClick={(e) => isRest && e.preventDefault()}
                className={`block rounded-xl border p-4 transition ${
                  isRest
                    ? "cursor-default border-slate-800/50 bg-slate-900/40 opacity-60"
                    : completed
                      ? "border-green-800 bg-green-950/30 hover:border-green-600"
                      : inProgress
                        ? "border-amber-700 bg-amber-950/20 hover:border-amber-500"
                        : "border-slate-800 bg-slate-900 hover:border-blue-600"
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <div>
                    <p className="text-sm font-medium text-blue-300">
                      {weekDayLabels[weekDay]}
                    </p>
                    <p className="mt-0.5 font-medium">
                      {isRest ? "Descanso" : day.muscleGroup || "Treino"}
                    </p>
                    {!isRest && (
                      <p className="mt-1 text-sm text-slate-400">
                        {day.exercises.length} exercícios
                      </p>
                    )}
                  </div>
                  <div className="text-right">
                    <span className="text-xs text-slate-500">{weekDayShort[weekDay]}</span>
                    {completed && (
                      <p className="mt-1 text-xs font-medium text-green-400">✓ Feito</p>
                    )}
                    {inProgress && !completed && (
                      <p className="mt-1 text-xs font-medium text-amber-400">Em andamento</p>
                    )}
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </AppShell>
  );
}

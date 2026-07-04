"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Workout, api, getToken } from "@/lib/api";

export default function TreinosPage() {
  const router = useRouter();
  const [workouts, setWorkouts] = useState<Workout[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<Workout[]>("/api/student/workouts")
      .then(setWorkouts)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }, [router]);

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Meus treinos</h2>
      {loading && <p className="text-slate-400">Carregando...</p>}
      {!loading && workouts.length === 0 && (
        <p className="rounded-xl border border-dashed border-slate-700 p-6 text-center text-slate-400">
          Nenhum treino disponível ainda. Seu instrutor vai publicar em breve.
        </p>
      )}
      <div className="space-y-3">
        {workouts.map((workout) => (
          <Link
            key={workout.id}
            href={`/treinos/${workout.id}`}
            className="block rounded-xl border border-slate-800 bg-slate-900 p-4 hover:border-blue-600"
          >
            <div className="flex items-start justify-between gap-2">
              <div>
                <h3 className="font-medium">{workout.title}</h3>
                <p className="mt-1 text-sm text-slate-400">
                  {workout.exercises.length} exercícios
                </p>
              </div>
              <span
                className={`rounded-full px-2 py-0.5 text-xs ${
                  workout.status === "CONCLUIDO"
                    ? "bg-green-900 text-green-300"
                    : "bg-blue-900 text-blue-300"
                }`}
              >
                {workout.status}
              </span>
            </div>
          </Link>
        ))}
      </div>
    </AppShell>
  );
}

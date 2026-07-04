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
    api<Workout[]>("/api/instructor/workouts")
      .then(setWorkouts)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }, [router]);

  return (
    <AppShell>
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-xl font-semibold">Treinos</h2>
        <Link
          href="/treinos/novo"
          className="rounded-lg bg-violet-600 px-3 py-1.5 text-sm font-medium"
        >
          + Novo
        </Link>
      </div>

      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-3">
        {workouts.map((w) => (
          <div key={w.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <div className="flex justify-between gap-2">
              <div>
                <h3 className="font-medium">{w.title}</h3>
                <p className="text-sm text-slate-400">Aluno: {w.student.name}</p>
                <p className="text-sm text-slate-500">{w.exercises.length} exercícios</p>
              </div>
              <span className="h-fit rounded-full bg-slate-800 px-2 py-0.5 text-xs">{w.status}</span>
            </div>
          </div>
        ))}
      </div>
    </AppShell>
  );
}

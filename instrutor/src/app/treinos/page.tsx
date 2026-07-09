"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { WorkoutProgram, api, getToken, weekDayLabels } from "@/lib/api";

export default function TreinosPage() {
  const router = useRouter();
  const [programs, setPrograms] = useState<WorkoutProgram[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<WorkoutProgram[]>("/api/instructor/programs")
      .then(setPrograms)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }, [router]);

  return (
    <AppShell>
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-xl font-semibold">Fichas semanais</h2>
        <Link
          href="/treinos/novo"
          className="rounded-lg bg-violet-600 px-3 py-1.5 text-sm font-medium"
        >
          + Nova ficha
        </Link>
      </div>

      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-3">
        {programs.map((program) => (
          <div key={program.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <div className="flex justify-between gap-2">
              <div>
                <h3 className="font-medium">{program.title}</h3>
                <p className="text-sm text-slate-400">Aluno: {program.student.name}</p>
                <p className="mt-1 text-sm text-slate-500">
                  {program.days.filter((d) => !d.restDay).length} dias de treino
                </p>
                <div className="mt-2 flex flex-wrap gap-1">
                  {program.days
                    .filter((d) => !d.restDay && d.muscleGroup)
                    .map((d) => (
                      <span
                        key={d.id}
                        className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-300"
                      >
                        {weekDayLabels[d.weekDay].slice(0, 3)}: {d.muscleGroup}
                      </span>
                    ))}
                </div>
              </div>
              <span
                className={`h-fit rounded-full px-2 py-0.5 text-xs ${
                  program.active ? "bg-green-900 text-green-300" : "bg-slate-800"
                }`}
              >
                {program.active ? "Ativa" : "Inativa"}
              </span>
            </div>
          </div>
        ))}
      </div>
    </AppShell>
  );
}

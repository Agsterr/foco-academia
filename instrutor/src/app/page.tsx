"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Dashboard, api, getToken } from "@/lib/api";

export default function DashboardPage() {
  const router = useRouter();
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<Dashboard>("/api/instructor/dashboard")
      .then(setDashboard)
      .catch((err) => {
        if (err instanceof Error && err.message.includes("Acesso negado")) {
          router.replace("/login?erro=perfil");
          return;
        }
        router.replace("/login");
      });
  }, [router]);

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Visão geral</h2>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard label="Alunos" value={dashboard?.totalStudents ?? 0} />
        <StatCard label="Treinos ativos" value={dashboard?.activeWorkouts ?? 0} />
        <StatCard label="Sugestões pendentes" value={dashboard?.pendingSuggestions ?? 0} />
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <Link
          href="/treinos/novo"
          className="rounded-xl border border-violet-700 bg-violet-950/50 p-4 text-center hover:bg-violet-900/40"
        >
          + Criar novo treino
        </Link>
        <Link
          href="/alunos"
          className="rounded-xl border border-slate-700 bg-slate-900 p-4 text-center hover:border-violet-600"
        >
          Gerenciar alunos
        </Link>
      </div>
    </AppShell>
  );
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
      <p className="text-sm text-slate-400">{label}</p>
      <p className="mt-1 text-3xl font-bold text-violet-300">{value}</p>
    </div>
  );
}

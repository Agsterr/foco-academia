"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, ClipboardList, MessageSquare, Plus, Users } from "lucide-react";
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
      .catch(() => router.replace("/login"));
  }, [router]);

  return (
    <AppShell>
      <div className="mb-6">
        <h2 className="text-2xl font-bold tracking-tight text-white">Visão geral</h2>
        <p className="mt-1 text-sm text-slate-400">Seus alunos e treinos em um lugar.</p>
      </div>
      <div className="grid grid-cols-3 gap-3 sm:gap-4">
        <StatCard label="Alunos" value={dashboard?.totalStudents} icon={Users} tone="from-violet-400 to-violet-700" href="/alunos" />
        <StatCard label="Treinos ativos" value={dashboard?.activeWorkouts} icon={ClipboardList} tone="from-fuchsia-400 to-pink-700" href="/treinos" />
        <StatCard label="Sugestões pendentes" value={dashboard?.pendingSuggestions} icon={MessageSquare} tone="from-amber-400 to-orange-600" href="/sugestoes" />
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <Link
          href="/treinos/novo"
          className="group flex items-center gap-4 rounded-2xl border border-violet-500/40 bg-gradient-to-br from-violet-500/20 to-transparent p-5 transition hover:border-violet-400"
        >
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-violet-500 text-white shadow-lg shadow-violet-900/50"><Plus className="h-5 w-5" /></span>
          <span className="flex-1 font-semibold text-white">Criar novo treino</span>
          <ArrowRight className="h-5 w-5 text-violet-300 transition group-hover:translate-x-1" />
        </Link>
        <Link href="/alunos" className="group card flex items-center gap-4 p-5 transition hover:border-slate-600">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-slate-800 text-slate-200"><Users className="h-5 w-5" /></span>
          <span className="flex-1 font-semibold text-white">Gerenciar alunos</span>
          <ArrowRight className="h-5 w-5 text-slate-400 transition group-hover:translate-x-1" />
        </Link>
      </div>
    </AppShell>
  );
}

function StatCard({ label, value, icon: Icon, tone, href }: { label: string; value?: number; icon: typeof Users; tone: string; href: string }) {
  return (
    <Link href={href} className="card p-3.5 transition hover:border-slate-600 sm:p-5">
      <span className={`flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br ${tone} text-white shadow-lg sm:h-10 sm:w-10`}>
        <Icon className="h-5 w-5" />
      </span>
      <p className="mt-3 text-2xl font-bold tracking-tight text-white sm:mt-4 sm:text-3xl">{value ?? "—"}</p>
      <p className="text-xs text-slate-400 sm:text-sm">{label}</p>
    </Link>
  );
}

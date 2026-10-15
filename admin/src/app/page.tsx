"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, Building2, CheckCircle2, GraduationCap, Plus, Users } from "lucide-react";
import AppShell from "@/components/AppShell";
import { Dashboard, api, getToken } from "@/lib/api";

export default function HomePage() {
  const router = useRouter();
  const [dash, setDash] = useState<Dashboard | null>(null);

  useEffect(() => {
    if (!getToken()) { router.replace("/login"); return; }
    api<Dashboard>("/api/admin/dashboard").then(setDash).catch(() => router.replace("/login"));
  }, [router]);

  return (
    <AppShell>
      <div className="mb-6">
        <h2 className="text-2xl font-bold tracking-tight text-white">Visão geral</h2>
        <p className="mt-1 text-sm text-slate-400">Academias e usuários da plataforma.</p>
      </div>
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <Stat label="Academias" value={dash?.totalAcademies} icon={Building2} tone="from-emerald-400 to-emerald-700" />
        <Stat label="Ativas" value={dash?.activeAcademies} icon={CheckCircle2} tone="from-teal-400 to-cyan-700" />
        <Stat label="Instrutores" value={dash?.totalInstructors} icon={GraduationCap} tone="from-sky-400 to-blue-700" />
        <Stat label="Alunos" value={dash?.totalStudents} icon={Users} tone="from-violet-400 to-fuchsia-700" />
      </div>
      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <Link href="/academias/nova" className="group flex items-center gap-4 rounded-2xl border border-emerald-500/40 bg-gradient-to-br from-emerald-500/15 to-transparent p-5 transition hover:border-emerald-400">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-emerald-500 text-white shadow-lg shadow-emerald-900/50"><Plus className="h-5 w-5" /></span>
          <span className="flex-1 font-semibold text-white">Criar nova academia</span>
          <ArrowRight className="h-5 w-5 text-emerald-300 transition group-hover:translate-x-1" />
        </Link>
        <Link href="/usuarios" className="group card flex items-center gap-4 p-5 transition hover:border-slate-600">
          <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-slate-800 text-slate-200"><Users className="h-5 w-5" /></span>
          <span className="flex-1 font-semibold text-white">Gerenciar usuários</span>
          <ArrowRight className="h-5 w-5 text-slate-400 transition group-hover:translate-x-1" />
        </Link>
      </div>
    </AppShell>
  );
}

function Stat({ label, value, icon: Icon, tone }: { label: string; value?: number; icon: typeof Users; tone: string }) {
  return (
    <div className="card p-4 sm:p-5">
      <span className={`flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br ${tone} text-white shadow-lg`}>
        <Icon className="h-5 w-5" />
      </span>
      <p className="mt-4 text-3xl font-bold tracking-tight text-white">{value ?? "—"}</p>
      <p className="text-sm text-slate-400">{label}</p>
    </div>
  );
}

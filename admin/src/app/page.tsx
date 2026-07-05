"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
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
      <h2 className="mb-4 text-xl font-semibold">Visão geral</h2>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Academias" value={dash?.totalAcademies ?? 0} />
        <Stat label="Ativas" value={dash?.activeAcademies ?? 0} />
        <Stat label="Instrutores" value={dash?.totalInstructors ?? 0} />
        <Stat label="Alunos" value={dash?.totalStudents ?? 0} />
      </div>
      <Link href="/academias/nova" className="mt-6 block rounded-xl border border-emerald-700 bg-emerald-950/40 p-4 text-center hover:bg-emerald-900/30">
        + Criar nova academia
      </Link>
    </AppShell>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
      <p className="text-sm text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-bold text-emerald-300">{value}</p>
    </div>
  );
}

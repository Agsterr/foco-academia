"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Academy, api, getToken } from "@/lib/api";

export default function AcademiasPage() {
  const router = useRouter();
  const [academies, setAcademies] = useState<Academy[]>([]);

  useEffect(() => {
    if (!getToken()) { router.replace("/login"); return; }
    api<Academy[]>("/api/admin/academies").then(setAcademies).catch(() => router.replace("/login"));
  }, [router]);

  return (
    <AppShell>
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-xl font-semibold">Academias</h2>
        <Link href="/academias/nova" className="rounded-lg bg-emerald-600 px-3 py-1.5 text-sm">+ Nova</Link>
      </div>
      <div className="space-y-3">
        {academies.map((a) => (
          <Link key={a.id} href={`/academias/${a.id}`} className="block rounded-xl border border-slate-800 bg-slate-900 p-4 hover:border-emerald-600">
            <div className="flex justify-between">
              <div>
                <h3 className="font-medium">{a.name}</h3>
                <p className="text-sm text-slate-400">{a.instructorCount} instrutores · {a.studentCount} alunos</p>
                <p className="text-xs text-slate-500">Limite: {a.deviceLimitPerUser} dispositivos/usuário</p>
              </div>
              <span className={`h-fit rounded-full px-2 py-0.5 text-xs ${a.active ? "bg-green-900 text-green-300" : "bg-red-900 text-red-300"}`}>
                {a.active ? "Ativa" : "Inativa"}
              </span>
            </div>
          </Link>
        ))}
      </div>
    </AppShell>
  );
}

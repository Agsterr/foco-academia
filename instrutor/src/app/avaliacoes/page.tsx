"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Feedback, api, getToken, ratingLabels } from "@/lib/api";

export default function AvaliacoesPage() {
  const router = useRouter();
  const [feedbacks, setFeedbacks] = useState<Feedback[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    api<Feedback[]>("/api/instructor/feedbacks")
      .then(setFeedbacks)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }, [router]);

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Avaliações dos treinos</h2>
      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-3">
        {feedbacks.map((f) => (
          <div key={f.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <div className="flex items-center justify-between">
              <p className="font-medium">{f.student.name}</p>
              <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs">
                {ratingLabels[f.rating]}
              </span>
            </div>
            {f.comment && <p className="mt-2 text-sm text-slate-300">{f.comment}</p>}
            <p className="mt-2 text-xs text-slate-500">
              {f.completed ? "Treino concluído" : "Em andamento"} ·{" "}
              {new Date(f.createdAt).toLocaleDateString("pt-BR")}
            </p>
          </div>
        ))}
        {!loading && feedbacks.length === 0 && (
          <p className="text-slate-400">Nenhuma avaliação ainda.</p>
        )}
      </div>
    </AppShell>
  );
}

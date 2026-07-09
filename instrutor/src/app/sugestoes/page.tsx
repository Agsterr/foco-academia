"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Suggestion, api, getToken } from "@/lib/api";

export default function SugestoesPage() {
  const router = useRouter();
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [responses, setResponses] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);

  function load() {
    api<Suggestion[]>("/api/instructor/suggestions")
      .then(setSuggestions)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router]);

  async function handleRespond(id: string, e: FormEvent) {
    e.preventDefault();
    const response = responses[id];
    if (!response?.trim()) return;
    await api(`/api/instructor/suggestions/${id}/respond`, {
      method: "POST",
      body: JSON.stringify({ response }),
    });
    load();
  }

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Sugestões dos alunos</h2>
      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-4">
        {!loading && suggestions.length === 0 && (
          <p className="rounded-xl border border-dashed border-slate-700 p-6 text-center text-slate-400">
            Nenhuma sugestão ainda. Os alunos podem enviar pelo app em Sugestões.
          </p>
        )}
        {suggestions.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="font-medium">{s.student.name}</p>
            <p className="mt-2">{s.message}</p>
            {s.category && <p className="mt-1 text-xs text-slate-500">{s.category}</p>}
            {s.response ? (
              <p className="mt-3 rounded-lg bg-slate-800 p-3 text-sm text-green-300">
                Respondido: {s.response}
              </p>
            ) : (
              <form onSubmit={(e) => handleRespond(s.id, e)} className="mt-3 flex gap-2">
                <input
                  value={responses[s.id] ?? ""}
                  onChange={(e) =>
                    setResponses((prev) => ({ ...prev, [s.id]: e.target.value }))
                  }
                  placeholder="Sua resposta..."
                  className="flex-1 rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
                />
                <button
                  type="submit"
                  className="rounded-lg bg-violet-600 px-3 py-2 text-sm"
                >
                  Responder
                </button>
              </form>
            )}
          </div>
        ))}
      </div>
    </AppShell>
  );
}

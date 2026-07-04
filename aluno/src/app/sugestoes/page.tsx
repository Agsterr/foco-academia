"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Suggestion, api, getToken } from "@/lib/api";

export default function SugestoesPage() {
  const router = useRouter();
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [message, setMessage] = useState("");
  const [category, setCategory] = useState("");
  const [feedback, setFeedback] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  function load() {
    api<Suggestion[]>("/api/student/suggestions")
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

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFeedback("");
    try {
      await api("/api/student/suggestions", {
        method: "POST",
        body: JSON.stringify({ message, category: category || undefined }),
      });
      setMessage("");
      setCategory("");
      setFeedback("Sugestão enviada!");
      load();
    } catch (err) {
      setFeedback(err instanceof Error ? err.message : "Erro ao enviar");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Sugestões</h2>

      <form onSubmit={handleSubmit} className="mb-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Sua sugestão para a academia..."
          className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
          rows={4}
          required
        />
        <input
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          placeholder="Categoria (opcional): equipamento, horário..."
          className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
        />
        {feedback && <p className="mt-2 text-sm text-green-400">{feedback}</p>}
        <button
          type="submit"
          disabled={saving}
          className="mt-3 w-full rounded-lg bg-blue-600 py-2 font-medium disabled:opacity-50"
        >
          {saving ? "Enviando..." : "Enviar sugestão"}
        </button>
      </form>

      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-3">
        {suggestions.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p>{s.message}</p>
            {s.category && <p className="mt-1 text-xs text-slate-500">{s.category}</p>}
            {s.response && (
              <p className="mt-3 rounded-lg bg-slate-800 p-3 text-sm text-green-300">
                Resposta: {s.response}
              </p>
            )}
            <p className="mt-2 text-xs text-slate-500">
              {new Date(s.createdAt).toLocaleDateString("pt-BR")} · {s.status}
            </p>
          </div>
        ))}
      </div>
    </AppShell>
  );
}

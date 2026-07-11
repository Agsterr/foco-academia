"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { FitnessGoal, completeOnboarding, goalLabels } from "@/lib/profile";

const goals: FitnessGoal[] = [
  "EMAGRECER",
  "GANHAR_MASSA",
  "CONDICIONAMENTO",
  "CORRIDA",
  "ALONGAMENTO",
  "MANUTENCAO",
];

export default function OnboardingPage() {
  const router = useRouter();
  const [heightCm, setHeightCm] = useState("170");
  const [weightKg, setWeightKg] = useState("70");
  const [goal, setGoal] = useState<FitnessGoal>("CONDICIONAMENTO");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await completeOnboarding({
        heightCm: Number(heightCm),
        weightKg: Number(weightKg),
        goal,
      });
      router.replace("/treinos");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao salvar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-8">
      <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6 shadow-xl">
        <h1 className="text-2xl font-bold text-blue-400">Bem-vindo!</h1>
        <p className="mt-1 text-sm text-slate-400">
          Conte um pouco sobre você para personalizar seus treinos.
        </p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label className="mb-1 block text-sm text-slate-300">Altura (cm)</label>
            <input
              type="number"
              min={50}
              max={250}
              value={heightCm}
              onChange={(e) => setHeightCm(e.target.value)}
              className="form-input"
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-slate-300">Peso atual (kg)</label>
            <input
              type="number"
              min={20}
              max={500}
              step="0.1"
              value={weightKg}
              onChange={(e) => setWeightKg(e.target.value)}
              className="form-input"
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-slate-300">Seu objetivo</label>
            <div className="grid gap-2">
              {goals.map((g) => (
                <label
                  key={g}
                  className={`flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-2 text-sm ${
                    goal === g
                      ? "border-blue-500 bg-blue-950/50 text-blue-200"
                      : "border-slate-700 text-slate-300"
                  }`}
                >
                  <input
                    type="radio"
                    name="goal"
                    value={g}
                    checked={goal === g}
                    onChange={() => setGoal(g)}
                  />
                  {goalLabels[g]}
                </label>
              ))}
            </div>
          </div>
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? "Salvando..." : "Começar"}
          </button>
        </form>
      </div>
    </div>
  );
}

"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import BluetoothScaleButton from "@/components/BluetoothScaleButton";
import WeightChart from "@/components/WeightChart";
import {
  BodyMeasurement,
  ProfileStatus,
  addMeasurement,
  getProfile,
  getProfileStatus,
  listMeasurements,
  submitGoalCheckIn,
} from "@/lib/profile";
import { getToken } from "@/lib/api";

export default function EvolucaoPage() {
  const router = useRouter();
  const [measurements, setMeasurements] = useState<BodyMeasurement[]>([]);
  const [status, setStatus] = useState<ProfileStatus | null>(null);
  const [currentWeight, setCurrentWeight] = useState<number | null>(null);
  const [weightInput, setWeightInput] = useState("");
  const [goalRating, setGoalRating] = useState(3);
  const [achieving, setAchieving] = useState(true);
  const [goalComment, setGoalComment] = useState("");
  const [message, setMessage] = useState("");

  function load() {
    void Promise.all([listMeasurements(), getProfileStatus(), getProfile()])
      .then(([m, s, p]) => {
        setMeasurements(m);
        setStatus(s);
        setCurrentWeight(p.currentWeightKg ?? null);
      })
      .catch((err) => {
        if (err instanceof Error && err.message.includes("Perfil não encontrado")) {
          router.replace("/onboarding");
          return;
        }
        router.replace("/login");
      });
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router]);

  async function handleWeight(e: FormEvent) {
    e.preventDefault();
    await addMeasurement({ weightKg: Number(weightInput) });
    setWeightInput("");
    setMessage("Peso registrado!");
    load();
  }

  async function handleGoalCheckIn(e: FormEvent) {
    e.preventDefault();
    await submitGoalCheckIn({
      achievingGoal: achieving,
      progressRating: goalRating,
      comment: goalComment || undefined,
    });
    setGoalComment("");
    setMessage("Obrigado pelo feedback sobre sua meta!");
    load();
  }

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Minha evolução</h2>
      {currentWeight != null && (
        <p className="mt-1 text-sm text-slate-400">
          Peso atual: <span className="text-blue-300">{currentWeight} kg</span>
        </p>
      )}

      {status?.pendingWeightCheck && (
        <div className="mt-4 rounded-xl border border-amber-700 bg-amber-950/40 p-4">
          <p className="font-medium text-amber-200">Hora de atualizar seu peso!</p>
          <p className="mt-1 text-sm text-amber-100/80">
            Seu instrutor marcou a data{" "}
            {status.pendingWeightSchedule?.dueDate
              ? new Date(status.pendingWeightSchedule.dueDate + "T12:00:00").toLocaleDateString("pt-BR")
              : "de hoje"}
            .
          </p>
        </div>
      )}

      <WeightChart measurements={measurements} />

      <BluetoothScaleButton onSaved={load} />

      <form onSubmit={handleWeight} className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h3 className="font-medium">Registrar peso (manual)</h3>
        <p className="mt-1 text-xs text-slate-500">
          Sem balança Bluetooth? Digite o valor normalmente.
        </p>
        <div className="mt-2 flex gap-2">
          <input
            type="number"
            step="0.1"
            min={20}
            max={500}
            value={weightInput}
            onChange={(e) => setWeightInput(e.target.value)}
            placeholder="kg"
            className="form-input flex-1"
            required
          />
          <button type="submit" className="btn-primary text-sm">
            Salvar
          </button>
        </div>
      </form>

      {status?.suggestGoalCheckIn && (
        <form onSubmit={handleGoalCheckIn} className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <h3 className="font-medium">Está atingindo seu objetivo?</h3>
          <label className="mt-3 flex items-center gap-2 text-sm">
            <input type="checkbox" checked={achieving} onChange={(e) => setAchieving(e.target.checked)} />
            Sinto que estou no caminho certo
          </label>
          <div className="mt-3">
            <label className="text-sm text-slate-400">Nota de progresso (1–5)</label>
            <input
              type="range"
              min={1}
              max={5}
              value={goalRating}
              onChange={(e) => setGoalRating(Number(e.target.value))}
              className="mt-1 w-full"
            />
            <p className="text-center text-sm text-blue-300">{goalRating}</p>
          </div>
          <textarea
            value={goalComment}
            onChange={(e) => setGoalComment(e.target.value)}
            placeholder="Comentário opcional"
            className="form-input mt-3 min-h-20"
          />
          <button type="submit" className="btn-primary mt-3 text-sm">
            Enviar opinião
          </button>
        </form>
      )}

      {message && <p className="mt-3 text-sm text-green-400">{message}</p>}
    </AppShell>
  );
}

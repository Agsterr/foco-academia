"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import {
  FitnessGoal,
  StudentProfile,
  getProfile,
  goalLabels,
  updateProfile,
} from "@/lib/profile";
import { getToken } from "@/lib/api";

const goals = Object.keys(goalLabels) as FitnessGoal[];

export default function PerfilPage() {
  const router = useRouter();
  const [profile, setProfile] = useState<StudentProfile | null>(null);
  const [heightCm, setHeightCm] = useState("");
  const [weightKg, setWeightKg] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [sex, setSex] = useState<StudentProfile["sex"]>("NAO_INFORMADO");
  const [activityLevel, setActivityLevel] =
    useState<StudentProfile["activityLevel"]>("MODERADO");
  const [goal, setGoal] = useState<FitnessGoal>("CONDICIONAMENTO");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    getProfile()
      .then((p) => {
        setProfile(p);
        setHeightCm(p.heightCm?.toString() ?? "");
        setWeightKg(p.currentWeightKg?.toString() ?? "");
        setBirthDate(p.birthDate ?? "");
        setSex(p.sex ?? "NAO_INFORMADO");
        setActivityLevel(p.activityLevel ?? "MODERADO");
        setGoal(p.goal ?? "CONDICIONAMENTO");
      })
      .catch(() => router.replace("/onboarding"));
  }, [router]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError("");
    setMessage("");
    try {
      const updated = await updateProfile({
        heightCm: heightCm ? Number(heightCm) : undefined,
        weightKg: weightKg ? Number(weightKg) : undefined,
        birthDate: birthDate || undefined,
        sex,
        activityLevel,
        goal,
      });
      setProfile(updated);
      setMessage("Perfil atualizado. As próximas estimativas de calorias usam estes dados.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao salvar");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Perfil físico</h2>
      <p className="mt-1 text-sm text-slate-400">
        {profile?.studentName} — dados para estimativa de calorias (MET).
      </p>

      <form onSubmit={handleSubmit} className="mt-4 space-y-3">
        <label className="block text-sm">
          Peso (kg)
          <input
            className="form-input mt-1"
            type="number"
            step="0.1"
            value={weightKg}
            onChange={(e) => setWeightKg(e.target.value)}
          />
        </label>
        <label className="block text-sm">
          Altura (cm)
          <input
            className="form-input mt-1"
            type="number"
            value={heightCm}
            onChange={(e) => setHeightCm(e.target.value)}
          />
        </label>
        <label className="block text-sm">
          Data de nascimento
          <input
            className="form-input mt-1"
            type="date"
            value={birthDate}
            onChange={(e) => setBirthDate(e.target.value)}
          />
        </label>
        <label className="block text-sm">
          Sexo
          <select
            className="form-input mt-1"
            value={sex}
            onChange={(e) => setSex(e.target.value as StudentProfile["sex"])}
          >
            <option value="MASCULINO">Masculino</option>
            <option value="FEMININO">Feminino</option>
            <option value="NAO_INFORMADO">Não informado</option>
          </select>
        </label>
        <label className="block text-sm">
          Nível de atividade
          <select
            className="form-input mt-1"
            value={activityLevel}
            onChange={(e) =>
              setActivityLevel(e.target.value as StudentProfile["activityLevel"])
            }
          >
            <option value="SEDENTARIO">Sedentário</option>
            <option value="LEVE">Leve</option>
            <option value="MODERADO">Moderado</option>
            <option value="INTENSO">Intenso</option>
            <option value="MUITO_INTENSO">Muito intenso</option>
          </select>
        </label>
        <label className="block text-sm">
          Objetivo
          <select
            className="form-input mt-1"
            value={goal}
            onChange={(e) => setGoal(e.target.value as FitnessGoal)}
          >
            {goals.map((g) => (
              <option key={g} value={g}>
                {goalLabels[g]}
              </option>
            ))}
          </select>
        </label>
        <button type="submit" disabled={saving} className="btn-primary w-full">
          {saving ? "Salvando..." : "Salvar"}
        </button>
      </form>

      {message && <p className="mt-3 text-sm text-green-400">{message}</p>}
      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
      {profile?.age != null && (
        <p className="mt-3 text-sm text-slate-500">Idade calculada: {profile.age} anos</p>
      )}
    </AppShell>
  );
}

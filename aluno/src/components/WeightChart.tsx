"use client";

import { BodyMeasurement } from "@/lib/profile";

export default function WeightChart({ measurements }: { measurements: BodyMeasurement[] }) {
  const sorted = [...measurements].reverse().slice(-12);
  if (sorted.length === 0) {
    return (
      <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-400">
        Nenhuma medição registrada ainda.
      </div>
    );
  }

  const weights = sorted.map((m) => m.weightKg);
  const min = Math.min(...weights) - 1;
  const max = Math.max(...weights) + 1;
  const range = max - min || 1;

  return (
    <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
      <h3 className="mb-3 font-medium">Gráfico de peso</h3>
      <div className="flex h-40 items-end gap-1">
        {sorted.map((m) => {
          const h = ((m.weightKg - min) / range) * 100;
          const date = new Date(m.recordedAt).toLocaleDateString("pt-BR", {
            day: "2-digit",
            month: "2-digit",
          });
          return (
            <div key={m.id} className="flex flex-1 flex-col items-center gap-1">
              <span className="text-[10px] text-slate-400">{m.weightKg}</span>
              <div
                className="w-full rounded-t bg-blue-500"
                style={{ height: `${Math.max(h, 8)}%` }}
                title={`${m.weightKg} kg`}
              />
              <span className="text-[9px] text-slate-500">{date}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

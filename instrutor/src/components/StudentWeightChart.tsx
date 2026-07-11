"use client";

export interface WeightPoint {
  id: string;
  weightKg: number;
  recordedAt: string;
  source?: string;
}

export default function StudentWeightChart({ measurements }: { measurements: WeightPoint[] }) {
  const sorted = [...measurements]
    .sort((a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime())
    .slice(-16);

  if (sorted.length === 0) {
    return (
      <p className="mt-3 text-sm text-slate-500">Sem histórico de peso ainda.</p>
    );
  }

  const weights = sorted.map((m) => m.weightKg);
  const last = weights[weights.length - 1];
  const first = weights[0];
  const delta = last - first;
  const minW = Math.min(...weights);
  const maxW = Math.max(...weights);
  const pad = Math.max((maxW - minW) * 0.15, 0.5);
  const yMin = minW - pad;
  const yMax = maxW + pad;
  const range = yMax - yMin || 1;
  const W = 400;
  const H = 140;
  const left = 28;
  const top = 10;
  const bottom = 22;
  const plotW = W - left - 8;
  const plotH = H - top - bottom;

  const points = sorted.map((m, i) => {
    const x = left + (sorted.length === 1 ? plotW / 2 : (i / (sorted.length - 1)) * plotW);
    const y = top + plotH - ((m.weightKg - yMin) / range) * plotH;
    return { x, y, m };
  });
  const line = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");

  return (
    <div className="mt-3 rounded-lg border border-slate-800 bg-slate-950 p-3">
      <div className="mb-2 flex justify-between text-xs text-slate-400">
        <span>Evolução ({sorted.length})</span>
        <span>
          {last.toFixed(1)} kg{" "}
          <span className={delta < 0 ? "text-green-400" : delta > 0 ? "text-amber-300" : ""}>
            ({delta > 0 ? "+" : ""}
            {delta.toFixed(1)})
          </span>
        </span>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} className="h-36 w-full">
        <path d={line} fill="none" stroke="#a78bfa" strokeWidth="2.5" strokeLinejoin="round" />
        {points.map((p) => (
          <circle key={p.m.id} cx={p.x} cy={p.y} r="3.5" fill="#4c1d95" stroke="#c4b5fd" strokeWidth="1.5" />
        ))}
      </svg>
    </div>
  );
}

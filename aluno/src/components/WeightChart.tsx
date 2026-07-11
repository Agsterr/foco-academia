"use client";

import { BodyMeasurement } from "@/lib/profile";

function sourceLabel(source: string) {
  switch (source) {
    case "SCALE_BLE":
      return "Balança";
    case "WATCH":
    case "IMPORT":
      return "Relógio/import";
    case "INSTRUCTOR":
      return "Instrutor";
    default:
      return "Manual";
  }
}

export default function WeightChart({ measurements }: { measurements: BodyMeasurement[] }) {
  const sorted = [...measurements]
    .sort((a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime())
    .slice(-20);

  if (sorted.length === 0) {
    return (
      <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-400">
        Nenhuma medição registrada ainda. Registre o peso manualmente ou conecte uma balança no app.
      </div>
    );
  }

  const weights = sorted.map((m) => m.weightKg);
  const first = weights[0];
  const last = weights[weights.length - 1];
  const delta = last - first;
  const minW = Math.min(...weights);
  const maxW = Math.max(...weights);
  const pad = Math.max((maxW - minW) * 0.15, 0.5);
  const yMin = minW - pad;
  const yMax = maxW + pad;
  const range = yMax - yMin || 1;

  const W = 560;
  const H = 200;
  const left = 36;
  const right = 12;
  const top = 16;
  const bottom = 28;
  const plotW = W - left - right;
  const plotH = H - top - bottom;

  const points = sorted.map((m, i) => {
    const x = left + (sorted.length === 1 ? plotW / 2 : (i / (sorted.length - 1)) * plotW);
    const y = top + plotH - ((m.weightKg - yMin) / range) * plotH;
    return { x, y, m };
  });

  const line = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const area =
    `${line} L ${points[points.length - 1].x.toFixed(1)} ${(top + plotH).toFixed(1)} ` +
    `L ${points[0].x.toFixed(1)} ${(top + plotH).toFixed(1)} Z`;

  const gridYs = [0, 0.25, 0.5, 0.75, 1].map((t) => ({
    y: top + plotH * (1 - t),
    label: (yMin + range * t).toFixed(1),
  }));

  return (
    <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
      <div className="mb-3 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="font-medium">Evolução do peso</h3>
          <p className="text-xs text-slate-500">Últimas {sorted.length} medições</p>
        </div>
        <div className="flex gap-4 text-sm">
          <div>
            <p className="text-[10px] uppercase text-slate-500">Atual</p>
            <p className="font-semibold text-blue-300">{last.toFixed(1)} kg</p>
          </div>
          <div>
            <p className="text-[10px] uppercase text-slate-500">Variação</p>
            <p
              className={`font-semibold ${
                delta < -0.05 ? "text-green-400" : delta > 0.05 ? "text-amber-300" : "text-slate-300"
              }`}
            >
              {delta > 0 ? "+" : ""}
              {delta.toFixed(1)} kg
            </p>
          </div>
          <div>
            <p className="text-[10px] uppercase text-slate-500">Faixa</p>
            <p className="font-semibold text-slate-300">
              {minW.toFixed(1)}–{maxW.toFixed(1)}
            </p>
          </div>
        </div>
      </div>

      <div className="w-full overflow-x-auto">
        <svg viewBox={`0 0 ${W} ${H}`} className="h-52 w-full min-w-[320px]" role="img" aria-label="Gráfico de peso">
          <defs>
            <linearGradient id="weightFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.35" />
              <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.02" />
            </linearGradient>
          </defs>
          {gridYs.map((g) => (
            <g key={g.label}>
              <line
                x1={left}
                x2={left + plotW}
                y1={g.y}
                y2={g.y}
                stroke="#1e293b"
                strokeWidth="1"
              />
              <text x={4} y={g.y + 3} fill="#64748b" fontSize="9">
                {g.label}
              </text>
            </g>
          ))}
          <path d={area} fill="url(#weightFill)" />
          <path d={line} fill="none" stroke="#60a5fa" strokeWidth="2.5" strokeLinejoin="round" />
          {points.map((p) => (
            <g key={p.m.id}>
              <circle cx={p.x} cy={p.y} r="4" fill="#1e3a8a" stroke="#93c5fd" strokeWidth="2" />
              <title>
                {p.m.weightKg.toFixed(1)} kg ·{" "}
                {new Date(p.m.recordedAt).toLocaleDateString("pt-BR")} · {sourceLabel(p.m.source)}
              </title>
            </g>
          ))}
          {points.map((p, i) =>
            i === 0 || i === points.length - 1 || i % Math.ceil(points.length / 4) === 0 ? (
              <text
                key={`d-${p.m.id}`}
                x={p.x}
                y={H - 8}
                textAnchor="middle"
                fill="#64748b"
                fontSize="9"
              >
                {new Date(p.m.recordedAt).toLocaleDateString("pt-BR", {
                  day: "2-digit",
                  month: "2-digit",
                })}
              </text>
            ) : null
          )}
        </svg>
      </div>

      <ul className="mt-3 max-h-36 space-y-1 overflow-y-auto text-xs text-slate-400">
        {[...sorted].reverse().slice(0, 8).map((m) => (
          <li key={m.id} className="flex justify-between gap-2 border-b border-slate-800/80 py-1">
            <span>
              {new Date(m.recordedAt).toLocaleDateString("pt-BR")} · {sourceLabel(m.source)}
            </span>
            <span className="font-medium text-slate-200">{m.weightKg.toFixed(1)} kg</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

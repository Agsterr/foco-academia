"use client";

import { RoutePoint } from "@/lib/cardio";

export default function RouteMap({ points }: { points: RoutePoint[] }) {
  if (points.length < 2) {
    return (
      <div className="flex h-48 items-center justify-center rounded-xl border border-slate-700 bg-slate-900 text-sm text-slate-500">
        Aguardando GPS...
      </div>
    );
  }

  const lats = points.map((p) => p.latitude);
  const lngs = points.map((p) => p.longitude);
  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);
  const pad = 0.0001;

  const toX = (lng: number) => ((lng - minLng + pad) / (maxLng - minLng + pad * 2)) * 100;
  const toY = (lat: number) => 100 - ((lat - minLat + pad) / (maxLat - minLat + pad * 2)) * 100;

  const path = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${toX(p.longitude)} ${toY(p.latitude)}`)
    .join(" ");

  return (
    <svg viewBox="0 0 100 100" className="h-48 w-full rounded-xl border border-slate-700 bg-slate-900">
      <path d={path} fill="none" stroke="#3b82f6" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
      <circle cx={toX(points[0].longitude)} cy={toY(points[0].latitude)} r="2" fill="#22c55e" />
      <circle
        cx={toX(points[points.length - 1].longitude)}
        cy={toY(points[points.length - 1].latitude)}
        r="2"
        fill="#ef4444"
      />
    </svg>
  );
}

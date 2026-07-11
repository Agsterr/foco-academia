"use client";

import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import { API_URL } from "@/lib/api";

interface AppVersion {
  versionName: string;
  versionCode: number;
  downloadUrl: string;
  releaseNotes?: string;
  forceUpdate: boolean;
}

export default function AppDownloadPage() {
  const [version, setVersion] = useState<AppVersion | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch(`${API_URL}/api/app/version`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("Nenhuma versão publicada"))))
      .then(setVersion)
      .catch((e) => setError(e instanceof Error ? e.message : "Erro"));
  }, []);

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">App mobile</h2>
      <p className="mt-2 text-sm text-slate-400">
        Baixe o app Android do aluno. Atualizações usam a mesma assinatura — não precisa desinstalar.
      </p>

      {error && <p className="mt-4 text-sm text-amber-400">{error}</p>}

      {version && (
        <div className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-6">
          <p className="text-lg font-semibold text-blue-300">
            Versão {version.versionName} (build {version.versionCode})
          </p>
          {version.releaseNotes && (
            <p className="mt-2 text-sm text-slate-400">{version.releaseNotes}</p>
          )}
          {version.forceUpdate && (
            <p className="mt-2 text-sm text-amber-400">Atualização obrigatória disponível</p>
          )}
          <a
            href={version.downloadUrl}
            className="btn-primary mt-4 inline-block w-full text-center text-sm"
          >
            Baixar APK Android
          </a>
        </div>
      )}

      <ul className="mt-6 space-y-2 text-sm text-slate-400">
        <li>• GPS, mapa e treinos outdoor offline</li>
        <li>• Atualização automática quando o instrutor publicar nova versão</li>
        <li>• Musculação continua disponível na web</li>
      </ul>
    </AppShell>
  );
}

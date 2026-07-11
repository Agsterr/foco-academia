"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import {
  AppRelease,
  ConnectedDevice,
  downloadAppRelease,
  formatDate,
  getToken,
  listAppReleases,
  listConnectedDevices,
  setReleaseForceUpdate,
  uploadAppRelease,
} from "@/lib/api";

function formatBytes(bytes: number) {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function AppMobilePage() {
  const router = useRouter();
  const [releases, setReleases] = useState<AppRelease[]>([]);
  const [devices, setDevices] = useState<ConnectedDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [uploading, setUploading] = useState(false);
  const [toggling, setToggling] = useState(false);
  const [versionName, setVersionName] = useState("");
  const [versionCode, setVersionCode] = useState("");
  const [releaseNotes, setReleaseNotes] = useState("");
  const [forceOnUpload, setForceOnUpload] = useState(false);
  const [file, setFile] = useState<File | null>(null);

  function load() {
    Promise.all([listAppReleases(), listConnectedDevices()])
      .then(([r, d]) => {
        setReleases(r);
        setDevices(d);
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Erro ao carregar"))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router]);

  async function handleDownload(release: AppRelease) {
    const blob = await downloadAppRelease(release.id);
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = release.fileName;
    link.click();
    URL.revokeObjectURL(url);
  }

  async function handleToggleForce(release: AppRelease) {
    setToggling(true);
    try {
      await setReleaseForceUpdate(release.id, !release.forceUpdate);
      setMessage(release.forceUpdate ? "Atualização obrigatória desativada" : "Atualização obrigatória ativada");
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro");
    } finally {
      setToggling(false);
    }
  }

  async function handleUpload(e: FormEvent) {
    e.preventDefault();
    if (!file) return;
    const code = Number.parseInt(versionCode, 10);
    if (!versionName.trim() || Number.isNaN(code)) {
      setError("Informe versionName e versionCode válidos");
      return;
    }
    setUploading(true);
    setError("");
    try {
      await uploadAppRelease({
        file,
        versionName: versionName.trim(),
        versionCode: code,
        releaseNotes: releaseNotes.trim() || undefined,
        forceUpdate: forceOnUpload,
      });
      setMessage("APK publicado com sucesso!");
      setFile(null);
      setVersionName("");
      setVersionCode("");
      setReleaseNotes("");
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao publicar");
    } finally {
      setUploading(false);
    }
  }

  const latest = releases[0];
  const outdated = devices.filter((d) => d.needsUpdate).length;

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">App mobile</h2>
      <p className="mt-1 text-sm text-slate-400">
        Deploy automático via GitHub Actions ao alterar <code>mobile/</code>. Mesma chave release = atualização in-place.
      </p>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
      {message && <p className="mt-3 text-sm text-green-400">{message}</p>}

      {latest && (
        <div className="mt-4 rounded-xl border border-emerald-800 bg-emerald-950/30 p-4">
          <p className="text-sm text-emerald-300">Versão publicada: {latest.versionName} (code {latest.versionCode})</p>
          <p className="mt-1 text-xs text-slate-400">
            {outdated > 0 ? `${outdated} dispositivo(s) desatualizado(s)` : "Todos os aparelhos na versão atual"}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <button type="button" onClick={() => handleDownload(latest)} className="btn-primary text-sm">
              Baixar APK
            </button>
            <button
              type="button"
              disabled={toggling}
              onClick={() => handleToggleForce(latest)}
              className={`rounded-lg px-4 py-2 text-sm ${latest.forceUpdate ? "bg-red-700 text-white" : "border border-slate-600"}`}
            >
              {latest.forceUpdate ? "Forçar atualização: ATIVA" : "Forçar atualização nos aparelhos"}
            </button>
          </div>
        </div>
      )}

      <form onSubmit={handleUpload} className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-4 space-y-3">
        <h3 className="font-medium">Publicar APK manualmente</h3>
        <input value={versionName} onChange={(e) => setVersionName(e.target.value)} placeholder="versionName (ex: 1.0.1)" className="form-input" />
        <input value={versionCode} onChange={(e) => setVersionCode(e.target.value)} placeholder="versionCode (ex: 2)" className="form-input" type="number" min={1} />
        <textarea value={releaseNotes} onChange={(e) => setReleaseNotes(e.target.value)} placeholder="Notas da versão" className="form-input min-h-20" />
        <input type="file" accept=".apk" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={forceOnUpload} onChange={(e) => setForceOnUpload(e.target.checked)} />
          Forçar atualização ao publicar
        </label>
        <button type="submit" disabled={uploading || !file} className="btn-primary text-sm">
          {uploading ? "Publicando..." : "Publicar APK"}
        </button>
      </form>

      <h3 className="mt-6 font-medium">Dispositivos mobile</h3>
      {loading ? (
        <p className="text-slate-400">Carregando...</p>
      ) : (
        <div className="mt-2 space-y-2">
          {devices.map((d) => (
            <div key={d.sessionId} className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-sm">
              <p className="font-medium">{d.userName} · {d.appVersion ?? "sem versão"}</p>
              <p className="text-slate-400">{d.userEmail} · {d.deviceLabel ?? d.deviceId.slice(0, 8)}</p>
              <p className={d.needsUpdate ? "text-amber-400" : "text-green-400"}>
                {d.needsUpdate ? "Desatualizado" : "Atualizado"} · {formatDate(d.lastSeenAt)}
              </p>
            </div>
          ))}
          {devices.length === 0 && <p className="text-slate-500">Nenhum dispositivo mobile conectado ainda.</p>}
        </div>
      )}

      <h3 className="mt-6 font-medium">Histórico de releases</h3>
      <div className="mt-2 space-y-2">
        {releases.map((r) => (
          <div key={r.id} className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-900 p-3 text-sm">
            <div>
              <p>{r.versionName} (code {r.versionCode}) · {formatBytes(r.fileSizeBytes)}</p>
              <p className="text-slate-500">{formatDate(r.createdAt)}</p>
            </div>
            <button type="button" onClick={() => handleDownload(r)} className="text-emerald-400">
              Baixar
            </button>
          </div>
        ))}
      </div>
    </AppShell>
  );
}

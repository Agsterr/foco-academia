"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { AdminUser, DeviceSession, api, formatDate, getToken } from "@/lib/api";

export default function UsuariosPage() {
  const router = useRouter();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [devices, setDevices] = useState<DeviceSession[]>([]);
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [message, setMessage] = useState("");

  function load() {
    api<AdminUser[]>("/api/admin/users").then(setUsers).catch(() => router.replace("/login"));
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router]);

  async function selectUser(user: AdminUser) {
    setSelected(user);
    const d = await api<DeviceSession[]>(`/api/admin/users/${user.id}/devices`);
    setDevices(d);
  }

  async function toggleActive(user: AdminUser) {
    await api(`/api/admin/users/${user.id}`, {
      method: "PATCH",
      body: JSON.stringify({ active: !user.active }),
    });
    setMessage(user.active ? "Usuário bloqueado" : "Usuário ativado");
    load();
  }

  async function removeDevice(deviceId: string) {
    if (!selected) return;
    await api(`/api/admin/users/${selected.id}/devices/${deviceId}`, { method: "DELETE" });
    setDevices((d) => d.filter((x) => x.deviceId !== deviceId));
    setMessage("Dispositivo removido");
    load();
  }

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Usuários e dispositivos</h2>
      {message && <p className="mt-2 text-sm text-green-400">{message}</p>}

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <div className="space-y-2">
          {users.map((u) => (
            <button
              key={u.id}
              type="button"
              onClick={() => selectUser(u)}
              className={`w-full rounded-xl border p-3 text-left ${
                selected?.id === u.id ? "border-emerald-500 bg-emerald-950/30" : "border-slate-800 bg-slate-900"
              }`}
            >
              <div className="flex justify-between">
                <div>
                  <p className="font-medium">{u.name} <span className="text-xs text-slate-500">({u.role})</span></p>
                  <p className="text-sm text-slate-400">{u.email}</p>
                  <p className="text-xs text-slate-500">{u.academyName ?? "—"}</p>
                </div>
                <div className="text-right text-xs">
                  <p className={u.active ? "text-green-400" : "text-red-400"}>{u.active ? "Ativo" : "Bloqueado"}</p>
                  <p className="text-slate-500">{u.deviceCount} app(s)</p>
                  <p className="text-slate-500">{formatDate(u.lastLoginAt)}</p>
                </div>
              </div>
            </button>
          ))}
        </div>

        {selected && (
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <h3 className="font-medium">{selected.name}</h3>
            <button
              type="button"
              onClick={() => toggleActive(selected)}
              className={`mt-3 rounded-lg px-4 py-2 text-sm ${
                selected.active ? "bg-red-700 text-white" : "bg-emerald-600 text-white"
              }`}
            >
              {selected.active ? "Bloquear usuário" : "Ativar usuário"}
            </button>

            <h4 className="mt-4 text-sm font-medium text-slate-300">Dispositivos instalados</h4>
            <div className="mt-2 space-y-2">
              {devices.map((d) => (
                <div key={d.id} className="flex items-center justify-between rounded-lg border border-slate-700 p-2 text-sm">
                  <div>
                    <p>{d.deviceLabel ?? d.deviceId.slice(0, 8)}</p>
                    <p className="text-xs text-slate-500">
                      {d.appClient}
                      {d.appVersion ? ` · ${d.appVersion}` : ""} · {formatDate(d.lastSeenAt)}
                    </p>
                  </div>
                  <button type="button" onClick={() => removeDevice(d.deviceId)} className="text-xs text-red-400">
                    Remover
                  </button>
                </div>
              ))}
              {devices.length === 0 && <p className="text-sm text-slate-500">Nenhum dispositivo.</p>}
            </div>
          </div>
        )}
      </div>
    </AppShell>
  );
}

"use client";

import { useCallback, useState } from "react";
import { addMeasurement } from "@/lib/profile";

/**
 * Web Bluetooth (Chrome/Edge Android ou desktop) — perfil padrão Weight Scale (0x181D).
 * Nem todas as balanças usam o perfil Bluetooth SIG; nesse caso use o app mobile.
 */
export default function BluetoothScaleButton({
  onSaved,
}: {
  onSaved: () => void;
}) {
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const supported =
    typeof navigator !== "undefined" && "bluetooth" in navigator;

  const connect = useCallback(async () => {
    if (!supported) {
      setStatus("Bluetooth na web só funciona no Chrome/Edge. Use o app mobile para mais balanças.");
      return;
    }
    setBusy(true);
    setStatus("Procurando balança… suba na balança se pedir.");
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const nav = navigator as any;
      const device = await nav.bluetooth.requestDevice({
        acceptAllDevices: false,
        filters: [{ services: ["weight_scale"] }],
        optionalServices: ["weight_scale", "body_composition", "battery_service"],
      });
      setStatus(`Conectando em ${device.name || "balança"}…`);
      const server = await device.gatt.connect();
      const service = await server.getPrimaryService("weight_scale");
      const characteristic = await service.getCharacteristic("weight_measurement");

      const weightKg = await new Promise<number>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error("Tempo esgotado — suba na balança")), 45000);
        characteristic.addEventListener("characteristicvaluechanged", (event: Event) => {
          const target = event.target as unknown as { value?: DataView };
          const value = target.value;
          if (!value) return;
          const parsed = parseWeightMeasurement(value);
          if (parsed != null) {
            clearTimeout(timer);
            resolve(parsed);
          }
        });
        characteristic.startNotifications().catch(reject);
      });

      setStatus(`Lido: ${weightKg.toFixed(1)} kg — salvando…`);
      await addMeasurement({
        weightKg: Number(weightKg.toFixed(1)),
        notes: "Medição via balança Bluetooth",
        source: "SCALE_BLE",
      });
      setStatus(`Peso ${weightKg.toFixed(1)} kg salvo da balança.`);
      onSaved();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Falha no Bluetooth";
      if (msg.toLowerCase().includes("cancel") || msg.toLowerCase().includes("chooser")) {
        setStatus("Conexão cancelada.");
      } else {
        setStatus(
          `${msg}. Dica: no app mobile há suporte mais amplo; o manual sempre funciona.`
        );
      }
    } finally {
      setBusy(false);
    }
  }, [onSaved, supported]);

  return (
    <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
      <h3 className="font-medium">Balança Bluetooth</h3>
      <p className="mt-1 text-xs text-slate-500">
        Compatível com balanças que usam o perfil padrão Weight Scale. Manual continua disponível abaixo.
      </p>
      <button
        type="button"
        disabled={busy}
        onClick={() => void connect()}
        className="btn-primary mt-3 text-sm disabled:opacity-50"
      >
        {busy ? "Aguardando balança…" : "Conectar balança"}
      </button>
      {status && <p className="mt-2 text-xs text-slate-400">{status}</p>}
      {!supported && (
        <p className="mt-2 text-xs text-amber-200/80">
          Este navegador não tem Web Bluetooth. Use Chrome no Android ou o app Foco Academia.
        </p>
      )}
    </div>
  );
}

/** Parse BLE Weight Measurement (0x2A9D) — kg ou lb. */
function parseWeightMeasurement(data: DataView): number | null {
  if (data.byteLength < 3) return null;
  const flags = data.getUint8(0);
  const imperial = (flags & 0x01) !== 0;
  const raw = data.getUint16(1, true);
  const value = raw / 200; // resolução 0.005
  if (imperial) {
    return value * 0.45359237; // lb → kg
  }
  return value;
}

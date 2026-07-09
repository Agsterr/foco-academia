"use client";

import { useEffect, useState } from "react";

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH || "";

export function PwaProvider() {
  const [installEvent, setInstallEvent] = useState<BeforeInstallPromptEvent | null>(null);
  const [installed, setInstalled] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    if (window.matchMedia("(display-mode: standalone)").matches) {
      setInstalled(true);
    }

    if ("serviceWorker" in navigator) {
      void navigator.serviceWorker
        .register(`${BASE_PATH}/sw.js`, { scope: `${BASE_PATH}/` })
        .catch(() => undefined);
    }

    const onInstallPrompt = (event: Event) => {
      event.preventDefault();
      setInstallEvent(event as BeforeInstallPromptEvent);
    };

    const onInstalled = () => {
      setInstalled(true);
      setInstallEvent(null);
    };

    window.addEventListener("beforeinstallprompt", onInstallPrompt);
    window.addEventListener("appinstalled", onInstalled);

    return () => {
      window.removeEventListener("beforeinstallprompt", onInstallPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  async function handleInstall() {
    if (!installEvent) return;
    await installEvent.prompt();
    const choice = await installEvent.userChoice;
    if (choice.outcome === "accepted") {
      setInstalled(true);
    }
    setInstallEvent(null);
  }

  if (installed || dismissed) {
    return null;
  }

  return (
    <div className="border-b border-violet-800 bg-violet-950/80 px-4 py-3">
      <div className="mx-auto max-w-5xl">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-sm font-medium text-violet-100">Instalar atalho do Instrutor</p>
            <p className="mt-1 text-xs text-violet-200/80">
              Abra <strong>instrutor-academia.focodev.com.br</strong> no Chrome/Edge e instale como app
              separado do Aluno.
            </p>
          </div>
          <div className="flex gap-2">
            {installEvent && (
              <button
                type="button"
                onClick={handleInstall}
                className="rounded-lg bg-violet-600 px-3 py-1.5 text-sm font-medium text-white"
              >
                Instalar agora
              </button>
            )}
            <button
              type="button"
              onClick={() => setDismissed(true)}
              className="rounded-lg border border-violet-700 px-3 py-1.5 text-sm text-violet-200"
            >
              Fechar
            </button>
          </div>
        </div>
        {!installEvent && (
          <p className="mt-2 text-xs text-violet-200/70">
            No Chrome: menu ⋮ → &quot;Instalar Foco Academia - Instrutor&quot; ou &quot;Salvar e compartilhar&quot; →
            &quot;Instalar&quot;.
          </p>
        )}
      </div>
    </div>
  );
}

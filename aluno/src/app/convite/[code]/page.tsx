"use client";

import { FormEvent, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import PasswordInput from "@/components/PasswordInput";
import { API_URL, api, getDeviceId, setAcademySlug, setToken } from "@/lib/api";
import { useHydrated } from "@/lib/use-hydrated";

interface InvitePreview {
  code: string;
  role: "ALUNO" | "INSTRUTOR";
  academyName: string;
  instructorName?: string;
  invitedBy?: string;
  name?: string;
  personal: boolean;
}

interface AcceptResponse {
  token: string;
  academySlug: string;
  user: { role: string };
}

const ANDROID_PACKAGE = "com.focodev.academia.aluno";
const INSTRUCTOR_WEB = "https://instrutor-academia.focodev.com.br/";

/** Abre o app instalado direto no convite; sem o app, o Android cai na página de download. */
function appIntentUrl(code: string): string {
  const fallback = encodeURIComponent(`${window.location.origin}/app`);
  return `intent://convite/${code}#Intent;scheme=focoacademia;package=${ANDROID_PACKAGE};S.browser_fallback_url=${fallback};end`;
}

export default function InvitePage() {
  const params = useParams<{ code: string }>();
  const router = useRouter();
  const code = (params?.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");

  const [invite, setInvite] = useState<InvitePreview | null>(null);
  const [loadError, setLoadError] = useState("");
  const hydrated = useHydrated();
  const isAndroid = hydrated && /android/i.test(navigator.userAgent);
  const [showForm, setShowForm] = useState(false);
  const [hasAccount, setHasAccount] = useState(false);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetch(`${API_URL}/api/auth/invites/${encodeURIComponent(code)}`)
      .then(async (r) => {
        const data = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error(typeof data.message === "string" ? data.message : "Convite não encontrado");
        return data as InvitePreview;
      })
      .then((data) => {
        setInvite(data);
        setName(data.name ?? "");
      })
      .catch((e) => setLoadError(e instanceof Error ? e.message : "Convite não encontrado"));
  }, [code]);

  async function handleAccept(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (!hasAccount && password !== confirm) {
      setError("As senhas não conferem.");
      return;
    }
    setLoading(true);
    try {
      const data = await api<AcceptResponse>(`/api/auth/invites/${encodeURIComponent(code)}/accept`, {
        method: "POST",
        body: JSON.stringify({
          name: hasAccount ? undefined : name.trim(),
          email: email.trim().toLowerCase(),
          password,
          deviceId: getDeviceId(),
          deviceLabel: navigator.userAgent.slice(0, 80),
          appClient: "WEB",
        }),
      });
      if (data.user.role === "INSTRUTOR") {
        // O painel do instrutor fica em outro endereço; lá ele entra com o e-mail e a senha.
        window.location.assign(INSTRUCTOR_WEB);
        return;
      }
      setAcademySlug(data.academySlug);
      setToken(data.token);
      router.push("/onboarding");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Não foi possível aceitar o convite");
    } finally {
      setLoading(false);
    }
  }

  if (loadError) {
    return (
      <Centered>
        <h1 className="text-xl font-bold text-red-400">Convite indisponível</h1>
        <p className="mt-2 text-sm text-slate-300">{loadError}</p>
      </Centered>
    );
  }
  if (!invite) {
    return (
      <Centered>
        <p className="text-sm text-slate-400">Carregando convite…</p>
      </Centered>
    );
  }

  const instructorInvite = invite.role === "INSTRUTOR";
  const title = instructorInvite
    ? `Você foi convidado(a) para a equipe da ${invite.academyName}`
    : invite.instructorName
      ? `Treine com ${invite.instructorName}${invite.personal ? "" : ` na ${invite.academyName}`}`
      : `Treine na ${invite.academyName}`;

  return (
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-8">
      <div className="rounded-2xl bg-gradient-to-br from-blue-400 to-blue-700 p-6 text-white shadow-xl">
        <p className="text-sm opacity-80">Foco Academia · convite</p>
        <h1 className="mt-1 text-2xl font-bold">{title}</h1>
        <p className="mt-2 text-sm opacity-90">
          {instructorInvite
            ? "Crie sua conta de instrutor para montar fichas e acompanhar seus alunos."
            : `${invite.invitedBy ?? invite.academyName} já deixou tudo pronto: é só criar sua conta.`}
        </p>
      </div>

      {!showForm && !instructorInvite && (
        <div className="mt-6 space-y-3">
          {isAndroid && (
            <a href={appIntentUrl(code)} className="btn-primary block w-full text-center">
              Abrir no app
            </a>
          )}
          {isAndroid && (
            <p className="text-center text-xs text-slate-400">
              Não tem o app? O botão leva para o download. Depois de instalar, toque no link de novo
              ou use “Tenho um código de convite” e digite <b className="text-slate-200">{code}</b>.
            </p>
          )}
          <button
            type="button"
            onClick={() => setShowForm(true)}
            className={`${isAndroid ? "rounded-xl border border-slate-700 py-3 text-slate-200" : "btn-primary"} block w-full text-center`}
          >
            Usar pelo navegador
          </button>
        </div>
      )}

      {(showForm || instructorInvite) && (
        <form onSubmit={handleAccept} className="mt-6 space-y-4 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          {!instructorInvite && (
            <label className="flex items-center gap-2 text-sm text-slate-300">
              <input type="checkbox" checked={hasAccount} onChange={(e) => setHasAccount(e.target.checked)} />
              Já tenho conta no app (meus treinos continuam)
            </label>
          )}
          {!hasAccount && (
            <div>
              <label htmlFor="convite-nome" className="mb-1 block text-sm text-slate-300">Seu nome</label>
              <input id="convite-nome" value={name} onChange={(e) => setName(e.target.value)} className="form-input" required minLength={2} />
            </div>
          )}
          <div>
            <label htmlFor="convite-email" className="mb-1 block text-sm text-slate-300">E-mail</label>
            <input id="convite-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} className="form-input" required />
          </div>
          <div>
            <label htmlFor="convite-senha" className="mb-1 block text-sm text-slate-300">
              {hasAccount ? "Senha da sua conta" : "Crie uma senha (mínimo 6)"}
            </label>
            <PasswordInput id="convite-senha" value={password} onChange={setPassword} required />
          </div>
          {!hasAccount && (
            <div>
              <label htmlFor="convite-confirma" className="mb-1 block text-sm text-slate-300">Confirme a senha</label>
              <PasswordInput id="convite-confirma" value={confirm} onChange={setConfirm} required />
            </div>
          )}
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? "Entrando…" : hasAccount ? "Vincular minha conta" : "Aceitar convite"}
          </button>
          <p className="text-xs text-slate-400">
            Sua conta fica neste aparelho. Se trocar de celular ou computador, peça para{" "}
            {instructorInvite ? "a academia" : "seu instrutor"} liberar.
          </p>
        </form>
      )}
    </div>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-8">
      <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6 text-center">{children}</div>
    </div>
  );
}

"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { LogOut, Activity, ClipboardList, Dumbbell, LayoutDashboard, MessageSquare, Star, Users } from "lucide-react";
import { clearToken } from "@/lib/api";

const links = [
  { href: "/", label: "Início", icon: LayoutDashboard },
  { href: "/alunos", label: "Alunos", icon: Users },
  { href: "/treinos", label: "Treinos", icon: ClipboardList },
  { href: "/cardio", label: "Cardio", icon: Activity },
  { href: "/sugestoes", label: "Sugestões", icon: MessageSquare },
  { href: "/avaliacoes", label: "Avaliações", icon: Star },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/login") {
    return <>{children}</>;
  }

  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname.startsWith(href));
  const logout = () => {
    clearToken();
    router.push("/login");
  };

  return (
    <div className="min-h-full">
      {/* Barra lateral (computador) */}
      <aside className="fixed inset-y-0 left-0 hidden w-64 flex-col border-r border-slate-800/80 bg-slate-950/80 backdrop-blur lg:flex">
        <div className="flex items-center gap-3 px-5 py-6">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-violet-400 to-violet-700 text-white shadow-lg shadow-violet-900/50">
            <Dumbbell className="h-5 w-5" />
          </span>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-violet-400">Foco Academia</p>
            <p className="font-semibold text-white">Painel do Instrutor</p>
          </div>
        </div>
        <nav className="flex-1 space-y-1 px-3">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                isActive(link.href)
                  ? "bg-gradient-to-r from-violet-500 to-violet-700 text-white shadow-lg shadow-violet-900/40"
                  : "text-slate-400 hover:bg-slate-800/70 hover:text-white"
              }`}
            >
              <link.icon className="h-[18px] w-[18px]" />
              {link.label}
            </Link>
          ))}
        </nav>
        <button onClick={logout} className="m-3 flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm text-slate-400 transition hover:bg-slate-800/70 hover:text-white">
          <LogOut className="h-[18px] w-[18px]" /> Sair
        </button>
      </aside>

      {/* Cabeçalho (celular e tablet) */}
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-slate-800/80 bg-slate-950/85 px-4 py-3 backdrop-blur lg:hidden">
        <div className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-violet-400 to-violet-700 text-white">
            <Dumbbell className="h-4 w-4" />
          </span>
          <p className="font-semibold text-white">Painel do Instrutor</p>
        </div>
        <button onClick={logout} aria-label="Sair" className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white">
          <LogOut className="h-5 w-5" />
        </button>
      </header>

      <main className="px-4 pb-28 pt-5 lg:ml-64 lg:px-10 lg:pb-12 lg:pt-10">
        <div className="mx-auto max-w-5xl">{children}</div>
      </main>

      {/* Navegação inferior (celular e tablet) */}
      <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-slate-800 bg-slate-950/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden">
        <div className="grid" style={{ gridTemplateColumns: `repeat(${links.length}, minmax(0, 1fr))` }}>
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={`flex flex-col items-center gap-1 py-2 text-[10px] font-medium ${
                isActive(link.href) ? "text-violet-300" : "text-slate-500"
              }`}
            >
              <span className={`flex h-8 w-11 items-center justify-center rounded-full transition ${isActive(link.href) ? "bg-violet-500/20" : ""}`}>
                <link.icon className="h-5 w-5" />
              </span>
              <span className="truncate">{link.label}</span>
            </Link>
          ))}
        </div>
      </nav>
    </div>
  );
}

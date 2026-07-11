"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { clearToken } from "@/lib/api";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/login") return <>{children}</>;

  return (
    <div className="mx-auto flex min-h-full max-w-5xl flex-col">
      <header className="sticky top-0 z-10 border-b border-slate-800 bg-slate-950/90 px-4 py-3 backdrop-blur">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-emerald-400">Admin Foco Academia</h1>
          <button onClick={() => { clearToken(); router.push("/login"); }} className="text-sm text-slate-400 hover:text-white">
            Sair
          </button>
        </div>
        <nav className="mt-3 flex gap-2">
          <Link href="/" className={`rounded-full px-3 py-1.5 text-sm ${pathname === "/" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-300"}`}>
            Início
          </Link>
          <Link href="/academias" className={`rounded-full px-3 py-1.5 text-sm ${pathname.startsWith("/academias") ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-300"}`}>
            Academias
          </Link>
          <Link href="/usuarios" className={`rounded-full px-3 py-1.5 text-sm ${pathname.startsWith("/usuarios") ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-300"}`}>
            Usuários
          </Link>
          <Link href="/app-mobile" className={`rounded-full px-3 py-1.5 text-sm ${pathname.startsWith("/app-mobile") ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-300"}`}>
            App mobile
          </Link>
        </nav>
      </header>
      <main className="flex-1 px-4 py-4">{children}</main>
    </div>
  );
}

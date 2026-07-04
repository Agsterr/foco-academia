"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { clearToken } from "@/lib/api";

const links = [
  { href: "/", label: "Início" },
  { href: "/alunos", label: "Alunos" },
  { href: "/treinos", label: "Treinos" },
  { href: "/sugestoes", label: "Sugestões" },
  { href: "/avaliacoes", label: "Avaliações" },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/login") {
    return <>{children}</>;
  }

  return (
    <div className="mx-auto flex min-h-full max-w-3xl flex-col">
      <header className="sticky top-0 z-10 border-b border-slate-800 bg-slate-950/90 px-4 py-3 backdrop-blur">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-violet-400">Painel Instrutor</h1>
          <button
            onClick={() => {
              clearToken();
              router.push("/login");
            }}
            className="text-sm text-slate-400 hover:text-white"
          >
            Sair
          </button>
        </div>
        <nav className="mt-3 flex flex-wrap gap-2">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={`rounded-full px-3 py-1.5 text-sm ${
                (link.href === "/" ? pathname === "/" : pathname.startsWith(link.href))
                  ? "bg-violet-600 text-white"
                  : "bg-slate-800 text-slate-300"
              }`}
            >
              {link.label}
            </Link>
          ))}
        </nav>
      </header>
      <main className="flex-1 px-4 py-4">{children}</main>
    </div>
  );
}

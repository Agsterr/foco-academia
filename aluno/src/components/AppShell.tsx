"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { clearToken } from "@/lib/api";

const links = [
  { href: "/treinos", label: "Treinos" },
  { href: "/outdoor", label: "Outdoor" },
  { href: "/dashboard", label: "Calorias" },
  { href: "/evolucao", label: "Evolução" },
  { href: "/perfil", label: "Perfil" },
  { href: "/sugestoes", label: "Sugestões" },
  { href: "/app", label: "App" },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/login" || pathname === "/onboarding") {
    return <>{children}</>;
  }

  return (
    <div className="mx-auto flex min-h-full max-w-lg flex-col">
      <header className="sticky top-0 z-10 border-b border-slate-800 bg-slate-950/90 px-4 py-3 backdrop-blur">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-blue-400">Foco Academia</h1>
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
        <nav className="mt-3 flex gap-2">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={`rounded-full px-4 py-1.5 text-sm ${
                pathname.startsWith(link.href)
                  ? "bg-blue-600 text-white"
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

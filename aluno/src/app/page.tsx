"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getToken } from "@/lib/api";
import AppShell from "@/components/AppShell";

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    router.replace("/treinos");
  }, [router]);

  return (
    <AppShell>
      <p className="text-slate-400">Carregando...</p>
    </AppShell>
  );
}

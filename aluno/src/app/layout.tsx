import type { Metadata, Viewport } from "next";
import { Geist } from "next/font/google";
import { PwaProvider } from "@/components/PwaProvider";
import "./globals.css";

const geist = Geist({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Foco Academia - Aluno",
  description: "Seus treinos na palma da mão",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Academia Aluno",
  },
  icons: {
    icon: "/icons/icon-192.png",
    apple: "/icons/icon-192.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#2563eb",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={`${geist.className} h-full`}>
      <body className="min-h-full bg-slate-950 text-slate-100">
        <PwaProvider />
        {children}
      </body>
    </html>
  );
}

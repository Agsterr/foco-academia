import type { Metadata, Viewport } from "next";
import { Geist } from "next/font/google";
import { PwaProvider } from "@/components/PwaProvider";
import "./globals.css";

const geist = Geist({ subsets: ["latin"] });
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

export const metadata: Metadata = {
  title: "Foco Academia - Instrutor",
  description: "Painel do instrutor",
  manifest: `${basePath}/manifest.json`,
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Academia Instrutor",
  },
  icons: {
    icon: `${basePath}/icons/icon-192.png`,
    apple: `${basePath}/icons/icon-192.png`,
  },
};

export const viewport: Viewport = {
  themeColor: "#7c3aed",
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

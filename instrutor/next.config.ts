import type { NextConfig } from "next";
import withPWAInit from "@ducanh2912/next-pwa";

const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const withPWA = withPWAInit({
  dest: "public",
  // PWA com basePath quebra cache/escopo; desativado em /instrutor até ícones e SW estarem corretos.
  disable: process.env.NODE_ENV === "development" || Boolean(basePath),
  register: true,
});

const nextConfig: NextConfig = {
  output: "standalone",
  turbopack: {},
  trailingSlash: Boolean(basePath),
  basePath,
  assetPrefix: basePath,
};

export default withPWA(nextConfig);

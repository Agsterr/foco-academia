import type { NextConfig } from "next";
import withPWAInit from "@ducanh2912/next-pwa";

const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const withPWA = withPWAInit({
  dest: "public",
  disable: process.env.NODE_ENV === "development" || Boolean(basePath),
  register: true,
});

const nextConfig: NextConfig = {
  output: "standalone",
  turbopack: {},
  basePath,
  assetPrefix: basePath,
};

export default withPWA(nextConfig);

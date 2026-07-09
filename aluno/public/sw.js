const CACHE = "foco-academia-aluno-v3";

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

// Necessário para instalação PWA; não intercepta instrutor/admin/api
self.addEventListener("fetch", (event) => {
  const path = new URL(event.request.url).pathname;
  if (
    path.startsWith("/instrutor") ||
    path.startsWith("/admin") ||
    path.startsWith("/api")
  ) {
    return;
  }
});

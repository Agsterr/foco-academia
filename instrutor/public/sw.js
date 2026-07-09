const CACHE = "foco-academia-instrutor-v3";

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", (event) => {
  const path = new URL(event.request.url).pathname;
  if (path.startsWith("/api") || path.startsWith("/admin") || path === "/") {
    return;
  }
});

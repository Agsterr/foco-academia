"use client";

import { useEffect, useMemo, useState } from "react";
import { mediaUrl, type MediaType } from "@/lib/api";

function detectMediaType(url: string, mediaType?: MediaType | string): "IMAGE" | "VIDEO" {
  if (mediaType === "IMAGE" || mediaType === "VIDEO") return mediaType;
  const lower = url.toLowerCase().split("?")[0];
  if (/\.(png|jpe?g|gif|webp|bmp|avif)$/.test(lower)) return "IMAGE";
  if (/\.(mp4|webm|ogg|mov|m4v)$/.test(lower)) return "VIDEO";
  // URLs do R2/upload sem extensão clara: assume vídeo se não for imagem óbvia
  return "VIDEO";
}

export default function ExerciseMedia({
  url,
  mediaType,
  name,
}: {
  url?: string;
  mediaType?: MediaType | string;
  name?: string;
}) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const src = useMemo(() => mediaUrl(url), [url]);
  const kind = useMemo(
    () => (src ? detectMediaType(src, mediaType) : null),
    [src, mediaType]
  );

  useEffect(() => {
    if (!lightboxOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setLightboxOpen(false);
    };
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [lightboxOpen]);

  if (!src || !kind || mediaType === "NONE") return null;

  if (kind === "IMAGE") {
    return (
      <>
        <button
          type="button"
          onClick={() => setLightboxOpen(true)}
          className="group relative mt-3 block w-full overflow-hidden rounded-xl border border-slate-700 bg-slate-950 text-left"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={src}
            alt={name ? `Foto: ${name}` : "Referência do exercício"}
            className="max-h-56 w-full object-contain"
            loading="lazy"
          />
          <span className="absolute bottom-2 right-2 rounded-md bg-black/70 px-2 py-1 text-xs text-white opacity-90 group-hover:opacity-100">
            Ampliar foto
          </span>
        </button>

        {lightboxOpen && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
            role="dialog"
            aria-modal="true"
            aria-label="Foto ampliada"
            onClick={() => setLightboxOpen(false)}
          >
            <button
              type="button"
              className="absolute right-4 top-4 rounded-full bg-white/10 px-3 py-1.5 text-sm text-white hover:bg-white/20"
              onClick={() => setLightboxOpen(false)}
            >
              Fechar
            </button>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={src}
              alt={name ? `Foto: ${name}` : "Referência do exercício"}
              className="max-h-[90vh] max-w-full object-contain"
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        )}
      </>
    );
  }

  return (
    <div className="mt-3 overflow-hidden rounded-xl border border-slate-700 bg-black">
      <video
        key={src}
        src={src}
        controls
        playsInline
        preload="metadata"
        controlsList="nodownload"
        className="aspect-video w-full bg-black"
      >
        Seu navegador não suporta reprodução de vídeo.
      </video>
      <p className="border-t border-slate-800 bg-slate-950 px-3 py-1.5 text-xs text-slate-400">
        Toque no play para assistir a demonstração
      </p>
    </div>
  );
}

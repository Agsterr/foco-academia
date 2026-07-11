"use client";

import { useEffect, useRef, useState } from "react";
import { API_URL, type MediaType } from "@/lib/api";
import { getRecentMedia, touchRecentMedia, type RecentMedia } from "@/lib/recent-media";

interface MediaPickerProps {
  onSelectFile: (file: File) => void;
  onSelectRecent: (item: RecentMedia) => void;
  onRemove?: () => void;
  uploading?: boolean;
  attached?: boolean;
  mediaType?: MediaType;
  videoUrl?: string;
}

function resolveMediaUrl(url: string) {
  return url.startsWith("http") ? url : `${API_URL}${url}`;
}

function HiddenFileInput({
  inputRef,
  accept,
  capture,
  onChange,
}: {
  inputRef: React.RefObject<HTMLInputElement | null>;
  accept: string;
  capture?: boolean | "user" | "environment";
  onChange: (file: File) => void;
}) {
  return (
    <input
      ref={inputRef}
      type="file"
      accept={accept}
      capture={capture}
      className="sr-only"
      onChange={(e) => {
        const file = e.target.files?.[0];
        if (file) onChange(file);
        e.target.value = "";
      }}
    />
  );
}

function AttachIcon() {
  return (
    <svg
      aria-hidden
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      className="h-6 w-6"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48"
      />
    </svg>
  );
}

export default function MediaPicker({
  onSelectFile,
  onSelectRecent,
  onRemove,
  uploading,
  attached,
  mediaType,
  videoUrl,
}: MediaPickerProps) {
  const galleryRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);
  const filesRef = useRef<HTMLInputElement>(null);
  const [recentItems, setRecentItems] = useState<RecentMedia[]>([]);
  const [showRecent, setShowRecent] = useState(false);

  useEffect(() => {
    setRecentItems(getRecentMedia());
  }, [attached, uploading]);

  const sourceOptions = [
    { id: "gallery", label: "Galeria", action: () => galleryRef.current?.click() },
    { id: "camera", label: "Câmera", action: () => cameraRef.current?.click() },
    { id: "files", label: "Arquivos", action: () => filesRef.current?.click() },
    {
      id: "recent",
      label: "Recentes",
      action: () => setShowRecent((prev) => !prev),
    },
  ] as const;

  const previewUrl = attached && videoUrl ? resolveMediaUrl(videoUrl) : null;
  const mediaLabel = mediaType === "IMAGE" ? "Foto" : mediaType === "VIDEO" ? "Vídeo" : "Mídia";

  return (
    <div className="space-y-2">
      <span className="block text-sm font-medium text-slate-300">Vídeo ou foto do exercício</span>

      {attached && previewUrl && !uploading ? (
        <div className="overflow-hidden rounded-xl border border-green-700/50 bg-slate-950">
          <div className="flex items-stretch gap-3 p-3">
            <div className="relative h-20 w-28 shrink-0 overflow-hidden rounded-lg bg-black">
              {mediaType === "IMAGE" ? (
                <img src={previewUrl} alt="Preview do exercício" className="h-full w-full object-cover" />
              ) : (
                <video src={previewUrl} className="h-full w-full object-cover" muted playsInline />
              )}
              <span className="absolute bottom-1 left-1 rounded bg-black/70 px-1.5 py-0.5 text-[10px] text-white">
                {mediaLabel}
              </span>
            </div>
            <div className="flex min-w-0 flex-1 flex-col justify-center gap-2">
              <p className="text-sm font-medium text-green-400">{mediaLabel} anexado</p>
              <p className="truncate text-xs text-slate-400">Pronto para o aluno ver no treino</p>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={uploading}
                  onClick={() => filesRef.current?.click()}
                  className="rounded-lg bg-violet-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-violet-500 disabled:opacity-50"
                >
                  Trocar arquivo
                </button>
                {onRemove && (
                  <button
                    type="button"
                    disabled={uploading}
                    onClick={onRemove}
                    className="rounded-lg border border-slate-600 px-3 py-1.5 text-xs text-slate-300 hover:border-slate-500 disabled:opacity-50"
                  >
                    Remover
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      ) : (
        <button
          type="button"
          disabled={uploading}
          onClick={() => filesRef.current?.click()}
          className="group flex w-full flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-600 bg-slate-900/60 px-4 py-5 text-center transition hover:border-violet-500 hover:bg-violet-950/20 disabled:cursor-wait disabled:opacity-60"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-violet-600/20 text-violet-300 transition group-hover:bg-violet-600/30 group-hover:text-violet-200">
            {uploading ? (
              <span className="h-5 w-5 animate-spin rounded-full border-2 border-violet-300 border-t-transparent" />
            ) : (
              <AttachIcon />
            )}
          </span>
          <span className="text-sm font-semibold text-slate-100">
            {uploading ? "Enviando arquivo..." : "Anexar vídeo ou foto"}
          </span>
          <span className="text-xs text-slate-400">
            Toque para escolher · MP4, MOV, JPG, PNG
          </span>
        </button>
      )}

      <div className="flex flex-wrap items-center gap-x-1 gap-y-1 text-xs text-slate-400">
        <span className="text-slate-500">Ou use:</span>
        {sourceOptions.map((option, index) => (
          <span key={option.id} className="inline-flex items-center gap-1">
            {index > 0 && <span className="text-slate-600">·</span>}
            <button
              type="button"
              disabled={uploading}
              onClick={option.action}
              className={`font-medium transition disabled:opacity-50 ${
                option.id === "recent" && showRecent
                  ? "text-violet-300"
                  : "text-violet-400 hover:text-violet-300"
              }`}
            >
              {option.label}
            </button>
          </span>
        ))}
      </div>

      <HiddenFileInput
        inputRef={galleryRef}
        accept="image/*,video/*"
        onChange={onSelectFile}
      />
      <HiddenFileInput
        inputRef={cameraRef}
        accept="image/*,video/*"
        capture="environment"
        onChange={onSelectFile}
      />
      <HiddenFileInput
        inputRef={filesRef}
        accept="image/*,video/*,.mp4,.mov,.avi,.webm,.mkv,.jpg,.jpeg,.png,.gif,.webp,.heic,.heif"
        onChange={onSelectFile}
      />

      {showRecent && (
        <div className="rounded-lg border border-slate-700 bg-slate-950 p-2">
          {recentItems.length === 0 ? (
            <p className="px-1 py-2 text-xs text-slate-400">
              Nenhum arquivo recente ainda.
            </p>
          ) : (
            <ul className="max-h-40 space-y-1 overflow-y-auto">
              {recentItems.map((item) => (
                <li key={item.url}>
                  <button
                    type="button"
                    disabled={uploading}
                    onClick={() => {
                      touchRecentMedia(item.url);
                      setRecentItems(getRecentMedia());
                      onSelectRecent(item);
                      setShowRecent(false);
                    }}
                    className="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm hover:bg-slate-900 disabled:opacity-50"
                  >
                    <span>{item.mediaType === "IMAGE" ? "🖼️" : "🎬"}</span>
                    <span className="min-w-0 flex-1 truncate text-slate-200">{item.name}</span>
                    <span className="shrink-0 text-xs text-slate-500">
                      {item.mediaType === "IMAGE" ? "foto" : "vídeo"}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

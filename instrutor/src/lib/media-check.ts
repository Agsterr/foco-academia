/** Mesmos limites da API: o servidor comprime para 720p, mas recusa vídeo acima de 60 s. */
export const MAX_VIDEO_SECONDS = 60;
const MAX_UPLOAD_MB = 150;
const MAX_IMAGE_MB = 10;

function videoDuration(file: File): Promise<number | null> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.preload = "metadata";
    const done = (value: number | null) => {
      URL.revokeObjectURL(url);
      resolve(value);
    };
    video.onloadedmetadata = () => done(Number.isFinite(video.duration) ? video.duration : null);
    video.onerror = () => done(null);
    video.src = url;
  });
}

/** Mensagem de erro antes de enviar (evita subir 150 MB para ser recusado), ou null se ok. */
export async function checkMediaFile(file: File): Promise<string | null> {
  const mb = file.size / (1024 * 1024);
  if (file.type.startsWith("image/")) {
    return mb > MAX_IMAGE_MB ? `Imagem grande demais (${mb.toFixed(0)} MB). Envie até ${MAX_IMAGE_MB} MB.` : null;
  }
  if (mb > MAX_UPLOAD_MB) {
    return `Vídeo grande demais (${mb.toFixed(0)} MB). Grave até ${MAX_VIDEO_SECONDS} segundos.`;
  }
  const seconds = await videoDuration(file);
  if (seconds !== null && seconds > MAX_VIDEO_SECONDS + 0.5) {
    return `Vídeo com ${Math.round(seconds)} s. Grave até ${MAX_VIDEO_SECONDS} segundos mostrando o exercício.`;
  }
  return null;
}

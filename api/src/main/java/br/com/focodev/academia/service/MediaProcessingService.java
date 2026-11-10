package br.com.focodev.academia.service;

import br.com.focodev.academia.exception.ApiException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/**
 * Prepara a mídia do exercício antes de guardar: vídeo vira MP4 de até 720p e 60 s
 * (um vídeo de celular de ~30 MB cai para poucos MB) e imagem tem limite de tamanho.
 * Assim o armazenamento (R2 ou disco) não cresce com vídeos 4K ou longos.
 */
@Slf4j
@Service
public class MediaProcessingService {

    public static final int MAX_VIDEO_SECONDS = 60;
    static final long MAX_IMAGE_BYTES = 10L * 1024 * 1024;
    /** Sem ffmpeg no servidor só passam vídeos já pequenos. */
    static final long MAX_UNPROCESSED_VIDEO_BYTES = 40L * 1024 * 1024;

    private static final Set<String> VIDEO_EXTENSIONS = Set.of(".mp4", ".mov", ".m4v", ".webm", ".3gp", ".mkv");
    private static final Set<String> IMAGE_EXTENSIONS = Set.of(".jpg", ".jpeg", ".png", ".webp", ".gif");

    /** Resultado pronto para guardar. Apagar {@link #path()} depois de usar. */
    public record ProcessedMedia(Path path, String extension, String contentType) {}

    @Value("${app.media.ffmpeg:ffmpeg}")
    private String ffmpeg = "ffmpeg";

    @Value("${app.media.ffprobe:ffprobe}")
    private String ffprobe = "ffprobe";

    public ProcessedMedia process(MultipartFile file) throws IOException {
        String extension = extensionOf(file.getOriginalFilename());
        String contentType = file.getContentType() != null ? file.getContentType().toLowerCase(Locale.ROOT) : "";
        boolean video = contentType.startsWith("video/") || VIDEO_EXTENSIONS.contains(extension);
        boolean image = !video && (contentType.startsWith("image/") || IMAGE_EXTENSIONS.contains(extension));

        if (image) {
            if (file.getSize() > MAX_IMAGE_BYTES) {
                throw new ApiException("Imagem grande demais: envie até 10 MB.");
            }
            if (!IMAGE_EXTENSIONS.contains(extension)) {
                throw new ApiException("Formato de imagem não suportado. Use JPG, PNG ou WEBP.");
            }
            Path tmp = Files.createTempFile("media-", extension);
            file.transferTo(tmp);
            return new ProcessedMedia(tmp, extension, contentType.isBlank() ? "image/jpeg" : contentType);
        }
        if (!video) {
            throw new ApiException("Envie um vídeo (MP4, MOV) ou uma foto (JPG, PNG).");
        }

        Path input = Files.createTempFile("media-in-", extension.isBlank() ? ".mp4" : extension);
        file.transferTo(input);
        try {
            return processVideo(input, file.getSize());
        } finally {
            Files.deleteIfExists(input);
        }
    }

    ProcessedMedia processVideo(Path input, long originalBytes) throws IOException {
        Double seconds = probeDuration(input);
        if (seconds == null) {
            // Sem ffprobe/ffmpeg: aceita só vídeo já pequeno, sem compressão.
            if (originalBytes > MAX_UNPROCESSED_VIDEO_BYTES) {
                throw new ApiException("Vídeo grande demais: envie até 40 MB.");
            }
            Path copy = Files.createTempFile("media-", ".mp4");
            Files.copy(input, copy, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            return new ProcessedMedia(copy, ".mp4", "video/mp4");
        }
        if (seconds > MAX_VIDEO_SECONDS + 0.5) {
            throw new ApiException("Vídeo muito longo: grave até " + MAX_VIDEO_SECONDS + " segundos mostrando o exercício.");
        }

        Path output = Files.createTempFile("media-out-", ".mp4");
        List<String> command = List.of(
                ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-i", input.toString(),
                "-t", String.valueOf(MAX_VIDEO_SECONDS),
                // Lado maior até 1280 px (720p), mantendo proporção e dimensões pares.
                "-vf", "scale='if(gte(iw,ih),min(1280,iw),-2)':'if(gte(iw,ih),-2,min(1280,ih))'",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "28", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "96k", "-ac", "1",
                "-movflags", "+faststart",
                "-threads", "2",
                output.toString()
        );
        Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
        try {
            byte[] ffmpegLog = process.getInputStream().readAllBytes();
            if (!process.waitFor(3, TimeUnit.MINUTES)) {
                process.destroyForcibly();
                throw new ApiException("Demorou demais para preparar o vídeo. Tente um vídeo mais curto.", HttpStatus.UNPROCESSABLE_ENTITY);
            }
            if (process.exitValue() != 0 || Files.size(output) == 0) {
                log.warn("ffmpeg falhou ({}): {}", process.exitValue(), new String(ffmpegLog, StandardCharsets.UTF_8));
                Files.deleteIfExists(output);
                throw new ApiException("Não foi possível ler este vídeo. Tente gravar de novo em MP4.");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Files.deleteIfExists(output);
            throw new ApiException("Envio interrompido.");
        }
        log.info("Vídeo comprimido: {} KB → {} KB ({} s)", originalBytes / 1024, Files.size(output) / 1024, Math.round(seconds));
        return new ProcessedMedia(output, ".mp4", "video/mp4");
    }

    /** Duração em segundos; nulo quando o ffprobe não está disponível. */
    Double probeDuration(Path input) throws IOException {
        Process process;
        try {
            process = new ProcessBuilder(
                    ffprobe, "-v", "error", "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1", input.toString()
            ).redirectErrorStream(true).start();
        } catch (IOException notInstalled) {
            log.warn("ffprobe não encontrado; vídeos não serão comprimidos");
            return null;
        }
        try {
            String out = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
            if (!process.waitFor(30, TimeUnit.SECONDS) || process.exitValue() != 0) {
                throw new ApiException("Não foi possível ler este vídeo. Tente gravar de novo em MP4.");
            }
            return Double.parseDouble(out.lines().findFirst().orElse("0"));
        } catch (NumberFormatException e) {
            throw new ApiException("Não foi possível ler este vídeo. Tente gravar de novo em MP4.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException("Envio interrompido.");
        }
    }

    static String extensionOf(String filename) {
        if (filename == null) return "";
        int dot = filename.lastIndexOf('.');
        if (dot < 0 || filename.length() - dot > 6) return "";
        return filename.substring(dot).toLowerCase(Locale.ROOT);
    }
}

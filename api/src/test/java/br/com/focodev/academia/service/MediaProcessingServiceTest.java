package br.com.focodev.academia.service;

import br.com.focodev.academia.exception.ApiException;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/** Compressão real com ffmpeg (instalado no CI e na imagem Docker da API). */
class MediaProcessingServiceTest {

    private static boolean ffmpegAvailable;

    @BeforeAll
    static void checkFfmpeg() {
        try {
            Process p = new ProcessBuilder("ffmpeg", "-version").redirectErrorStream(true).start();
            p.getInputStream().readAllBytes();
            ffmpegAvailable = p.waitFor(10, TimeUnit.SECONDS) && p.exitValue() == 0;
        } catch (Exception e) {
            ffmpegAvailable = false;
        }
    }

    /** Vídeo de teste Full HD com ruído (comprime pouco, como um vídeo de câmera). */
    private static Path makeVideo(int seconds) throws Exception {
        return makeVideo(seconds, "testsrc2=size=1920x1080:rate=30,noise=alls=40:allf=t");
    }

    private static Path makeVideo(int seconds, String source) throws Exception {
        Path out = Files.createTempFile("teste-", ".mp4");
        Process p = new ProcessBuilder(
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", source,
                "-f", "lavfi", "-i", "sine=frequency=440",
                "-t", String.valueOf(seconds),
                "-c:v", "libx264", "-preset", "ultrafast", "-crf", "12", "-c:a", "aac",
                out.toString()
        ).redirectErrorStream(true).start();
        p.getInputStream().readAllBytes();
        assertThat(p.waitFor(120, TimeUnit.SECONDS)).isTrue();
        return out;
    }

    private static int[] dimensions(Path video) throws Exception {
        Process p = new ProcessBuilder("ffprobe", "-v", "error", "-select_streams", "v:0",
                "-show_entries", "stream=width,height", "-of", "csv=p=0", video.toString())
                .redirectErrorStream(true).start();
        String out = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        p.waitFor(10, TimeUnit.SECONDS);
        String[] parts = out.split(",");
        return new int[]{Integer.parseInt(parts[0].trim()), Integer.parseInt(parts[1].trim())};
    }

    @Test
    void fullHdVideoBecomesSmaller720pMp4() throws Exception {
        assumeTrue(ffmpegAvailable, "ffmpeg não instalado");
        Path source = makeVideo(8);
        long originalSize = Files.size(source);
        MediaProcessingService service = new MediaProcessingService();

        MockMultipartFile upload = new MockMultipartFile(
                "file", "supino.mov", "video/quicktime", Files.readAllBytes(source));
        MediaProcessingService.ProcessedMedia media = service.process(upload);
        try {
            assertThat(media.extension()).isEqualTo(".mp4");
            assertThat(media.contentType()).isEqualTo("video/mp4");
            int[] wh = dimensions(media.path());
            assertThat(wh[0]).isEqualTo(1280);
            assertThat(wh[1]).isEqualTo(720);
            assertThat(Files.size(media.path())).isLessThan(originalSize / 2);
        } finally {
            Files.deleteIfExists(media.path());
            Files.deleteIfExists(source);
        }
    }

    @Test
    void videoLongerThanOneMinuteIsRejected() throws Exception {
        assumeTrue(ffmpegAvailable, "ffmpeg não instalado");
        // Para testar só a duração, um vídeo pequeno basta.
        Path source = makeVideo(75, "testsrc2=size=320x240:rate=15");
        try {
            MockMultipartFile upload = new MockMultipartFile(
                    "file", "longo.mp4", "video/mp4", Files.readAllBytes(source));
            ApiException error = assertThrows(ApiException.class, () -> new MediaProcessingService().process(upload));
            assertThat(error.getMessage()).contains("60 segundos");
        } finally {
            Files.deleteIfExists(source);
        }
    }

    @Test
    void withoutFfmpegOnlySmallVideosAreAccepted() throws Exception {
        MediaProcessingService service = new MediaProcessingService();
        ReflectionTestUtils.setField(service, "ffprobe", "/nao/existe/ffprobe");

        Path big = Files.createTempFile("grande-", ".mp4");
        try (RandomAccessFile raf = new RandomAccessFile(big.toFile(), "rw")) {
            raf.setLength(MediaProcessingService.MAX_UNPROCESSED_VIDEO_BYTES + 1);
        }
        try {
            ApiException error = assertThrows(ApiException.class,
                    () -> service.processVideo(big, Files.size(big)));
            assertThat(error.getMessage()).contains("40 MB");
        } finally {
            Files.deleteIfExists(big);
        }
    }

    @Test
    void imagesHaveSizeLimitAndOtherFilesAreRejected() throws Exception {
        MediaProcessingService service = new MediaProcessingService();
        byte[] tooBig = new byte[(int) MediaProcessingService.MAX_IMAGE_BYTES + 1];
        assertThrows(ApiException.class, () -> service.process(
                new MockMultipartFile("file", "foto.jpg", "image/jpeg", tooBig)));
        assertThrows(ApiException.class, () -> service.process(
                new MockMultipartFile("file", "planilha.pdf", "application/pdf", new byte[10])));

        MediaProcessingService.ProcessedMedia ok = service.process(
                new MockMultipartFile("file", "foto.png", "image/png", new byte[100]));
        try {
            assertThat(ok.extension()).isEqualTo(".png");
        } finally {
            Files.deleteIfExists(ok.path());
        }
    }
}

package br.com.focodev.academia.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Service
public class MediaStorageService {

    @Value("${app.upload.dir}")
    private String uploadDir;

    @Value("${app.r2.bucket:}")
    private String r2Bucket;

    @Value("${app.r2.endpoint:}")
    private String r2Endpoint;

    @Value("${app.r2.access-key-id:}")
    private String r2AccessKeyId;

    @Value("${app.r2.secret-access-key:}")
    private String r2SecretAccessKey;

    @Value("${app.r2.public-base-url:}")
    private String r2PublicBaseUrl;

    private volatile S3Client s3Client;

    /** Guarda a mídia já preparada (comprimida) e devolve a URL pública. */
    public String store(MediaProcessingService.ProcessedMedia media) throws IOException {
        String filename = UUID.randomUUID() + media.extension();
        if (isR2Enabled()) {
            PutObjectRequest request = PutObjectRequest.builder()
                    .bucket(r2Bucket)
                    .key(filename)
                    .contentType(media.contentType())
                    // Arquivo nunca muda (nome único): o Cloudflare pode guardar em cache por 1 ano.
                    .cacheControl("public, max-age=31536000, immutable")
                    .build();
            getS3Client().putObject(request, RequestBody.fromFile(media.path()));
            return r2PublicBaseUrl.replaceAll("/$", "") + "/" + filename;
        }
        Path directory = Paths.get(uploadDir).toAbsolutePath().normalize();
        Files.createDirectories(directory);
        Files.copy(media.path(), directory.resolve(filename));
        return "/api/media/" + filename;
    }

    private boolean isR2Enabled() {
        return !r2Bucket.isBlank()
                && !r2Endpoint.isBlank()
                && !r2AccessKeyId.isBlank()
                && !r2SecretAccessKey.isBlank()
                && !r2PublicBaseUrl.isBlank();
    }

    private S3Client getS3Client() {
        if (s3Client == null) {
            synchronized (this) {
                if (s3Client == null) {
                    s3Client = S3Client.builder()
                            .endpointOverride(URI.create(r2Endpoint))
                            .region(Region.of("auto"))
                            .credentialsProvider(StaticCredentialsProvider.create(
                                    AwsBasicCredentials.create(r2AccessKeyId, r2SecretAccessKey)))
                            .serviceConfiguration(S3Configuration.builder()
                                    .pathStyleAccessEnabled(true)
                                    .chunkedEncodingEnabled(false)
                                    .build())
                            .build();
                }
            }
        }
        return s3Client;
    }
}

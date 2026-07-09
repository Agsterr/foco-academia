package br.com.focodev.academia.service;

import br.com.focodev.academia.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
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

    public String store(MultipartFile file) throws IOException {
        String filename = buildFilename(file);

        if (isR2Enabled()) {
            uploadToR2(file, filename);
            return r2PublicBaseUrl.replaceAll("/$", "") + "/" + filename;
        }

        Path directory = Paths.get(uploadDir).toAbsolutePath().normalize();
        Files.createDirectories(directory);
        Files.copy(file.getInputStream(), directory.resolve(filename));
        return "/api/media/" + filename;
    }

    private boolean isR2Enabled() {
        return !r2Bucket.isBlank()
                && !r2Endpoint.isBlank()
                && !r2AccessKeyId.isBlank()
                && !r2SecretAccessKey.isBlank()
                && !r2PublicBaseUrl.isBlank();
    }

    private void uploadToR2(MultipartFile file, String filename) throws IOException {
        String contentType = file.getContentType();
        if (contentType == null || contentType.isBlank()) {
            contentType = "application/octet-stream";
        }

        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(r2Bucket)
                .key(filename)
                .contentType(contentType)
                .build();

        getS3Client().putObject(request, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
    }

    private S3Client getS3Client() {
        if (s3Client == null) {
            synchronized (this) {
                if (s3Client == null) {
                    s3Client = S3Client.builder()
                            .endpointOverride(URI.create(r2Endpoint))
                            .region(Region.US_EAST_1)
                            .credentialsProvider(StaticCredentialsProvider.create(
                                    AwsBasicCredentials.create(r2AccessKeyId, r2SecretAccessKey)))
                            .serviceConfiguration(S3Configuration.builder()
                                    .pathStyleAccessEnabled(true)
                                    .build())
                            .build();
                }
            }
        }
        return s3Client;
    }

    private static String buildFilename(MultipartFile file) {
        String original = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String extension = "";
        int dot = original.lastIndexOf('.');
        if (dot > 0) {
            extension = original.substring(dot);
        }
        if (extension.length() > 10) {
            throw new ApiException("Extensão de arquivo inválida");
        }
        return UUID.randomUUID() + extension;
    }
}

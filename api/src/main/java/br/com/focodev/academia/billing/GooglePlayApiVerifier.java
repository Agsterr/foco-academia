package br.com.focodev.academia.billing;

import br.com.focodev.academia.exception.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.auth.oauth2.GoogleCredentials;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Verificação pela Google Play Developer API (purchases.subscriptionsv2.get),
 * autenticada com a conta de serviço configurada em app.billing.google-service-account-json.
 */
@Slf4j
@Component
public class GooglePlayApiVerifier implements GooglePlayVerifier {

    private static final String SCOPE = "https://www.googleapis.com/auth/androidpublisher";
    private static final Set<String> VALID_STATES = Set.of(
            "SUBSCRIPTION_STATE_ACTIVE",
            "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
            // Cancelada pelo usuário: continua valendo até o fim do período pago.
            "SUBSCRIPTION_STATE_CANCELED"
    );

    private final BillingProperties properties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private volatile GoogleCredentials credentials;

    public GooglePlayApiVerifier(BillingProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean isConfigured() {
        String json = properties.googleServiceAccountJson();
        return json != null && !json.isBlank();
    }

    @Override
    public Optional<VerifiedSubscription> verify(String productId, String purchaseToken) {
        if (!isConfigured()) {
            return Optional.empty();
        }
        try {
            String url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                    + URLEncoder.encode(properties.packageNameOrDefault(), StandardCharsets.UTF_8)
                    + "/purchases/subscriptionsv2/tokens/"
                    + URLEncoder.encode(purchaseToken, StandardCharsets.UTF_8);
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .header("Authorization", "Bearer " + accessToken())
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 404 || response.statusCode() == 400 || response.statusCode() == 410) {
                throw new ApiException("Compra não encontrada no Google Play.");
            }
            if (response.statusCode() / 100 != 2) {
                log.warn("Google Play respondeu {} ao verificar assinatura", response.statusCode());
                throw new ApiException("Não foi possível confirmar a compra agora. Tente de novo em instantes.",
                        HttpStatus.BAD_GATEWAY);
            }
            return Optional.of(parse(productId, objectMapper.readTree(response.body())));
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Falha ao verificar assinatura no Google Play", e);
            throw new ApiException("Não foi possível confirmar a compra agora. Tente de novo em instantes.",
                    HttpStatus.BAD_GATEWAY);
        }
    }

    static VerifiedSubscription parse(String requestedProductId, JsonNode body) {
        String state = body.path("subscriptionState").asText("");
        Instant expiresAt = null;
        String productId = requestedProductId;
        boolean autoRenewing = false;
        for (JsonNode item : body.path("lineItems")) {
            String expiry = item.path("expiryTime").asText(null);
            if (expiry != null) {
                Instant parsed = Instant.parse(expiry);
                if (expiresAt == null || parsed.isAfter(expiresAt)) {
                    expiresAt = parsed;
                    productId = item.path("productId").asText(productId);
                    autoRenewing = item.path("autoRenewingPlan").path("autoRenewEnabled").asBoolean(false);
                }
            }
        }
        boolean active = VALID_STATES.contains(state) && expiresAt != null && expiresAt.isAfter(Instant.now());
        return new VerifiedSubscription(productId, expiresAt != null ? expiresAt : Instant.EPOCH, autoRenewing, active);
    }

    private String accessToken() throws Exception {
        if (credentials == null) {
            synchronized (this) {
                if (credentials == null) {
                    credentials = GoogleCredentials.fromStream(new ByteArrayInputStream(
                                    properties.googleServiceAccountJson().getBytes(StandardCharsets.UTF_8)))
                            .createScoped(List.of(SCOPE));
                }
            }
        }
        credentials.refreshIfExpired();
        return credentials.getAccessToken().getTokenValue();
    }
}

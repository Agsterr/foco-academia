package br.com.focodev.academia.security;

import br.com.focodev.academia.exception.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Limita tentativas de login por IP (proteção contra força bruta). */
@Component
public class LoginRateLimiter {

    private static final int MAX_ATTEMPTS = 10;
    private static final long WINDOW_MS = 15 * 60 * 1000L;

    private record Bucket(int count, long resetAt) {}

    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    public void check(HttpServletRequest request) {
        long now = System.currentTimeMillis();
        if (buckets.size() > 10_000) {
            buckets.entrySet().removeIf(e -> e.getValue().resetAt() <= now);
        }
        Bucket bucket = buckets.compute(clientIp(request), (ip, current) ->
                current == null || current.resetAt() <= now
                        ? new Bucket(1, now + WINDOW_MS)
                        : new Bucket(current.count() + 1, current.resetAt()));
        if (bucket.count() > MAX_ATTEMPTS) {
            throw new ApiException("Muitas tentativas. Aguarde alguns minutos.", HttpStatus.TOO_MANY_REQUESTS);
        }
    }

    private String clientIp(HttpServletRequest request) {
        for (String header : new String[]{"CF-Connecting-IP", "X-Real-IP", "X-Forwarded-For"}) {
            String value = request.getHeader(header);
            if (value != null && !value.isBlank()) {
                return value.split(",")[0].trim();
            }
        }
        return request.getRemoteAddr();
    }
}

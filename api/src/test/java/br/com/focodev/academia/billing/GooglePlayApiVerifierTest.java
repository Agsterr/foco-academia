package br.com.focodev.academia.billing;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Leitura da resposta de purchases.subscriptionsv2.get do Google Play. */
class GooglePlayApiVerifierTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private GooglePlayVerifier.VerifiedSubscription parse(String state, Instant expiry, boolean autoRenew) throws Exception {
        String json = """
                {"subscriptionState":"%s","lineItems":[
                  {"productId":"foco_premium_anual","expiryTime":"%s","autoRenewingPlan":{"autoRenewEnabled":%s}}
                ]}""".formatted(state, expiry, autoRenew);
        return GooglePlayApiVerifier.parse("foco_premium_anual", mapper.readTree(json));
    }

    @Test
    void activeSubscription() throws Exception {
        Instant expiry = Instant.now().plus(Duration.ofDays(20));
        var v = parse("SUBSCRIPTION_STATE_ACTIVE", expiry, true);
        assertTrue(v.active());
        assertTrue(v.autoRenewing());
        assertEquals("foco_premium_anual", v.productId());
        assertEquals(expiry.toEpochMilli() / 1000, v.expiresAt().toEpochMilli() / 1000);
    }

    @Test
    void canceledStillValidUntilPaidPeriodEnds() throws Exception {
        assertTrue(parse("SUBSCRIPTION_STATE_CANCELED", Instant.now().plus(Duration.ofDays(3)), false).active());
        assertFalse(parse("SUBSCRIPTION_STATE_CANCELED", Instant.now().minus(Duration.ofDays(1)), false).active());
    }

    @Test
    void expiredOrOnHoldIsNotActive() throws Exception {
        assertFalse(parse("SUBSCRIPTION_STATE_EXPIRED", Instant.now().plus(Duration.ofDays(3)), false).active());
        assertFalse(parse("SUBSCRIPTION_STATE_ON_HOLD", Instant.now().plus(Duration.ofDays(3)), false).active());
    }
}

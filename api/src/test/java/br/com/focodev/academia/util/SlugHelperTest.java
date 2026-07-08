package br.com.focodev.academia.util;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class SlugHelperTest {

    @Test
    void fromName_normalizesAccentsAndSpaces() {
        assertEquals("academia-fitness", SlugHelper.fromName("Academia Fitness"));
        assertEquals("academia-teste", SlugHelper.fromName("  Academia   Teste  "));
        assertEquals("joao-123", SlugHelper.fromName("João 123"));
    }

    @Test
    void fromName_handlesBlankAndNull() {
        assertEquals("academia", SlugHelper.fromName(null));
        assertEquals("academia", SlugHelper.fromName("   "));
        assertEquals("academia", SlugHelper.fromName("!!!"));
    }

    @Test
    void fromName_truncatesLongNames() {
        String longName = "a".repeat(100);
        assertEquals(64, SlugHelper.fromName(longName).length());
    }

    @Test
    void unique_returnsBaseWhenAvailable() {
        Set<String> existing = new HashSet<>();
        assertEquals("minha-academia", SlugHelper.unique("Minha Academia", existing::contains));
    }

    @Test
    void unique_appendsCounterWhenTaken() {
        Set<String> existing = new HashSet<>(Set.of("minha-academia"));
        assertEquals("minha-academia-2", SlugHelper.unique("Minha Academia", existing::contains));
    }

    @Test
    void unique_truncatesLongSlugWhenAppendingCounter() {
        String base = "a".repeat(64);
        Set<String> existing = new HashSet<>(Set.of(base));
        String result = SlugHelper.unique(base, existing::contains);
        assertTrue(result.startsWith("a"));
        assertTrue(result.endsWith("-2"));
        assertTrue(result.length() <= 64);
    }

    @Test
    void unique_throwsWhenExhausted() {
        Set<String> existing = new HashSet<>();
        for (int i = 1; i < 1000; i++) {
            existing.add(i == 1 ? "academia" : "academia-" + i);
        }
        assertThrows(IllegalStateException.class, () -> SlugHelper.unique("academia", existing::contains));
    }
}

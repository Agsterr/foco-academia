package br.com.focodev.academia.util;

import java.text.Normalizer;
import java.util.function.Predicate;

public final class SlugHelper {

    private SlugHelper() {
    }

    public static String fromName(String name) {
        if (name == null || name.isBlank()) {
            return "academia";
        }
        String normalized = Normalizer.normalize(name.trim().toLowerCase(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .replaceAll("[^a-z0-9]+", "-")
                .replaceAll("^-|-$", "");
        if (normalized.isBlank()) {
            return "academia";
        }
        return normalized.length() > 64 ? normalized.substring(0, 64) : normalized;
    }

    public static String unique(String base, Predicate<String> exists) {
        String slug = fromName(base);
        if (!exists.test(slug)) {
            return slug;
        }
        for (int i = 2; i < 1000; i++) {
            String candidate = slug + "-" + i;
            if (candidate.length() > 64) {
                candidate = slug.substring(0, Math.max(1, 64 - String.valueOf(i).length() - 1)) + "-" + i;
            }
            if (!exists.test(candidate)) {
                return candidate;
            }
        }
        throw new IllegalStateException("Não foi possível gerar slug único");
    }
}

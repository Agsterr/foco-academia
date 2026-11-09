package br.com.focodev.academia.config;

import br.com.focodev.academia.util.SlugHelper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;

@Configuration
@RequiredArgsConstructor
public class DatabaseSchemaFix {

    private final JdbcTemplate jdbcTemplate;

    @Bean
    @Order(0)
    CommandLineRunner fixDatabaseSchema() {
        return args -> {
            jdbcTemplate.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check");
            jdbcTemplate.execute("""
                    ALTER TABLE users ADD CONSTRAINT users_role_check
                    CHECK (role IN ('ADMIN', 'INSTRUTOR', 'ALUNO', 'GESTOR'))
                    """);

            // Fichas e treinos outdoor criados pelo próprio aluno não têm instrutor.
            dropNotNull("workout_programs", "instructor_id");
            dropNotNull("cardio_workouts", "instructor_id");

            jdbcTemplate.execute("ALTER TABLE academies ADD COLUMN IF NOT EXISTS slug VARCHAR(64)");
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT id::text AS id, name FROM academies WHERE slug IS NULL OR slug = ''"
            );
            for (Map<String, Object> row : rows) {
                String id = (String) row.get("id");
                String name = (String) row.get("name");
                String slug = SlugHelper.unique(name, candidate ->
                        Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                                "SELECT EXISTS(SELECT 1 FROM academies WHERE LOWER(slug) = LOWER(?))",
                                Boolean.class,
                                candidate
                        ))
                );
                jdbcTemplate.update("UPDATE academies SET slug = ? WHERE id = ?::uuid", slug, id);
            }
        };
    }

    private void dropNotNull(String table, String column) {
        try {
            jdbcTemplate.execute("ALTER TABLE " + table + " ALTER COLUMN " + column + " DROP NOT NULL");
        } catch (Exception ignored) {
            // Coluna já aceita nulo (ou o banco de teste já foi criado assim).
        }
    }
}

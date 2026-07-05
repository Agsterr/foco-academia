package br.com.focodev.academia.config;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;

@Configuration
@RequiredArgsConstructor
public class DatabaseSchemaFix {

    private final JdbcTemplate jdbcTemplate;

    @Bean
    @Order(0)
    CommandLineRunner fixUsersRoleConstraint() {
        return args -> {
            jdbcTemplate.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check");
            jdbcTemplate.execute("""
                    ALTER TABLE users ADD CONSTRAINT users_role_check
                    CHECK (role IN ('ADMIN', 'INSTRUTOR', 'ALUNO'))
                    """);
        };
    }
}

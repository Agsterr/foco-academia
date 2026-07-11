package br.com.focodev.academia;

import br.com.focodev.academia.config.AppReleaseProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AppReleaseProperties.class)
public class AcademiaApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(AcademiaApiApplication.class, args);
	}

}

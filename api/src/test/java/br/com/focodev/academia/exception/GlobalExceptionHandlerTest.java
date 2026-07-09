package br.com.focodev.academia.exception;

import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void handleApiException() {
        ResponseEntity<Map<String, String>> response =
                handler.handleApiException(new ApiException("Falha"));

        assertEquals(400, response.getStatusCode().value());
        assertEquals("Falha", response.getBody().get("message"));
    }

    @Test
    void handleValidation() {
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Object(), "target");
        bindingResult.addError(new FieldError("target", "name", "obrigatório"));

        MethodArgumentNotValidException ex = new MethodArgumentNotValidException(null, bindingResult);

        ResponseEntity<Map<String, String>> response = handler.handleValidation(ex);

        assertEquals(400, response.getStatusCode().value());
        assertEquals("obrigatório", response.getBody().get("name"));
    }

    @Test
    void handleBadCredentials() {
        ResponseEntity<Map<String, String>> response =
                handler.handleBadCredentials(new BadCredentialsException("bad"));

        assertEquals(401, response.getStatusCode().value());
        assertEquals("E-mail ou senha inválidos", response.getBody().get("message"));
    }

    @Test
    void handleAuthentication() {
        ResponseEntity<Map<String, String>> response =
                handler.handleAuthentication(new DisabledException("disabled"));

        assertEquals(401, response.getStatusCode().value());
        assertEquals("E-mail ou senha inválidos", response.getBody().get("message"));
    }

    @Test
    void handleGeneric() {
        ResponseEntity<Map<String, String>> response = handler.handleGeneric(new RuntimeException("boom"));
        assertEquals(500, response.getStatusCode().value());
        assertEquals("Erro interno do servidor", response.getBody().get("message"));
    }

    @Test
    void apiExceptionMessage() {
        assertEquals("teste", new ApiException("teste").getMessage());
    }
}

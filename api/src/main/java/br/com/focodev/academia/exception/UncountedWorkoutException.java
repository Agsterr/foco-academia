package br.com.focodev.academia.exception;

/**
 * Treino iniciado sem deslocamento/séries suficientes — a sessão é apagada
 * e a transação deve confirmar o delete (não reverter).
 */
public class UncountedWorkoutException extends ApiException {

    public UncountedWorkoutException(String message) {
        super(message);
    }
}

package com.iceibank.agencia;

import com.iceibank.agencia.service.OperacoesContaService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> validacao(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(err -> err.getField() + ": " + err.getDefaultMessage())
                .orElse("Requisição inválida.");
        return ResponseEntity.badRequest().body(Map.of("erro", msg));
    }

    @ExceptionHandler(OperacoesContaService.ConflitoSincronizacaoException.class)
    public ResponseEntity<Map<String, Object>> conflito(OperacoesContaService.ConflitoSincronizacaoException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ex.getCorpo());
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> status(ResponseStatusException ex) {
        return ResponseEntity.status(ex.getStatusCode())
                .body(Map.of("erro", ex.getReason() != null ? ex.getReason() : ex.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> generico(Exception ex) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("erro", ex.getMessage() != null ? ex.getMessage() : "Erro interno."));
    }
}

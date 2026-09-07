package com.iceibank.agencia.controller;

import com.iceibank.agencia.clock.RelogioLamport;
import com.iceibank.agencia.dto.LoginRequest;
import com.iceibank.agencia.model.Conta;
import com.iceibank.agencia.security.JwtService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
public class AuthController {

    private final JwtService jwtService;
    private final String username;
    private final String password;
    private final int idAgencia;
    private final RelogioLamport relogio;
    private final ConcurrentHashMap<Integer, Conta> contas;

    public AuthController(
            JwtService jwtService,
            @Value("${iceibank.auth.username}") String username,
            @Value("${iceibank.auth.password}") String password,
            int idAgencia,
            RelogioLamport relogio,
            ConcurrentHashMap<Integer, Conta> contas
    ) {
        this.jwtService = jwtService;
        this.username = username;
        this.password = password;
        this.idAgencia = idAgencia;
        this.relogio = relogio;
        this.contas = contas;
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest body) {
        if (!username.equals(body.getUsername()) || !password.equals(body.getPassword())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "erro", "Credenciais inválidas."
            ));
        }
        String token = jwtService.gerarToken(body.getUsername());
        return ResponseEntity.ok(Map.of(
                "token", token,
                "expiresInMs", jwtService.getExpirationMs()
        ));
    }

    /** Útil para evidências e diagnóstico — público. */
    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
                "agencia", idAgencia,
                "lamport", relogio.getContador(),
                "contas", contas.size(),
                "status", "UP"
        );
    }
}

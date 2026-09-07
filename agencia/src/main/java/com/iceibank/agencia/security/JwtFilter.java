package com.iceibank.agencia.security;

import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final String internalToken;

    public JwtFilter(JwtService jwtService, @Value("${iceibank.internal-token}") String internalToken) {
        this.jwtService = jwtService;
        this.internalToken = internalToken;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String path = request.getRequestURI();
        String method = request.getMethod();

        if ("OPTIONS".equalsIgnoreCase(method)
                || path.equals("/auth/login")
                || path.equals("/health")) {
            filterChain.doFilter(request, response);
            return;
        }

        // Chamada interna entre agências
        if (path.matches("/contas/\\d+/creditar-remoto") && "POST".equalsIgnoreCase(method)) {
            String interno = request.getHeader("X-Internal-Token");
            if (internalToken.equals(interno)) {
                var auth = new UsernamePasswordAuthenticationToken(
                        "agencia-interna",
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_INTERNAL"))
                );
                SecurityContextHolder.getContext().setAuthentication(auth);
                filterChain.doFilter(request, response);
                return;
            }
            unauthorized(response, "Token interno inválido ou ausente.");
            return;
        }

        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            unauthorized(response, "Token JWT ausente. Use Authorization: Bearer <token>.");
            return;
        }

        String token = header.substring(7);
        try {
            var claims = jwtService.validarEExtrair(token);
            var auth = new UsernamePasswordAuthenticationToken(
                    claims.getSubject(),
                    null,
                    List.of(new SimpleGrantedAuthority("ROLE_USER"))
            );
            SecurityContextHolder.getContext().setAuthentication(auth);
            filterChain.doFilter(request, response);
        } catch (JwtException | IllegalArgumentException e) {
            unauthorized(response, "Token JWT inválido ou expirado.");
        }
    }

    private void unauthorized(HttpServletResponse response, String mensagem) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write("{\"erro\":\"" + mensagem.replace("\"", "'") + "\"}");
    }
}

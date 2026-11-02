package com.techchallenger.oficina360.frameworks.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import static com.techchallenger.oficina360.constants.Roles.*;

@Configuration
@RequiredArgsConstructor
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;


    @Bean
    @SuppressWarnings("java:S4502")
    public SecurityFilterChain securityFilterChain(HttpSecurity http) {
        return http
                .csrf(csrf -> csrf.disable()) // API stateless autenticada por JWT
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .authorizeHttpRequests(auth -> auth

                        // PUBLIC
                        .requestMatchers(
                                "/actuator/health",
                                "/actuator/health/**",
                                "/actuator/prometheus"
                        ).permitAll()
                        .requestMatchers("/auth/login").permitAll()
                        .requestMatchers(
                                "/swagger-ui/**",
                                "/swagger-ui.html",
                                "/v3/api-docs/**"
                        ).permitAll()

                        // CLIENTE (restrito e específico)
                        .requestMatchers(HttpMethod.GET, "/ordens-servico/cliente/**")
                        .hasRole(CLIENTE)

                        .requestMatchers(HttpMethod.PATCH, "/ordens-servico/cliente/*/aprovacao")
                        .hasRole(CLIENTE)

                        .requestMatchers(HttpMethod.GET, "/clientes/me")
                        .hasRole(CLIENTE)

                        .requestMatchers(HttpMethod.GET, "/veiculos/me")
                        .hasRole(CLIENTE)

                        // INTERNO
                        .requestMatchers(HttpMethod.GET, "/ordens-servico/**")
                        .hasAnyRole(ADMIN, ATENDENTE, MECANICO)

                        .requestMatchers(HttpMethod.POST, "/ordens-servico/**")
                        .hasAnyRole(ADMIN, ATENDENTE)

                        .requestMatchers(HttpMethod.PATCH, "/ordens-servico/*/diagnostico")
                        .hasAnyRole(ADMIN, MECANICO)

                        .requestMatchers(HttpMethod.PATCH, "/ordens-servico/*/execucao/**")
                        .hasAnyRole(ADMIN, MECANICO)

                        .requestMatchers(HttpMethod.PATCH, "/ordens-servico/*/entrega")
                        .hasAnyRole(ADMIN, ATENDENTE)

                        // fallback
                        .anyRequest().authenticated()
                )
                .addFilterBefore(
                        jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class
                )
                .build();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) {
        return configuration.getAuthenticationManager();
    }


    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

}
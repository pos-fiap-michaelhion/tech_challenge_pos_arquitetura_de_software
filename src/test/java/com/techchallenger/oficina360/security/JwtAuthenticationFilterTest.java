package com.techchallenger.oficina360.security;

import com.techchallenger.oficina360.dominio.Usuario;
import com.techchallenger.oficina360.frameworks.security.JwtAuthenticationFilter;
import com.techchallenger.oficina360.gateways.TokenGateway;
import com.techchallenger.oficina360.gateways.UsuarioGateway;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class JwtAuthenticationFilterTest {

    private static final String DOCUMENTO = "27631184020";
    private static final String EMAIL = "admin@oficina360.com";
    private static final String SENHA_CRIPTOGRAFADA = "senha-criptografada";
    private static final String ROLE = "ADMIN";
    @Mock
    private TokenGateway tokenGateway;

    @Mock
    private UsuarioGateway usuarioGateway;

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    private AutoCloseable closeable;

    @InjectMocks
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    private Usuario usuario;

    @BeforeEach
    void setUp() {
        closeable = MockitoAnnotations.openMocks(this);

        usuario = new Usuario(
                UUID.randomUUID(),
                EMAIL,
                SENHA_CRIPTOGRAFADA,
                ROLE,
                DOCUMENTO
                );

        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void tearDown() throws Exception {
        SecurityContextHolder.clearContext();
        closeable.close();
    }

    @Test
    void deveContinuarFiltroQuandoNaoExistirHeaderAuthorization() throws Exception {
        when(request.getHeader("Authorization"))
                .thenReturn(null);

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());

        verify(tokenGateway, never()).validarTokenEObterSubject(anyString());
        verify(usuarioGateway, never()).findByEmail(anyString());
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void deveContinuarFiltroQuandoHeaderAuthorizationNaoForBearer() throws Exception {
        when(request.getHeader("Authorization"))
                .thenReturn("Basic abc123");

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());

        verify(tokenGateway, never()).validarTokenEObterSubject(anyString());
        verify(usuarioGateway, never()).findByEmail(anyString());
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void deveAutenticarUsuarioQuandoTokenForValido() throws Exception {
        when(request.getHeader("Authorization"))
                .thenReturn("Bearer token-valido");

        when(tokenGateway.validarTokenEObterSubject("token-valido"))
                .thenReturn(DOCUMENTO);

        when(usuarioGateway.findByDocumento(DOCUMENTO))
                .thenReturn(Optional.of(usuario));

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals(
                EMAIL,
                SecurityContextHolder.getContext().getAuthentication().getName()
        );

        verify(tokenGateway, times(1))
                .validarTokenEObterSubject("token-valido");

        verify(usuarioGateway, times(1))
                .findByDocumento(DOCUMENTO);

        verify(filterChain, times(1))
                .doFilter(request, response);
    }

    @Test
    void deveContinuarFiltroQuandoTokenValidoMasUsuarioNaoEncontrado() throws Exception {
        when(request.getHeader("Authorization"))
                .thenReturn("Bearer token-valido");

        when(tokenGateway.validarTokenEObterSubject("token-valido"))
                .thenReturn(DOCUMENTO);

        when(usuarioGateway.findByDocumento(DOCUMENTO))
                .thenReturn(Optional.empty());

        jwtAuthenticationFilter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());

        verify(tokenGateway, times(1))
                .validarTokenEObterSubject("token-valido");

        verify(usuarioGateway, times(1))
                .findByDocumento(DOCUMENTO);

        verify(filterChain, times(1))
                .doFilter(request, response);
    }
}
package com.techchallenger.oficina360.frameworks.security;

import com.techchallenger.oficina360.gateways.TokenGateway;
import com.techchallenger.oficina360.gateways.UsuarioGateway;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private final TokenGateway tokenGateway;
	private final UsuarioGateway usuarioGateway;

	@Override
	public void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {

		String token = recuperarToken(request);

		if (token != null) {

			String documento = tokenGateway.validarTokenEObterSubject(token);

			usuarioGateway.findByDocumento(documento).ifPresent(usuario -> {

				UsuarioSecurityDetails principal = new UsuarioSecurityDetails(usuario);

				UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(principal,
						null, principal.getAuthorities());

				SecurityContextHolder.getContext().setAuthentication(authentication);

			});
		}

		filterChain.doFilter(request, response);
	}

	private String recuperarToken(HttpServletRequest request) {

		String authorizationHeader = request.getHeader("Authorization");

		if (authorizationHeader == null || authorizationHeader.isBlank()) {
			return null;
		}

		if (!authorizationHeader.startsWith("Bearer ")) {
			return null;
		}

		return authorizationHeader.replace("Bearer ", "").trim();
	}
}
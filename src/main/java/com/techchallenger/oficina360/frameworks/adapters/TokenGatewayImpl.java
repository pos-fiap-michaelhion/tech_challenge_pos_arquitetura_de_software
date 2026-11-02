package com.techchallenger.oficina360.frameworks.adapters;

import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.techchallenger.oficina360.dominio.Usuario;
import com.techchallenger.oficina360.gateways.TokenGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.ZoneOffset;

@Component
@RequiredArgsConstructor
public class TokenGatewayImpl implements TokenGateway {

	@Value("${api.security.jwt.secret}")
	private String secret;

	@Value("${api.security.jwt.issuer:oficina360-api}")
	private String issuer;

	@Value("${api.security.jwt.expiration-hours:2}")
	private Long expirationHours;

	private final RelogioSistema relogioSistema;

	@Override
	public String gerarToken(Usuario usuario) {
		Algorithm algorithm = Algorithm.HMAC256(secret);

		return JWT.create()
				.withIssuer(issuer)
				.withSubject(usuario.getDocumento())
				.withClaim("role", usuario.getRole())
				.withExpiresAt(dataExpiracao())
				.sign(algorithm);
	}

	@Override
	public String validarTokenEObterSubject(String token) {
		Algorithm algorithm = Algorithm.HMAC256(secret);

		return JWT.require(algorithm)
				.withIssuer(issuer)
				.build()
				.verify(token)
				.getSubject();
	}

	private Instant dataExpiracao() {
		return relogioSistema.agora()
				.plusHours(expirationHours)
				.toInstant(ZoneOffset.of("-03:00"));
	}
}

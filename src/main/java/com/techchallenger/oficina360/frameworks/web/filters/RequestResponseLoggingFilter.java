package com.techchallenger.oficina360.frameworks.web.filters;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static net.logstash.logback.argument.StructuredArguments.kv;

@Component
public class RequestResponseLoggingFilter extends OncePerRequestFilter {

	private static final Logger log = LoggerFactory.getLogger(RequestResponseLoggingFilter.class);

	private static final int MAX_PAYLOAD_LENGTH = 1_000;
	private static final int REQUEST_CACHE_LIMIT = 10_000;

	private static final String EMPTY_PAYLOAD = "[empty]";
	private static final String ANONYMOUS_USER = "anonymous";

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		return request.getRequestURI().startsWith("/actuator");
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {

		String requestId = resolveRequestId(request);

		ContentCachingRequestWrapper requestWrapper = new ContentCachingRequestWrapper(request, REQUEST_CACHE_LIMIT);

		ContentCachingResponseWrapper responseWrapper = new ContentCachingResponseWrapper(response);

		long startTime = System.currentTimeMillis();

		MDC.put("requestId", requestId);

		try {
			filterChain.doFilter(requestWrapper, responseWrapper);
		} finally {
			long durationMs = System.currentTimeMillis() - startTime;

			try {
				logRequest(requestWrapper);
				logResponse(responseWrapper, durationMs);
			} catch (RuntimeException exception) {
				/*
				 * Uma falha no logging não deve impedir o retorno da
				 * resposta original ao cliente.
				 */
				log.warn("Não foi possível registrar os dados da requisição HTTP", exception);
			} finally {
				/*
				 * ContentCachingResponseWrapper mantém o corpo em cache.
				 * Sem esta chamada, o cliente pode receber uma resposta vazia.
				 */
				responseWrapper.copyBodyToResponse();

				/*
				 * Remove somente o campo criado por este filtro.
				 * MDC.clear() poderia apagar traceId, spanId ou outros
				 * campos adicionados por Micrometer/OpenTelemetry.
				 */
				MDC.remove("requestId");
			}
		}
	}

	private void logRequest(ContentCachingRequestWrapper request) {

		if (!log.isInfoEnabled()) {
			return;
		}

		String payload = sanitizePayload(getBody(request.getContentAsByteArray()));

		log.info("HTTP request received {} {} {} {} {} {} {}", kv("event", "http_request"),
				kv("httpMethod", request.getMethod()), kv("httpUri", request.getRequestURI()),
				kv("queryString", getQueryString(request)), kv("user", getUsuarioLogado()),
				kv("clientIp", getClientIp(request)), kv("requestPayload", payload));
	}

	private void logResponse(ContentCachingResponseWrapper response, long durationMs) {

		if (!log.isInfoEnabled()) {
			return;
		}

		String payload = sanitizePayload(getBody(response.getContentAsByteArray()));

		int status = response.getStatus();

		if (status >= HttpServletResponse.SC_INTERNAL_SERVER_ERROR) {
			log.error("HTTP response completed {} {} {} {}", kv("event", "http_response"), kv("httpStatus", status),
					kv("durationMs", durationMs), kv("responsePayload", payload));
			return;
		}

		if (status >= HttpServletResponse.SC_BAD_REQUEST) {
			log.warn("HTTP response completed {} {} {} {}", kv("event", "http_response"), kv("httpStatus", status),
					kv("durationMs", durationMs), kv("responsePayload", payload));
			return;
		}

		log.info("HTTP response completed {} {} {} {}", kv("event", "http_response"), kv("httpStatus", status),
				kv("durationMs", durationMs), kv("responsePayload", payload));
	}

	private String getBody(byte[] content) {

		if (content == null || content.length == 0) {
			return EMPTY_PAYLOAD;
		}

		String body = new String(content, StandardCharsets.UTF_8);

		if (body.length() > MAX_PAYLOAD_LENGTH) {
			return body.substring(0, MAX_PAYLOAD_LENGTH) + "...[truncated]";
		}

		return body;
	}

	private String sanitizePayload(String body) {

		if (body == null || body.isBlank()) {
			return body;
		}

		String sanitized = body;

		sanitized = sanitized.replaceAll("\\b\\d{11}\\b", "***CPF***");

		sanitized = sanitized.replaceAll("\\b\\d{14}\\b", "***CNPJ***");

		sanitized = sanitized.replaceAll("(?i)\"senha\"\\s*:\\s*\"[^\"]*\"", "\"senha\":\"***\"");

		sanitized = sanitized.replaceAll("(?i)\"password\"\\s*:\\s*\"[^\"]*\"", "\"password\":\"***\"");

		sanitized = sanitized.replaceAll("(?i)\"token\"\\s*:\\s*\"[^\"]*\"", "\"token\":\"***\"");

		sanitized = sanitized.replaceAll("(?i)\"access_token\"\\s*:\\s*\"[^\"]*\"", "\"access_token\":\"***\"");

		sanitized = sanitized.replaceAll("(?i)\"refresh_token\"\\s*:\\s*\"[^\"]*\"", "\"refresh_token\":\"***\"");

		sanitized = sanitized.replaceAll("\\b[A-Z]{3}\\d[A-Z0-9]\\d{2}\\b", "***PLACA***");

		return sanitized;
	}

	private String getUsuarioLogado() {

		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

		if (authentication == null || !authentication.isAuthenticated() || authentication.getName() == null
				|| authentication.getName().isBlank() || "anonymousUser".equals(authentication.getName())) {

			return ANONYMOUS_USER;
		}

		return authentication.getName();
	}

	private String getQueryString(HttpServletRequest request) {

		String queryString = request.getQueryString();

		if (queryString == null || queryString.isBlank()) {
			return "";
		}

		return queryString;
	}

	private String getClientIp(HttpServletRequest request) {

		String forwardedFor = request.getHeader("X-Forwarded-For");

		if (forwardedFor != null && !forwardedFor.isBlank()) {
			/*
			 * X-Forwarded-For pode conter vários IPs:
			 * cliente, proxy1, proxy2.
			 */
			return forwardedFor.split(",")[0].trim();
		}

		String realIp = request.getHeader("X-Real-IP");

		if (realIp != null && !realIp.isBlank()) {
			return realIp.trim();
		}

		return request.getRemoteAddr();
	}

	private String resolveRequestId(HttpServletRequest request) {

		String receivedRequestId = request.getHeader("X-Request-Id");

		if (receivedRequestId != null && !receivedRequestId.isBlank()) {

			return sanitizeRequestId(receivedRequestId);
		}

		return UUID.randomUUID().toString();
	}

	private String sanitizeRequestId(String requestId) {

		String sanitized = requestId.replaceAll("[^a-zA-Z0-9._-]", "");

		if (sanitized.isBlank()) {
			return UUID.randomUUID().toString();
		}

		int maximumLength = 100;

		if (sanitized.length() > maximumLength) {
			return sanitized.substring(0, maximumLength);
		}

		return sanitized;
	}
}
package com.techchallenger.oficina360.it.ordemservicos;

import com.auth0.jwt.JWT;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.jayway.jsonpath.JsonPath;
import com.techchallenger.oficina360.dominio.Estoque;
import com.techchallenger.oficina360.frameworks.dtos.ordemservico.AprovacaoOrdemServicoDTO;
import com.techchallenger.oficina360.gateways.EstoqueGateway;
import com.techchallenger.oficina360.gateways.NotificacaoEmailGateway;
import com.techchallenger.oficina360.it.BaseIT;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;

import java.util.UUID;

import static com.techchallenger.oficina360.it.fixtures.ordemservico.OrderServiceFixture.*;
import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles(value = "test")
public class OrdemServicoAprovacaoIT extends BaseIT {

	private static final String OS_COM_STATUS_AGUARDANDO_APROVACAO = "cc702d41-3acf-464f-ad33-f9ec8c01f57d";

	@Autowired
	private EstoqueGateway estoqueGateway;

	@MockitoBean
	private NotificacaoEmailGateway notificacaoEmailGateway;

	@Test
	void deveAprovarOrcamento() throws Exception {
		aprovar(OS_COM_STATUS_AGUARDANDO_APROVACAO, aprovacaoOrdemServicoDTOValido(), tokenCliente()).andExpect(
				status().isAccepted()).andDo(print());

	}

	@Test
	void naoDeveAprovarOrcamentoDeOutroCliente() throws Exception {

		aprovar(OS_COM_STATUS_AGUARDANDO_APROVACAO, aprovacaoOrdemServicoDTOValido(), tokenCliente1()).andExpect(
				status().isForbidden()).andDo(print());
	}

	@Test
	void deveLiberarReservaQuandoOrcamentoForReprovado() throws Exception {

		String response = mockMvc.perform(autenticado(
						post("/ordem-servico/salvar").contentType(MediaType.APPLICATION_JSON)
								.content(json(ordemServicoValida())), tokenAdmin())).andReturn().getResponse()
				.getContentAsString();

		UUID id = UUID.fromString(JsonPath.read(response, "$.id"));
		mockMvc.perform(autenticado(patch("/ordem-servico/{id}/diagnostico", id),
						tokenAdmin()).contentType(MediaType.APPLICATION_JSON).content(json(diagnosticoDTOValido())))
				.andExpect(status().isOk());

		Estoque estoqueAntes = estoqueGateway.findByCodigo("PNEU-205-55-R16").orElseThrow();

		assertEquals(5, estoqueAntes.getReservados());

		AprovacaoOrdemServicoDTO aprovacaoOrdemServicoDTO = new AprovacaoOrdemServicoDTO(false, "Não quero executar");

		aprovar(id.toString(), aprovacaoOrdemServicoDTO, tokenCliente2())
				.andExpect(status().isAccepted()).andDo(print());

		Estoque estoqueDepois = estoqueGateway.findByCodigo("PNEU-205-55-R16").orElseThrow();
		//todo o valor esta como 1 por sujeira na massa de dados
		assertAll(() -> assertEquals(1, estoqueDepois.getReservados()),
				() -> assertEquals(estoqueAntes.getQuantidade(), estoqueDepois.getQuantidade()));
	}

	private ResultActions aprovar(String id, AprovacaoOrdemServicoDTO aprovacaoOrdemServicoDTO, String token)
			throws Exception {
		return mockMvc.perform(autenticado(patch(("/ordem-servico/clientes/aprovacao/%s").formatted(
				id)), token)
				.contentType(MediaType.APPLICATION_JSON)
				.content(objectMapper.writeValueAsString(aprovacaoOrdemServicoDTO)));
	}

	@Test
	void deveGerarTokenDoClienteComDocumentoNoSubject() {
		String token = tokenCliente();

		DecodedJWT jwt = JWT.decode(token);

		assertAll(
				() -> assertEquals(
						"12345678901",
						jwt.getSubject()
				),
				() -> assertEquals(
						"CLIENTE",
						jwt.getClaim("role").asString()
				)
		);
	}
}

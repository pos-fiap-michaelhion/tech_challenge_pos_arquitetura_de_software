package com.techchallenger.oficina360.it.ordemservicos;

import com.techchallenger.oficina360.frameworks.adapters.RelogioSistema;
import com.techchallenger.oficina360.gateways.OrdemServicoGateway;
import com.techchallenger.oficina360.gateways.UsuarioGateway;
import com.techchallenger.oficina360.it.BaseIT;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles(value = "test")
class OrdemServicoListarIT extends BaseIT {

	private static final String ORDEM_SERVICO_BASE_PATH = "/ordem-servico";
	private static final String SENHA = "$2a$10$ATQgy75GIzx6MsDKQmijxOWrBb5oP7hu/1HBQa1slZfIVQ/fasI7e";
	public static final String DOCUMENTO_CLIENTE = "99999999998";

	@Autowired
	private UsuarioGateway usuarioGateway;

	@Autowired
	private OrdemServicoGateway ordemServicoGateway;

	@Autowired
	private RelogioSistema relogioSistema;


	@Test
	void deveListarOrdemServico() throws Exception {

		mockMvc.perform(autenticado(get(ORDEM_SERVICO_BASE_PATH + "/listar"), tokenAdmin())).andExpect(status().isOk())
				.andExpect(jsonPath("$.content").isArray()).andDo(print())
				.andExpect(jsonPath("$.content.length()").value(8))
				.andExpect(jsonPath("$.pageable.pageNumber").value(0))
				.andExpect(jsonPath("$.totalElements").value(8));

	}

}
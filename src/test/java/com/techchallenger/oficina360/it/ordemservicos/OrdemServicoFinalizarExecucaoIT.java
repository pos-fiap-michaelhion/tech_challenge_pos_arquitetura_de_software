package com.techchallenger.oficina360.it.ordemservicos;

import com.techchallenger.oficina360.gateways.NotificacaoEmailGateway;
import com.techchallenger.oficina360.it.BaseIT;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@ActiveProfiles(value = "test")
public class OrdemServicoFinalizarExecucaoIT extends BaseIT {

	private static final String OS_COM_STATUS_RECEBIDA = "76dba7d9-2ded-426f-aae8-fd8f8506a7cc";
	private static final String OS_COM_STATUS_EM_EXECUCAO = "4baecc4b-57d2-419b-b080-ae6615a44052";

	@MockitoBean
	private NotificacaoEmailGateway notificacaoEmailGateway;

	@Test
	void deveFinalizarExecucao() throws Exception {

		finalizar(OS_COM_STATUS_EM_EXECUCAO,tokenAdmin()).andExpect(status().isAccepted()).andDo(print());
	}

	@Test
	void clienteNaodeveFinalizarExecucao() throws Exception {
		finalizar(OS_COM_STATUS_EM_EXECUCAO,tokenCliente1()).andExpect(status().isForbidden()).andDo(print());
	}

	@Test
	void naoDeveFinalizarOrdemNaoIniciada() throws Exception {
			finalizar(OS_COM_STATUS_RECEBIDA,tokenAdmin()).andExpect(status().isConflict()).andDo(print());
	}

	@Autowired
	JdbcTemplate jdbcTemplate;

	@Test
	void debugBanco() {
		Integer total = jdbcTemplate.queryForObject(
				"""
				SELECT COUNT(*)
				FROM INFORMATION_SCHEMA.TABLES
				WHERE TABLE_NAME='USUARIO'
				""",
				Integer.class
		);
		System.out.println("=============================================================");
		System.out.println(total);
		System.out.println("=============================================================");
	}


	private ResultActions finalizar(String id,String token) throws Exception {
		return mockMvc.perform(autenticado(
				patch("/ordem-servico/execucao/finalizar/%s".formatted(id)), token));
	}
}

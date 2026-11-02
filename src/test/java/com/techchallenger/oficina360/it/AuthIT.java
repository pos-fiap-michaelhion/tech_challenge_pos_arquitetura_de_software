package com.techchallenger.oficina360.it;

import com.techchallenger.oficina360.constants.Roles;
import com.techchallenger.oficina360.dominio.Usuario;
import com.techchallenger.oficina360.frameworks.dtos.autenticacao.LoginRequestDTO;
import com.techchallenger.oficina360.gateways.PasswordEncoderGateway;
import com.techchallenger.oficina360.gateways.UsuarioGateway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles(value = "test")
class AuthIT {

	private static final String EMAIL = "admin1@oficina360.com";
	private static final String PASSWORD = "123456";
	public static final String CPF = "25231015000191";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private UsuarioGateway usuarioGateway;

	@Autowired
	private PasswordEncoderGateway passwordEncoderGateway;

	@Autowired
	private ObjectMapper objectMapper;

	@BeforeEach
	void setup() {

		usuarioGateway.excluirTodos();

		Usuario usuario = new Usuario(null, EMAIL, passwordEncoderGateway.criptografar(PASSWORD), Roles.ADMIN, CPF);

		usuarioGateway.save(usuario);
	}

	@Test
	void deveAutenticarUsuarioEConsultarRecursoProtegido() throws Exception {

		LoginRequestDTO login = new LoginRequestDTO(EMAIL, PASSWORD);

		String response = mockMvc.perform(post("/auth/login")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(login)))
						.andExpect(status().isOk())
						.andReturn().getResponse()
				.getContentAsString();

		JsonNode json = objectMapper.readTree(response);

		String token = json.get("token").asString();

		mockMvc.perform(get("/clientes/listar")
				.header("Authorization", "Bearer " + token))
				.andExpect(status().isOk());

	}

	@Test
	void deveCriarUsuarioAutenticarEConsultarRecursoProtegido() throws Exception {
		LoginRequestDTO login = new LoginRequestDTO(EMAIL, PASSWORD);

		String response = mockMvc.perform(post("/auth/login")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(login)))
				.andExpect(status().isOk())
				.andReturn().getResponse()
				.getContentAsString();

		JsonNode json = objectMapper.readTree(response);

		String token = json.get("token").asString();

		mockMvc.perform(
				post("/clientes/salvar")
						.header("Authorization", "Bearer " + token)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
                        {
                          "nome":"João Silva",
                          "documento":"03255014085",
                          "telefone":"11999999999",
                          "email":"joao@email.com"
                        }
                        """)
		).andExpect(status().isCreated());

		mockMvc.perform(
				post("/auth/criar-usuario")
						.header("Authorization", "Bearer " + token)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
                        {
                          "email":"cliente@teste.com",
                          "senha":"123456",
                          "role":"CLIENTE",
                          "documento":"03255014085"
                        }
                        """)
		).andExpect(status().isOk());

		LoginRequestDTO login1 = new LoginRequestDTO(
				"cliente@teste.com",
				"123456"
		);

		String response1 =
				mockMvc.perform(
								post("/auth/login")
										.contentType(MediaType.APPLICATION_JSON)
										.content(objectMapper.writeValueAsString(login1))
						)
						.andExpect(status().isOk())
						.andReturn()
						.getResponse()
						.getContentAsString();

		String token1 =
				objectMapper.readTree(response1)
						.get("token").asString();

		mockMvc.perform(
						get("/clientes/listar")
								.header("Authorization", "Bearer " + token1)
				)
				.andExpect(status().isOk());
	}
}

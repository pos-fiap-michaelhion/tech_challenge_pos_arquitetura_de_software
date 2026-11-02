package com.techchallenger.oficina360.it.fixtures.ordemservico;

import com.techchallenger.oficina360.dominio.Usuario;
import com.techchallenger.oficina360.frameworks.dtos.ordemservico.AprovacaoOrdemServicoDTO;
import com.techchallenger.oficina360.frameworks.dtos.ordemservico.CriarOrdemServicoRequestDTO;
import com.techchallenger.oficina360.frameworks.dtos.ordemservico.diagnostico.DiagnosticoDTO;
import com.techchallenger.oficina360.frameworks.dtos.ordemservico.diagnostico.DiagnosticoEstoqueDTO;

import java.util.List;
import java.util.UUID;

import static com.techchallenger.oficina360.constants.Roles.ADMIN;
import static com.techchallenger.oficina360.constants.Roles.CLIENTE;

public final class OrderServiceFixture {

	public static final UUID ADMIN_ID = UUID.fromString("99999999-9999-9999-9999-999999999999");

	public static final String ADMIN_EMAIL = "admin@oficina360.com";

	public static final String ADMIN_DOCUMENTO = "25231015000191";

	/*
	 * Cliente proprietário das ordens fixas.
	 *
	 * As ordens presentes na massa de testes possuem:
	 * DOCUMENTO_CLIENTE = 12345678901
	 */
	public static final UUID CLIENTE_ID = UUID.fromString("99999999-9999-9999-9999-999999999998");

	public static final String CLIENTE_EMAIL = "cliente@oficina360.com";

	public static final String CLIENTE_DOCUMENTO = "12345678901";

	/*
	 * Cliente que não é proprietário das ordens fixas.
	 */
	public static final UUID CLIENTE_1_ID = UUID.fromString("99999999-9999-9999-9999-999999999977");

	public static final String CLIENTE_1_EMAIL = "cliente1@oficina360.com";

	public static final String CLIENTE_1_DOCUMENTO = "12345678801";

	/*
	 * Cliente utilizado na criação dinâmica de ordens.
	 */
	public static final UUID CLIENTE_2_ID = UUID.fromString("99999999-9999-9999-9999-999999998877");

	public static final String CLIENTE_2_EMAIL = "cliente2@oficina360.com";

	public static final String CLIENTE_2_DOCUMENTO = "98765432100";

	private static final String SENHA_TESTE = "123456";

	private static final String PLACA_CLIENTE = "DEF2G34";

	private static final String PLACA_OUTRO_CLIENTE = "GHI3J45";

	private static final String DESCRICAO_PROBLEMA = "Barulho no motor";

	private static final String DESCRICAO_PROBLEMA_ATUALIZADA = "Problema atualizado";

	private static final String CODIGO_SERVICO_BALANCEAMENTO = "BALANCEAMENTO";

	private static final String CODIGO_SERVICO_INEXISTENTE = "SERVICO-INEXISTENTE";

	private static final String CODIGO_ESTOQUE_PNEU = "PNEU-205-55-R16";

	private static final String CODIGO_ESTOQUE_INEXISTENTE = "ITEM-INEXISTENTE";

	private OrderServiceFixture() {
	}

	public static CriarOrdemServicoRequestDTO ordemServicoValida() {
		return new CriarOrdemServicoRequestDTO(CLIENTE_2_DOCUMENTO, PLACA_CLIENTE, DESCRICAO_PROBLEMA);
	}

	public static CriarOrdemServicoRequestDTO ordemServicoPlacaDeOutroCliente() {
		return new CriarOrdemServicoRequestDTO(CLIENTE_2_DOCUMENTO, PLACA_OUTRO_CLIENTE, DESCRICAO_PROBLEMA);
	}

	public static CriarOrdemServicoRequestDTO ordemServicoEditada() {
		return new CriarOrdemServicoRequestDTO(CLIENTE_2_DOCUMENTO, PLACA_CLIENTE, DESCRICAO_PROBLEMA_ATUALIZADA);
	}

	public static Usuario gerarUsuarioAdmin() {
		return criarUsuario(ADMIN_ID, ADMIN_EMAIL, ADMIN, ADMIN_DOCUMENTO);
	}

	public static Usuario gerarUsuarioCliente() {
		return criarUsuario(CLIENTE_ID, CLIENTE_EMAIL, CLIENTE, CLIENTE_DOCUMENTO);
	}

	public static Usuario gerarUsuarioCliente1() {
		return criarUsuario(CLIENTE_1_ID, CLIENTE_1_EMAIL, CLIENTE, CLIENTE_1_DOCUMENTO);
	}

	public static Usuario gerarUsuarioCliente2() {
		return criarUsuario(CLIENTE_2_ID, CLIENTE_2_EMAIL, CLIENTE, CLIENTE_2_DOCUMENTO);
	}

	public static DiagnosticoDTO diagnosticoDTOValido() {
		return new DiagnosticoDTO(List.of(CODIGO_SERVICO_BALANCEAMENTO),
				List.of(new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_PNEU, 4)));
	}

	public static AprovacaoOrdemServicoDTO aprovacaoOrdemServicoDTOValido() {
		return new AprovacaoOrdemServicoDTO(true, null);
	}

	public static DiagnosticoDTO diagnosticoComServicoInexistente() {
		return new DiagnosticoDTO(List.of(CODIGO_SERVICO_INEXISTENTE),
				List.of(new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_PNEU, 4)));
	}

	public static DiagnosticoDTO diagnosticoComServicoValidoEInvalido() {
		return new DiagnosticoDTO(List.of(CODIGO_SERVICO_BALANCEAMENTO, CODIGO_SERVICO_INEXISTENTE),
				List.of(new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_PNEU, 4)));
	}

	public static DiagnosticoDTO diagnosticoComItemEstoqueInexistente() {
		return new DiagnosticoDTO(List.of(CODIGO_SERVICO_BALANCEAMENTO),
				List.of(new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_INEXISTENTE, 2)));
	}

	public static DiagnosticoDTO diagnosticoComEstoqueValidoEInvalido() {
		return new DiagnosticoDTO(List.of(CODIGO_SERVICO_BALANCEAMENTO),
				List.of(new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_PNEU, 1),
						new DiagnosticoEstoqueDTO(CODIGO_ESTOQUE_INEXISTENTE, 1)));
	}

	private static Usuario criarUsuario(UUID id, String email, String role, String documento) {
		return new Usuario(id, email, SENHA_TESTE, role, documento);
	}
}
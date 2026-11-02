package com.techchallenger.oficina360.frameworks.adapters;

import com.techchallenger.oficina360.dominio.Usuario;
import com.techchallenger.oficina360.frameworks.mappers.usuario.UsuarioDTOMapper;
import com.techchallenger.oficina360.frameworks.persistence.entities.UsuarioEntity;
import com.techchallenger.oficina360.frameworks.persistence.repositories.UsuarioRepository;
import com.techchallenger.oficina360.gateways.UsuarioGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static com.techchallenger.oficina360.frameworks.mappers.usuario.UsuarioDTOMapper.toDomain;
import static com.techchallenger.oficina360.frameworks.mappers.usuario.UsuarioDTOMapper.toEntity;

@Component
@RequiredArgsConstructor
public class UsuarioGatewayImpl implements UsuarioGateway {

	private final UsuarioRepository repository;

	@Override
	public Optional<Usuario> findByEmail(String email) {
		return repository
				.findByEmail(email)
				.map(UsuarioDTOMapper::toDomain);
	}

	@Override
	public Optional<Usuario> findByDocumento(String documento) {
		return repository
				.findByDocumento(documento)
				.map(UsuarioDTOMapper::toDomain);
	}

	@Override
	public boolean existsByEmail(String email) {
		return repository.existsByEmail(email);
	}

	@Override
	public Usuario save(Usuario usuario) {
		UsuarioEntity entity = toEntity(usuario);
		UsuarioEntity persisted = repository.save(entity);
		return toDomain(persisted);
	}

	@Override
	public List<Usuario> saveAll(List<Usuario> usuarios) {
		List<UsuarioEntity> usuarioEntityList = usuarios.stream().map(UsuarioDTOMapper::toEntity).toList();
		List<UsuarioEntity> usuarioEntitiesSaved = repository.saveAll(usuarioEntityList);
		return usuarioEntitiesSaved.stream().map(UsuarioDTOMapper::toDomain).toList();
	}

	@Override
	public List<Usuario> findAll() {
		return repository.findAll()
				.stream()
				.map(UsuarioDTOMapper::toDomain)
				.toList();
	}

	@Override
	public Optional<Usuario> findById(UUID id) {
		return repository.findById(id)
				.map(UsuarioDTOMapper::toDomain);
	}


	@Override
	public void excluirTodos() {
		repository.deleteAll();
	}
}

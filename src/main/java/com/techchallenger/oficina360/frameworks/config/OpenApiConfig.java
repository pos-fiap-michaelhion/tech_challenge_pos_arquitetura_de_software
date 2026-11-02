package com.techchallenger.oficina360.frameworks.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    @Bean
    public OpenAPI oficina360OpenAPI() {
        return new OpenAPI()
                .info(apiInfo())
                .externalDocs(externalDocumentation())
                .servers(List.of(
                        kongGatewayServer(),
                        localServer()
                ))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME_NAME,securityScheme()))
                .addSecurityItem(new SecurityRequirement().addList(SECURITY_SCHEME_NAME));
    }

    private Server kongGatewayServer() {
        return new Server()
                .url("/api")
                .description("Kong Gateway");
    }
    private Server localServer() {
        return new Server()
                .url("/")
                .description("Api local");
    }

    private Info apiInfo() {
        return new Info()
                .title("Oficina360 API")
                .description(
                        "API REST do sistema Oficina360, desenvolvido para o Tech Challenge. " +
                                "O sistema apoia a gestão de uma oficina mecânica, incluindo clientes, " +
                                "veículos, serviços, estoque de peças e insumos, reservas de estoque " +
                                "e ordens de serviço."
                )
                .version("1.0.0")
                .contact(new Contact()
                        .name("Equipe Oficina360")
                        .email("contato@oficina360.com"))
                .license(new License()
                        .name("Uso acadêmico - Tech Challenge"));
    }

    private ExternalDocumentation externalDocumentation() {
        return new ExternalDocumentation()
                .description("Documentação do projeto Oficina360")
                .url("https://github.com/seu-usuario/seu-repositorio");
    }

    private SecurityScheme securityScheme() {
        return new SecurityScheme()
                .name(SECURITY_SCHEME_NAME)
                .description(
                        "Autenticação via JWT usando o header " +
                                "Authorization: Bearer {token}."
                )
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("JWT");
    }
}
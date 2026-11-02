INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     '76dba7d9-2ded-426f-aae8-fd8f8506a7cc',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'RECEBIDA',
     0.00,
     0.00,
     0.00
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     'd1c835b7-270e-45e5-8352-05e27b565f24',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'EM_DIAGNOSTICO',
     0.00,
     0.00,
     0.00
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     'cc702d41-3acf-464f-ad33-f9ec8c01f57d',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'AGUARDANDO_APROVACAO',
     0.00,
     0.00,
     0.00
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     '2b3a19fd-d3c0-4d9f-9738-6fec31269023',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'ORCAMENTO_APROVADO',
     0.00,
     0.00,
     0.00
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     '0b49c552-8ba0-4c0b-bcec-42db82526af9',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'ORCAMENTO_REPROVADO',
     0.00,
     0.00,
     0.00
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS,
    DT_HORA_INICIO_EXECUCAO

) VALUES (
     '4baecc4b-57d2-419b-b080-ae6615a44052',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'EM_EXECUCAO',
     0.00,
     0.00,
     0.00,
     CURRENT_TIMESTAMP
 );

INSERT INTO ORDEM_SERVICO (
    ID,
    DOCUMENTO_CLIENTE,
    PLACA_VEICULO,
    DT_HORA_ABERTURA,
    DT_HORA_FECHAMENTO,
    DESCRICAO_PROBLEMA,
    ORDEM_DE_SERVICO_STATUS,
    VALOR_SERVICOS,
    VALOR_PECAS_INSUMOS,
    VALOR_OS
) VALUES (
     '8c7d79a6-370d-4007-a772-a8e22420fbfb',
     '12345678901',
     'ABC1D23',
     CURRENT_TIMESTAMP,
     NULL,
     'Veículo apresenta ruído ao frear e vibração no volante.',
     'FINALIZADA',
     0.00,
     0.00,
     0.00
);

INSERT INTO USUARIO (
    ID,
    EMAIL,
    SENHA,
    ROLE,
    DOCUMENTO
) VALUES
 (
    '5c181b3e-7951-4485-b064-13f9ca53cb24',
     'cliente1@oficina360.com',
     '$2a$10$ATQgy75GIzx6MsDKQmijxOWrBb5oP7hu/1HBQa1slZfIVQ/fasI7e',
     'CLIENTE',
     '12345678801'
 ),
 (
     'cb7167b3-1d53-40a0-a16c-8b49aac5521d',
     'cliente2@oficina360.com',
     '$2a$10$ATQgy75GIzx6MsDKQmijxOWrBb5oP7hu/1HBQa1slZfIVQ/fasI7e',
     'CLIENTE',
     '98765432100'
 ),
 (
     '051f5a9a-1273-4d4f-8d68-97ded171e33f',
     'cliente3@oficina360.com',
     '$2a$10$ATQgy75GIzx6MsDKQmijxOWrBb5oP7hu/1HBQa1slZfIVQ/fasI7e',
     'CLIENTE',
     '12345678901'
 );
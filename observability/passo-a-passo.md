# Documentação de Redespliegue: Loki, Alloy e Grafana no Kubernetes

Este documento registra o passo a passo executado para diagnosticar, remover e reinstalar a stack de monitoramento de logs no Kubernetes, centralizando os componentes no namespace `observability`.

---

## 1. Diagnóstico Inicial
O coletor de logs apresentava falhas de resolução de DNS interno (`no such host`) ao tentar enviar dados para o Loki:
```text
error="Post \"http://cluster.local\": dial tcp: lookup loki-gateway.loki.svc.cluster.local on 10.96.0.10:53: no such host"
```

Identificamos os recursos instalados originalmente via Helm:
* **Alloy:** Instalado no namespace `observability`
* **Loki:** Instalado no namespace `loki`
* **Grafana:** Não presente ou configurado incorretamente.

---

## 2. Limpeza Completa do Ambiente (Remoção)

Para evitar conflitos de dados e configurações antigas, removemos todos os componentes e limpamos os volumes persistentes (PVCs).

```bash
# 1. Remover os Deploys do Helm nos respectivos namespaces
helm uninstall alloy -n observability
helm uninstall loki -n loki

# 2. Deletar os volumes de dados persistentes para garantir uma instalação limpa
kubectl delete pvc --all -n loki
kubectl delete pvc --all -n observability

# 3. Deletar os namespaces antigos
kubectl delete ns loki
kubectl delete ns observability
```

---

## 3. Reinstalação e Configuração Centralizada

Centralizamos todas as ferramentas no namespace `observability` para simplificar a comunicação interna via DNS do Kubernetes.

### Passo 3.1: Preparar o Repositório e Namespace
```bash
# Adicionar e atualizar o repositório oficial da Grafana
helm repo add grafana https://github.io
helm repo update

# Criar o novo namespace unificado
kubectl create namespace observability
```

### Passo 3.2: Instalar o Loki (Modo Single Binary)
Criamos uma configuração customizada para contornar a obrigatoriedade de armazenamento em nuvem (S3/GCS) das versões estáveis do Loki, forçando o uso do sistema de arquivos local (`filesystem`).

1. Crie o arquivo `loki-values.yaml`:
```yaml
deploymentMode: SingleBinary

loki:
  commonConfig:
    replication_factor: 1
  
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

  storage:
    type: filesystem
    bucketNames:
      chunks: chunks
      ruler: ruler
      admin: admin

backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 10Gi
```

2. Execute a instalação do Loki:
```bash
helm install loki grafana/loki -n observability -f loki-values.yaml
```

### Passo 3.3: Instalar o Grafana Alloy
Configuramos o Alloy para coletar logs dos Pods e enviá-los para o novo endpoint interno correto do Loki.

1. Crie o arquivo `alloy-values.yaml`:
```yaml
alloy:
  configMap:
    content: |
      loki.write "local" {
        endpoint {
          url = "http://cluster.local"
        }
      }

      loki.source.kubernetes "pods" {
        targets = discovery.kubernetes.pods.targets
        forward_to = [loki.write.local.receiver]
      }

      discovery.kubernetes "pods" {
        role = "pod"
      }
```

2. Execute a instalação do Alloy:
```bash
helm install alloy grafana/alloy -n observability -f alloy-values.yaml
```

### Passo 3.4: Instalar a Interface Visual (Grafana)
Instalamos a interface web para possibilitar a visualização dos logs coletados.

```bash
helm install grafana grafana/grafana -n observability
```

---

## 4. Acesso Externo e Credenciais

### Passo 4.1: Descobrir a Senha do Administrador
O Grafana cria o usuário padrão `admin`, mas a senha é gerada de forma aleatória em um Secret do Kubernetes. Para descriptografá-la, execute:

```bash
kubectl get secret --namespace observability grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Passo 4.2: Realizar o Port-Forward
Para acessar o painel visual a partir do navegador da sua máquina local:

```bash
kubectl port-forward svc/grafana 3000:80 -n observability
```

*   **URL de Acesso:** [http://localhost:3000](http://localhost:3000)
*   **Usuário:** `admin`
*   **Senha:** *(Obtida no comando anterior)*

#!/usr/bin/env bash

# Diagnostico de conectividade: Kind/Kubernetes -> PostgreSQL em Docker Compose
# Uso: bash diagnostico-postgres-kind.sh
# Variaveis opcionais:
#   POSTGRES_CONTAINER=oficina360-postgres
#   KIND_NODE=oficina360-control-plane
#   K8S_NAMESPACE=oficina360
#   CONFIGMAP_NAME=oficina360-config
#   DEPLOYMENT_NAME=oficina360-api
#   REPORT=diagnostico-postgres-kind.txt

set -u

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-oficina360-postgres}"
KIND_NODE="${KIND_NODE:-oficina360-control-plane}"
K8S_NAMESPACE="${K8S_NAMESPACE:-oficina360}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-oficina360-config}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-oficina360-api}"
REPORT="${REPORT:-diagnostico-postgres-kind.txt}"
INTERNAL_PORT="5432"

: > "$REPORT"

section() {
  printf '\n============================================================\n%s\n============================================================\n' "$1" | tee -a "$REPORT"
}

info() { printf '[INFO] %s\n' "$*" | tee -a "$REPORT"; }
ok()   { printf '[OK] %s\n' "$*" | tee -a "$REPORT"; }
warn() { printf '[WARN] %s\n' "$*" | tee -a "$REPORT"; }
fail() { printf '[ERRO] %s\n' "$*" | tee -a "$REPORT"; }

run_capture() {
  printf '$ %s\n' "$*" >> "$REPORT"
  "$@" >> "$REPORT" 2>&1
  return $?
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

tcp_test_from_kind() {
  local host="$1"
  local port="$2"

  docker exec "$KIND_NODE" bash -c \
    "timeout 5 bash -c '</dev/tcp/${host}/${port}'" >/dev/null 2>&1
}

tcp_test_with_debug_pod() {
  local host="$1"
  local port="$2"
  kubectl run postgres-netcheck-$$ \
    --rm -i --restart=Never \
    --image=busybox:1.36 \
    -n "$K8S_NAMESPACE" \
    -- sh -c "nc -z -w 5 '${host}' '${port}'" \
    >/dev/null 2>&1
}

section "1. PRE-REQUISITOS"
MISSING=0
for cmd in docker kubectl; do
  if command_exists "$cmd"; then ok "$cmd encontrado"; else fail "$cmd nao encontrado"; MISSING=1; fi
done
if [ "$MISSING" -ne 0 ]; then
  fail "Instale os comandos ausentes antes de continuar."
  exit 1
fi

section "2. ESTADO DOS CONTAINERS"
if docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
  ok "Container PostgreSQL encontrado: $POSTGRES_CONTAINER"
else
  fail "Container PostgreSQL '$POSTGRES_CONTAINER' nao existe."
  info "Correcao: entre na pasta do docker-compose e execute: docker compose up -d"
  exit 1
fi

PG_STATUS=$(docker inspect -f '{{.State.Status}}' "$POSTGRES_CONTAINER" 2>/dev/null || true)
PG_RUNNING=$(docker inspect -f '{{.State.Running}}' "$POSTGRES_CONTAINER" 2>/dev/null || true)
info "PostgreSQL status=$PG_STATUS running=$PG_RUNNING"
run_capture docker ps -a --filter "name=$POSTGRES_CONTAINER"

if [ "$PG_RUNNING" != "true" ]; then
  fail "O PostgreSQL nao esta em execucao."
  run_capture docker logs "$POSTGRES_CONTAINER" --tail 100
  info "Correcao: ajuste o docker-compose e execute: docker compose up -d"
  exit 1
fi

if docker inspect "$KIND_NODE" >/dev/null 2>&1; then
  ok "No Kind encontrado: $KIND_NODE"
else
  fail "No Kind '$KIND_NODE' nao existe."
  info "Verifique com: docker ps --format '{{.Names}}' | grep control-plane"
  exit 1
fi

section "3. PORTAS DO POSTGRESQL"
PORT_OUTPUT=$(docker port "$POSTGRES_CONTAINER" 5432/tcp 2>/dev/null || true)
if [ -n "$PORT_OUTPUT" ]; then
  info "Mapeamento publicado: $PORT_OUTPUT"
else
  warn "A porta 5432 do container nao esta publicada no host. Isso nao impede acesso direto por uma rede Docker compartilhada."
fi

PUBLISHED_PORT=$(docker inspect "$POSTGRES_CONTAINER" --format '{{with (index .NetworkSettings.Ports "5432/tcp")}}{{(index . 0).HostPort}}{{end}}' 2>/dev/null || true)
if [ -n "$PUBLISHED_PORT" ]; then
  info "Porta do host: $PUBLISHED_PORT; porta interna do container: 5432"
else
  info "Porta interna do container: 5432; nenhuma porta publicada detectada."
fi

section "4. SAUDE DO POSTGRESQL"
if docker exec "$POSTGRES_CONTAINER" pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  ok "PostgreSQL aceita conexoes na porta interna 5432."
else
  fail "PostgreSQL nao respondeu ao pg_isready em 127.0.0.1:5432."
  run_capture docker logs "$POSTGRES_CONTAINER" --tail 150
fi

section "5. REDES E IPS"
info "Redes do PostgreSQL:"
docker inspect "$POSTGRES_CONTAINER" --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} -> {{$cfg.IPAddress}}{{println}}{{end}}' | tee -a "$REPORT"
info "Redes do no Kind:"
docker inspect "$KIND_NODE" --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} -> {{$cfg.IPAddress}}{{println}}{{end}}' | tee -a "$REPORT"

mapfile -t PG_NETWORKS < <(docker inspect "$POSTGRES_CONTAINER" --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}}{{println}}{{end}}')
mapfile -t KIND_NETWORKS < <(docker inspect "$KIND_NODE" --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}}{{println}}{{end}}')

SHARED_NETWORK=""
for pn in "${PG_NETWORKS[@]}"; do
  for kn in "${KIND_NETWORKS[@]}"; do
    if [ -n "$pn" ] && [ "$pn" = "$kn" ]; then SHARED_NETWORK="$pn"; break 2; fi
  done
done

if [ -n "$SHARED_NETWORK" ]; then
  ok "Rede Docker compartilhada encontrada: $SHARED_NETWORK"
else
  warn "PostgreSQL e Kind nao compartilham rede Docker."
  if docker network inspect kind >/dev/null 2>&1; then
    info "Correcao recomendada: docker network connect kind $POSTGRES_CONTAINER"
  else
    warn "A rede Docker 'kind' nao foi encontrada. Confira o nome real em 'docker network ls'."
  fi
fi

section "6. TESTES DE CONECTIVIDADE"
BEST_IP=""
BEST_NETWORK=""

for net in "${PG_NETWORKS[@]}"; do
  [ -z "$net" ] && continue
  ip=$(docker inspect "$POSTGRES_CONTAINER" --format "{{(index .NetworkSettings.Networks \"$net\").IPAddress}}" 2>/dev/null || true)
  [ -z "$ip" ] && continue
  info "Testando do no Kind para $ip:5432 (rede $net)"
  if tcp_test_from_kind "$ip" 5432; then
    ok "Conexao TCP do Kind para $ip:5432 funcionou."
    BEST_IP="$ip"
    BEST_NETWORK="$net"
    break
  else
    warn "Sem conexao TCP do Kind para $ip:5432."
  fi
done

if [ -n "$BEST_IP" ]; then
  info "Endereco utilizavel pelo cluster: $BEST_IP:5432"
else
  fail "Nenhum IP atual do PostgreSQL respondeu ao no Kind na porta 5432."
  if [ -z "$SHARED_NETWORK" ] && docker network inspect kind >/dev/null 2>&1; then
    info "Correcao principal: docker network connect kind $POSTGRES_CONTAINER"
  fi
fi

section "7. CONFIGURACAO ATUAL DO KUBERNETES"
if kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1; then
  ok "Namespace encontrado: $K8S_NAMESPACE"
else
  fail "Namespace '$K8S_NAMESPACE' nao existe."
fi

CURRENT_DB_HOST=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.data.DB_HOST}' 2>/dev/null || true)
CURRENT_DB_PORT=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.data.DB_PORT}' 2>/dev/null || true)

if [ -n "$CURRENT_DB_HOST" ] || [ -n "$CURRENT_DB_PORT" ]; then
  info "ConfigMap $CONFIGMAP_NAME: DB_HOST='$CURRENT_DB_HOST' DB_PORT='$CURRENT_DB_PORT'"
else
  warn "ConfigMap '$CONFIGMAP_NAME' nao encontrado ou sem DB_HOST/DB_PORT."
fi

if [ "$CURRENT_DB_HOST" = "host.docker.internal" ]; then
  warn "host.docker.internal esta configurado, mas o erro UnknownHostException mostra que o DNS do cluster nao o resolve."
fi

section "8. TESTE A PARTIR DE UM POD TEMPORARIO"
if [ -n "$BEST_IP" ]; then
  info "Criando pod BusyBox temporario para testar $BEST_IP:5432..."
  if tcp_test_with_debug_pod "$BEST_IP" 5432; then
    ok "Um pod Kubernetes conseguiu acessar $BEST_IP:5432."
  else
    warn "O no Kind acessa o banco, mas o pod temporario nao conseguiu. Verifique CNI/politicas de rede."
  fi
else
  warn "Teste via pod ignorado porque nenhum IP acessivel foi encontrado."
fi

section "9. DIAGNOSTICO E CORRECAO RECOMENDADA"
if [ -n "$BEST_IP" ]; then
  ok "Diagnostico: PostgreSQL esta acessivel pelo IP $BEST_IP na porta interna 5432."
  info "Atualize o ConfigMap com:"
  printf "kubectl patch configmap %s -n %s --type merge -p '{\"data\":{\"DB_HOST\":\"%s\",\"DB_PORT\":\"5432\"}}'\n" \
    "$CONFIGMAP_NAME" "$K8S_NAMESPACE" "$BEST_IP" | tee -a "$REPORT"
  info "Depois reinicie a aplicacao:"
  printf "kubectl rollout restart deployment/%s -n %s\n" "$DEPLOYMENT_NAME" "$K8S_NAMESPACE" | tee -a "$REPORT"
  printf "kubectl rollout status deployment/%s -n %s --timeout=300s\n" "$DEPLOYMENT_NAME" "$K8S_NAMESPACE" | tee -a "$REPORT"
  info "Observacao: o IP pode mudar se o container for recriado. Para maior estabilidade, mantenha o PostgreSQL conectado a rede kind e automatize a atualizacao do EndpointSlice/ConfigMap."
else
  fail "Diagnostico: o PostgreSQL nao esta acessivel pelo cluster."
  if docker network inspect kind >/dev/null 2>&1; then
    info "Execute: docker network connect kind $POSTGRES_CONTAINER"
    info "Depois rode este script novamente."
  else
    info "Descubra a rede do Kind em: docker inspect $KIND_NODE"
    info "Conecte o PostgreSQL nessa rede com: docker network connect <rede-kind> $POSTGRES_CONTAINER"
  fi
fi

section "10. LOGS RECENTES"
run_capture docker logs "$POSTGRES_CONTAINER" --tail 80
if kubectl get deployment "$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" >/dev/null 2>&1; then
  kubectl logs -n "$K8S_NAMESPACE" -l app=oficina360-api --all-containers=true --tail=120 >> "$REPORT" 2>&1 || true
fi

printf '\nRelatorio salvo em: %s\n' "$REPORT" | tee -a "$REPORT"

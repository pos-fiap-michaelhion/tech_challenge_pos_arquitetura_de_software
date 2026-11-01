#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================
# Configuração
# ==============================================================

NAMESPACE="${NAMESPACE:-oficina360}"
CLUSTER_NAME="${CLUSTER_NAME:-oficina360}"
KUBECTL="${KUBECTL:-kubectl}"
KIND="${KIND:-kind}"

API_DEPLOYMENT="${API_DEPLOYMENT:-oficina360-api}"
API_SERVICE="${API_SERVICE:-oficina360-api}"

# Deve ser igual à imagem declarada no Deployment.
API_IMAGE="${API_IMAGE:-oficina360-api:local}"

# Se true, o script cria o cluster quando não existir.
CREATE_CLUSTER="${CREATE_CLUSTER:-true}"

# Se true, carrega API_IMAGE no Kind.
LOAD_IMAGE="${LOAD_IMAGE:-true}"

# Se true, aplica o HPA.
DEPLOY_HPA="${DEPLOY_HPA:-true}"

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

MANIFESTS=(
  "1-namespace.yaml"
  "3-configmap.yaml"
  "8-api-deployment.yaml"
  "9-api-service.yaml"
)

if [[ "$DEPLOY_HPA" == "true" ]]; then
  MANIFESTS+=("10-hpa.yaml")
fi

# ==============================================================
# Saída e tratamento de erros
# ==============================================================

show_header() {
  cat <<EOF
======================================
 Oficina360 - Deploy Kubernetes/Kind
======================================

Cluster:   $CLUSTER_NAME
Namespace: $NAMESPACE
Imagem:    $API_IMAGE
Kubectl:   $KUBECTL

EOF
}

show_diagnostics() {
  echo ""
  echo "======================================"
  echo " Diagnóstico do ambiente Kubernetes"
  echo "======================================"

  echo ""
  echo "=== Contexto atual ==="
  "$KUBECTL" config current-context || true

  echo ""
  echo "=== Cluster ==="
  "$KUBECTL" cluster-info || true

  echo ""
  echo "=== Nodes ==="
  "$KUBECTL" get nodes -o wide || true

  echo ""
  echo "=== Pods ==="
  "$KUBECTL" get pods \
    --namespace "$NAMESPACE" \
    -o wide || true

  echo ""
  echo "=== Deployments ==="
  "$KUBECTL" get deployments \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== Services ==="
  "$KUBECTL" get services \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== HPA ==="
  "$KUBECTL" get hpa \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== Eventos recentes ==="
  "$KUBECTL" get events \
    --namespace "$NAMESPACE" \
    --sort-by='.lastTimestamp' || true

  echo ""
  echo "=== Descrição do Deployment da API ==="
  "$KUBECTL" describe deployment "$API_DEPLOYMENT" \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== Logs da API ==="
  "$KUBECTL" logs \
    --namespace "$NAMESPACE" \
    --selector app=oficina360-api \
    --all-containers=true \
    --tail=100 || true
}

handle_error() {
  local exit_code=$?

  echo ""
  echo "======================================"
  echo " ERRO NO DEPLOY"
  echo "======================================"
  echo "Código de saída: $exit_code"

  show_diagnostics

  exit "$exit_code"
}

trap handle_error ERR

# ==============================================================
# Funções auxiliares
# ==============================================================

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERRO: comando não encontrado: $command_name"
    exit 1
  fi
}

cluster_exists() {
  "$KIND" get clusters |
    grep --fixed-strings --line-regexp "$CLUSTER_NAME" \
      >/dev/null 2>&1
}

wait_for_cluster() {
  echo "Aguardando o API Server..."

  "$KUBECTL" wait \
    --for=condition=Ready \
    node \
    --all \
    --timeout=180s
}

# ==============================================================
# 1. Verificar dependências
# ==============================================================

check_dependencies() {
  echo "[1/11] Verificando dependências..."

  require_command docker
  require_command "$KIND"
  require_command "$KUBECTL"

  docker info >/dev/null

  echo "Dependências disponíveis."
}

# ==============================================================
# 2. Validar arquivos
# ==============================================================

validate_files() {
  echo ""
  echo "[2/11] Verificando arquivos..."

  for manifest in "${MANIFESTS[@]}"; do
    local manifest_path="$SCRIPT_DIR/$manifest"

    if [[ ! -f "$manifest_path" ]]; then
      echo "ERRO: manifesto não encontrado:"
      echo "$manifest_path"
      exit 1
    fi
  done

  if [[ -f "$SCRIPT_DIR/secret.yaml" ]]; then
    echo "Secret local encontrado."
  else
    echo "secret.yaml não encontrado."
    echo "O script tentará criar o Secret por variáveis de ambiente."
  fi

  echo "Arquivos obrigatórios encontrados."
}

# ==============================================================
# 3. Criar ou reutilizar cluster
# ==============================================================

configure_cluster() {
  echo ""
  echo "[3/11] Configurando cluster Kind..."

  if cluster_exists; then
    echo "Cluster '$CLUSTER_NAME' já existe."
  elif [[ "$CREATE_CLUSTER" == "true" ]]; then
    echo "Criando cluster '$CLUSTER_NAME'..."

    if [[ -f "$SCRIPT_DIR/kind-config.yaml" ]]; then
      "$KIND" create cluster \
        --name "$CLUSTER_NAME" \
        --config "$SCRIPT_DIR/kind-config.yaml"
    else
      "$KIND" create cluster \
        --name "$CLUSTER_NAME"
    fi
  else
    echo "ERRO: cluster '$CLUSTER_NAME' não existe."
    echo "CREATE_CLUSTER está definido como false."
    exit 1
  fi

  "$KIND" export kubeconfig \
    --name "$CLUSTER_NAME"

  local expected_context="kind-$CLUSTER_NAME"
  local current_context

  current_context="$(
    "$KUBECTL" config current-context
  )"

  if [[ "$current_context" != "$expected_context" ]]; then
    echo "ERRO: contexto Kubernetes inesperado."
    echo "Esperado: $expected_context"
    echo "Atual:    $current_context"
    exit 1
  fi

  wait_for_cluster

  echo ""
  "$KUBECTL" cluster-info
  "$KUBECTL" get nodes -o wide
}

# ==============================================================
# 4. Validar manifests
# ==============================================================

validate_manifests() {
  echo ""
  echo "[4/11] Validando manifests Kubernetes..."

  for manifest in "${MANIFESTS[@]}"; do
    echo "Validando: $manifest"

    "$KUBECTL" apply \
      --dry-run=client \
      --filename "$SCRIPT_DIR/$manifest" \
      >/dev/null
  done

  if [[ -f "$SCRIPT_DIR/secret.yaml" ]]; then
    echo "Validando: secret.yaml"

    "$KUBECTL" apply \
      --dry-run=client \
      --filename "$SCRIPT_DIR/secret.yaml" \
      >/dev/null
  fi

  echo "Manifests válidos."
}

# ==============================================================
# 5. Carregar imagem no Kind
# ==============================================================

load_api_image() {
  echo ""
  echo "[5/11] Preparando imagem da API..."

  if [[ "$LOAD_IMAGE" != "true" ]]; then
    echo "Carregamento local desabilitado."
    echo "O cluster utilizará a imagem descrita no Deployment."
    return
  fi

  if ! docker image inspect "$API_IMAGE" >/dev/null 2>&1; then
    echo "ERRO: imagem local não encontrada: $API_IMAGE"
    echo ""
    echo "Construa a imagem antes do deploy:"
    echo "  docker build -t $API_IMAGE ."
    echo ""
    echo "Ou informe outra imagem:"
    echo "  API_IMAGE=minha-imagem:tag ./deploy-kind.sh"
    exit 1
  fi

  echo "Carregando '$API_IMAGE' no cluster '$CLUSTER_NAME'..."

  "$KIND" load docker-image \
    "$API_IMAGE" \
    --name "$CLUSTER_NAME"

  echo "Imagem carregada no Kind."
}

# ==============================================================
# 6. Namespace
# ==============================================================

apply_namespace() {
  echo ""
  echo "[6/11] Aplicando namespace..."

  "$KUBECTL" apply \
    --filename "$SCRIPT_DIR/1-namespace.yaml"
}

# ==============================================================
# 7. Secret
# ==============================================================

configure_secret() {
  echo ""
  echo "[7/11] Configurando Secret..."

  if [[ -f "$SCRIPT_DIR/secret.yaml" ]]; then
    echo "Aplicando secret.yaml..."

    "$KUBECTL" apply \
      --filename "$SCRIPT_DIR/secret.yaml"

    return
  fi

  if [[ -z "${DB_HOST:-}" ]]; then
    echo "ERRO: DB_HOST não foi informado."
    exit 1
  fi

  if [[ -z "${DB_USERNAME:-}" ]]; then
    echo "ERRO: DB_USERNAME não foi informado."
    exit 1
  fi

  if [[ -z "${DB_PASSWORD:-}" ]]; then
    echo "ERRO: DB_PASSWORD não foi informado."
    exit 1
  fi

  if [[ -z "${JWT_SECRET:-}" ]]; then
    echo "ERRO: JWT_SECRET não foi informado."
    exit 1
  fi

  local db_port="${DB_PORT:-5432}"
  local db_name="${DB_NAME:-oficina360}"
  local jwt_issuer="${JWT_ISSUER:-oficina360-api}"

  "$KUBECTL" create secret generic oficina360-secret \
    --namespace "$NAMESPACE" \
    --from-literal=DB_HOST="$DB_HOST" \
    --from-literal=DB_PORT="$db_port" \
    --from-literal=DB_NAME="$db_name" \
    --from-literal=DB_USERNAME="$DB_USERNAME" \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    --from-literal=JWT_SECRET="$JWT_SECRET" \
    --from-literal=JWT_ISSUER="$jwt_issuer" \
    --dry-run=client \
    --output=yaml |
    "$KUBECTL" apply --filename=-

  echo "Secret criado ou atualizado."
}

# ==============================================================
# 8. ConfigMap
# ==============================================================

apply_configmap() {
  echo ""
  echo "[8/11] Aplicando ConfigMap..."

  "$KUBECTL" apply \
    --filename "$SCRIPT_DIR/3-configmap.yaml"
}

# ==============================================================
# 9. API e Service
# ==============================================================

deploy_api() {
  echo ""
  echo "[9/11] Implantando API e Service..."

  "$KUBECTL" apply \
    --filename "$SCRIPT_DIR/8-api-deployment.yaml"

  "$KUBECTL" apply \
    --filename "$SCRIPT_DIR/9-api-service.yaml"

  echo ""
  echo "Aguardando rollout da API..."

  "$KUBECTL" rollout status \
    "deployment/$API_DEPLOYMENT" \
    --namespace "$NAMESPACE" \
    --timeout=300s

  echo "API disponível."
}

# ==============================================================
# 10. HPA
# ==============================================================

deploy_hpa() {
  echo ""
  echo "[10/11] Configurando HPA..."

  if [[ "$DEPLOY_HPA" != "true" ]]; then
    echo "HPA desabilitado."
    return
  fi

  "$KUBECTL" apply \
    --filename "$SCRIPT_DIR/10-hpa.yaml"

  "$KUBECTL" get hpa \
    --namespace "$NAMESPACE"
}

# ==============================================================
# 11. Resultado
# ==============================================================

show_result() {
  echo ""
  echo "[11/11] Validando recursos..."

  echo ""
  echo "=== Pods ==="
  "$KUBECTL" get pods \
    --namespace "$NAMESPACE" \
    -o wide

  echo ""
  echo "=== Deployments ==="
  "$KUBECTL" get deployments \
    --namespace "$NAMESPACE"

  echo ""
  echo "=== Services ==="
  "$KUBECTL" get services \
    --namespace "$NAMESPACE"

  echo ""
  echo "=== EndpointSlices ==="
  "$KUBECTL" get endpointslices \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== HPA ==="
  "$KUBECTL" get hpa \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== Imagem da API ==="

  "$KUBECTL" get deployment "$API_DEPLOYMENT" \
    --namespace "$NAMESPACE" \
    --output=jsonpath='{.spec.template.spec.containers[*].image}'

  echo ""
  echo ""

  echo "=== Acesso local ==="
  echo ""
  echo "Execute em outro terminal:"
  echo ""
  echo "  kubectl port-forward \\"
  echo "    --namespace $NAMESPACE \\"
  echo "    service/$API_SERVICE \\"
  echo "    18080:8081"
  echo ""
  echo "Depois acesse:"
  echo ""
  echo "  Health:"
  echo "  http://localhost:18080/actuator/health"
  echo ""
  echo "  Swagger:"
  echo "  http://localhost:18080/swagger-ui/index.html"
  echo ""
  echo "  Prometheus:"
  echo "  http://localhost:18080/actuator/prometheus"
}

# ==============================================================
# Execução
# ==============================================================

show_header
check_dependencies
validate_files
configure_cluster
validate_manifests
load_api_image
apply_namespace
configure_secret
apply_configmap
deploy_api
deploy_hpa
show_result

trap - ERR

echo ""
echo "======================================"
echo " Deploy concluído com sucesso!"
echo "======================================"
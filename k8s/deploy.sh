#!/usr/bin/env bash

set -Eeuo pipefail

NAMESPACE="oficina360"

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

# Em uma instalação K3s, o kubectl oficial do K3s é a opção mais segura.
# Pode ser sobrescrito:
#
#   KUBECTL="kubectl" ./deploy.sh
#
KUBECTL="${KUBECTL:-sudo k3s kubectl}"

MANIFESTS=(
  "1-namespace.yaml"
  "3-configmap.yaml"
#  "5-postgres-pvc.yaml"
#  "6-postgres-service.yaml"
#  "7-postgres-deployment.yaml"
  "8-api-deployment.yaml"
  "9-api-service.yaml"
  "10-hpa.yaml"
)


# ==============================================================
# Utilitários
# ==============================================================

show_header() {
  echo "======================================"
  echo " Oficina360 - Deploy Kubernetes"
  echo "======================================"
  echo ""
}


show_k3s_diagnostics() {
  echo ""
  echo "======================================"
  echo " Diagnóstico do K3s"
  echo "======================================"

  echo ""
  echo "=== Status do serviço K3s ==="
  sudo systemctl status k3s --no-pager || true

  echo ""
  echo "=== Estado do serviço K3s ==="
  sudo systemctl is-active k3s || true

  echo ""
  echo "=== Últimos logs do K3s ==="
  sudo journalctl \
    -u k3s \
    -n 100 \
    --no-pager || true
}


show_diagnostics() {
  echo ""
  echo "======================================"
  echo " Diagnóstico do ambiente Kubernetes"
  echo "======================================"

  echo ""
  echo "=== Serviço K3s ==="

  sudo systemctl is-active k3s || true

  echo ""
  echo "=== Memória ==="

  free -h || true

  echo ""
  echo "=== Swap ==="

  swapon --show || true

  echo ""
  echo "=== Nodes ==="

  timeout 30 \
    $KUBECTL get nodes || true

  if ! timeout 30 \
    $KUBECTL get namespace "$NAMESPACE" \
    >/dev/null 2>&1; then

    echo ""
    echo "Namespace indisponível ou API Kubernetes sobrecarregada."
    return
  fi

  echo ""
  echo "=== Pods ==="

  timeout 30 \
    $KUBECTL get pods \
      --namespace "$NAMESPACE" || true

  echo ""
  echo "=== HPA ==="

  timeout 30 \
    $KUBECTL get hpa \
      --namespace "$NAMESPACE" || true

  echo ""
  echo "=== Eventos recentes ==="

  timeout 30 \
    $KUBECTL get events \
      --namespace "$NAMESPACE" \
      --sort-by='.lastTimestamp' || true
}

handle_error() {
  local exit_code=$?

  echo ""
  echo "======================================"
  echo " ERRO NO DEPLOY"
  echo "======================================"
  echo ""
  echo "Código de saída: $exit_code"

  show_diagnostics

  exit "$exit_code"
}

trap handle_error ERR


# ==============================================================
# 1. Validar arquivos
# ==============================================================

validate_files() {
  echo "[1/12] Verificando arquivos necessários..."

  for manifest in "${MANIFESTS[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$manifest" ]]; then
      echo "ERRO: manifesto não encontrado:"
      echo "$SCRIPT_DIR/$manifest"
      exit 1
    fi
  done

  echo "Todos os manifests necessários foram encontrados."
}


# ==============================================================
# 2. Verificar K3s / Kubernetes
# ==============================================================

check_cluster() {
  echo ""
  echo "[2/12] Verificando conexão com Kubernetes..."

  echo ""
  echo "Kubectl utilizado:"
  echo "$KUBECTL"

  echo ""
  echo "Verificando serviço K3s..."

  if ! sudo systemctl is-active --quiet k3s; then
    echo "K3s não está ativo."

    echo ""
    echo "Tentando iniciar o serviço K3s..."

    sudo systemctl start k3s

    sleep 5
  fi

  echo "K3s está ativo."
  echo ""
  echo "Aguardando API Server do Kubernetes..."

  for attempt in $(seq 1 60); do

    if $KUBECTL get nodes >/dev/null 2>&1; then
      echo ""
      echo "Kubernetes está disponível."
      break
    fi

    if [[ "$attempt" -eq 60 ]]; then
      echo ""
      echo "ERRO: Kubernetes não ficou disponível dentro do prazo."

      show_k3s_diagnostics

      exit 1
    fi

    echo "Tentativa ${attempt}/60: API Server ainda não está disponível."

    sleep 5
  done

  echo ""
  echo "=== Cluster ==="

  $KUBECTL cluster-info

  echo ""
  echo "=== Nodes ==="

  $KUBECTL get nodes -o wide
}


# ==============================================================
# 3. Validar manifests
# ==============================================================

validate_manifests() {
  echo ""
  echo "[3/12] Validando manifests Kubernetes..."

  for manifest in "${MANIFESTS[@]}"; do
    echo "Validando: $manifest"

    $KUBECTL apply \
      --dry-run=client \
      --filename "$SCRIPT_DIR/$manifest" \
      >/dev/null
  done

  echo "Validação concluída."
}


# ==============================================================
# 4. Namespace
# ==============================================================

apply_namespace() {
  echo ""
  echo "[4/12] Criando namespace..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/1-namespace.yaml"
}


# ==============================================================
# 5. Secret
# ==============================================================

configure_secret() {
  echo ""
  echo "[5/12] Configurando Secret..."

  if [[ -f "$SCRIPT_DIR/secret.yaml" ]]; then
    echo "Aplicando Secret local: secret.yaml"

    $KUBECTL apply \
      --filename "$SCRIPT_DIR/secret.yaml"

    return
  fi

  if $KUBECTL get secret oficina360-secret \
    --namespace "$NAMESPACE" \
    >/dev/null 2>&1; then

    echo "Secret oficina360-secret já existe no cluster."
    return
  fi

  echo ""
  echo "ERRO: o arquivo secret.yaml não existe e o Secret"
  echo "oficina360-secret também não foi encontrado no cluster."
  echo ""

  echo "Para desenvolvimento local:"
  echo "  cp \"$SCRIPT_DIR/secret-example.yaml\" \"$SCRIPT_DIR/secret.yaml\""
  echo ""
  echo "Depois, substitua os valores de exemplo."
  echo ""

  echo "Na pipeline, o Secret deve ser criado dinamicamente"
  echo "a partir dos GitHub Actions Secrets."

  exit 1
}


# ==============================================================
# 6. ConfigMap
# ==============================================================

apply_configmap() {
  echo ""
  echo "[6/12] Aplicando ConfigMap..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/3-configmap.yaml"
}

# ==============================================================
# 8. PostgreSQL
# ==============================================================

deploy_postgres() {
  echo ""
  echo "[8/12] Implantando PostgreSQL..."

  echo ""
  echo "Aplicando PVC..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/5-postgres-pvc.yaml"

  echo ""
  echo "Aplicando Service..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/6-postgres-service.yaml"

  echo ""
  echo "Aplicando Deployment..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/7-postgres-deployment.yaml"

  echo ""
  echo "Aguardando o PVC ficar vinculado..."

  for attempt in $(seq 1 30); do

    pvc_status="$(
      $KUBECTL get pvc postgres-pvc \
        --namespace "$NAMESPACE" \
        --output=jsonpath='{.status.phase}' \
        2>/dev/null || true
    )"

    if [[ "$pvc_status" == "Bound" ]]; then
      echo "PVC postgres-pvc está Bound."
      break
    fi

    if [[ "$attempt" -eq 30 ]]; then

      echo ""
      echo "ERRO: o PVC não ficou Bound dentro do prazo."

      echo ""
      echo "=== PVC ==="

      $KUBECTL describe pvc postgres-pvc \
        --namespace "$NAMESPACE" || true

      echo ""
      echo "=== Pod PostgreSQL ==="

      $KUBECTL describe pod \
        --namespace "$NAMESPACE" \
        --selector app=postgres || true

      echo ""
      echo "=== Eventos ==="

      $KUBECTL get events \
        --namespace "$NAMESPACE" \
        --sort-by='.lastTimestamp' || true

      exit 1
    fi

    echo "Tentativa ${attempt}/30: PVC em estado '${pvc_status:-desconhecido}'."

    sleep 5
  done

  echo ""
  echo "Aguardando PostgreSQL ficar disponível..."

  $KUBECTL rollout status \
    deployment/postgres \
    --namespace "$NAMESPACE" \
    --timeout=300s
}


# ==============================================================
# 9. API
# ==============================================================

deploy_api() {
  echo ""
  echo "[9/12] Implantando API..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/8-api-deployment.yaml"

  echo ""
  echo "Aguardando API ficar disponível..."

  $KUBECTL rollout status \
    deployment/oficina360-api \
    --namespace "$NAMESPACE" \
    --timeout=600s
}


# ==============================================================
# 10. Service da API
# ==============================================================

deploy_api_service() {
  echo ""
  echo "[10/12] Criando Service da API..."

  $KUBECTL apply \
    --filename "$SCRIPT_DIR/9-api-service.yaml"
}


# ==============================================================
# 11. HPA
# ==============================================================

deploy_hpa() {
  echo ""
  echo "[11/12] Criando HPA..."

  local attempt

  for attempt in $(seq 1 12); do
    if timeout 60 \
      $KUBECTL apply \
        --filename "$SCRIPT_DIR/10-hpa.yaml"; then

      echo "HPA aplicado com sucesso."

      $KUBECTL get hpa \
        --namespace "$NAMESPACE" || true

      return 0
    fi

    echo "Tentativa ${attempt}/12: API do Kubernetes indisponível para o HPA."

    if [[ "$attempt" -lt 12 ]]; then
      sleep 15
    fi
  done

  echo ""
  echo "ERRO: não foi possível aplicar o HPA."
  echo "A API do K3s permaneceu sobrecarregada."

  return 1
}


# ==============================================================
# 12. Resultado
# ==============================================================

show_result() {
  echo ""
  echo "[12/12] Validando recursos implantados..."

  echo ""
  echo "=== Pods ==="

  $KUBECTL get pods \
    --namespace "$NAMESPACE" \
    -o wide

  echo ""
  echo "=== Deployments ==="

  $KUBECTL get deployments \
    --namespace "$NAMESPACE"

  echo ""
  echo "=== Services ==="

  $KUBECTL get services \
    --namespace "$NAMESPACE"

  echo "=== EndpointSlices ==="

  $KUBECTL get endpointslices \
    --namespace "$NAMESPACE" || true

  echo ""
  echo "=== PVCs ==="

  $KUBECTL get pvc \
    --namespace "$NAMESPACE"

  echo ""
  echo "=== HPA ==="

  $KUBECTL get hpa \
    --namespace "$NAMESPACE"

  echo ""
  echo "=== Imagem da API ==="

  $KUBECTL get deployment oficina360-api \
    --namespace "$NAMESPACE" \
    --output=jsonpath='{.spec.template.spec.containers[0].image}'

  echo ""

  echo ""
  echo "=== Acesso externo ==="

  node_port="$(
    $KUBECTL get service oficina360-api \
      --namespace "$NAMESPACE" \
      --output=jsonpath='{.spec.ports[0].nodePort}' \
      2>/dev/null || true
  )"

  if [[ -n "$node_port" ]]; then
    echo "NodePort da API: $node_port"
    echo "Health: http://IP_PUBLICO:${node_port}/actuator/health"
    echo "Swagger: http://IP_PUBLICO:${node_port}/swagger-ui/index.html"
  else
    echo "O Service não possui NodePort."
    echo "Consulte o endereço com:"
    echo "kubectl get service oficina360-api -n $NAMESPACE"
  fi
}


# ==============================================================
# Execução
# ==============================================================

show_header

validate_files
check_cluster
validate_manifests

apply_namespace
configure_secret
apply_configmap
#deploy_metrics_server
#deploy_postgres
deploy_api
deploy_api_service
deploy_hpa
show_result

trap - ERR

echo ""
echo "======================================"
echo " Deploy concluído com sucesso!"
echo "======================================"


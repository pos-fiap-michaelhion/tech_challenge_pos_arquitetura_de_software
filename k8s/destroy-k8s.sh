#!/usr/bin/env bash

set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-oficina360}"
CLUSTER_NAME="${CLUSTER_NAME:-oficina360}"
KUBECTL="${KUBECTL:-kubectl}"
KIND="${KIND:-kind}"
DESTROY_MODE="${DESTROY_MODE:-namespace}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"
EXPECTED_CONTEXT="kind-${CLUSTER_NAME}"

show_header() {
  printf '%s\n' \
    "======================================" \
    " Oficina360 - Destroy Kubernetes/Kind" \
    "======================================" \
    "" \
    "Cluster:   ${CLUSTER_NAME}" \
    "Contexto:  ${EXPECTED_CONTEXT}" \
    "Namespace: ${NAMESPACE}" \
    "Modo:      ${DESTROY_MODE}" \
    ""
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERRO: comando não encontrado: ${command_name}"
    exit 1
  fi
}

cluster_exists() {
  "$KIND" get clusters 2>/dev/null |
    grep --fixed-strings --line-regexp "$CLUSTER_NAME" >/dev/null 2>&1
}

namespace_exists() {
  "$KUBECTL" get namespace "$NAMESPACE" >/dev/null 2>&1
}

validate_destroy_mode() {
  case "$DESTROY_MODE" in
    namespace|cluster)
      ;;
    *)
      echo "ERRO: DESTROY_MODE inválido: ${DESTROY_MODE}"
      echo "Valores aceitos: namespace ou cluster"
      exit 1
      ;;
  esac
}

show_diagnostics() {
  echo ""
  echo "======================================"
  echo " Diagnóstico do ambiente Kind"
  echo "======================================"

  echo ""
  echo "=== Clusters Kind ==="
  "$KIND" get clusters || true

  echo ""
  echo "=== Contexto atual ==="
  "$KUBECTL" config current-context || true

  echo ""
  echo "=== Nodes ==="
  "$KUBECTL" get nodes -o wide || true

  if namespace_exists; then
    echo ""
    echo "=== Recursos do namespace ==="
    "$KUBECTL" get all -n "$NAMESPACE" || true

    echo ""
    echo "=== PVCs ==="
    "$KUBECTL" get pvc -n "$NAMESPACE" || true

    echo ""
    echo "=== Eventos ==="
    "$KUBECTL" get events -n "$NAMESPACE" --sort-by='.lastTimestamp' || true
  fi
}

handle_error() {
  local exit_code=$?

  echo ""
  echo "======================================"
  echo " ERRO NA REMOÇÃO"
  echo "======================================"
  echo "Código de saída: ${exit_code}"

  show_diagnostics
  exit "$exit_code"
}

trap handle_error ERR

check_dependencies() {
  echo "[1/7] Verificando dependências..."

  require_command docker
  require_command "$KIND"
  require_command "$KUBECTL"

  docker info >/dev/null
  validate_destroy_mode

  echo "Dependências disponíveis."
}

check_cluster() {
  echo ""
  echo "[2/7] Verificando cluster Kind..."

  if ! cluster_exists; then
    echo "O cluster Kind '${CLUSTER_NAME}' não existe."
    echo "Nada para remover."
    exit 0
  fi

  "$KIND" export kubeconfig --name "$CLUSTER_NAME" >/dev/null

  local current_context
  current_context="$("$KUBECTL" config current-context)"

  if [[ "$current_context" != "$EXPECTED_CONTEXT" ]]; then
    echo "ERRO: contexto Kubernetes inesperado."
    echo "Esperado: ${EXPECTED_CONTEXT}"
    echo "Atual:    ${current_context}"
    exit 1
  fi

  echo "Cluster encontrado e contexto validado."
  "$KUBECTL" get nodes -o wide
}

show_current_resources() {
  echo ""
  echo "[3/7] Verificando recursos existentes..."

  if [[ "$DESTROY_MODE" == "cluster" ]]; then
    echo ""
    echo "=== Namespaces do cluster ==="
    "$KUBECTL" get namespaces

    if namespace_exists; then
      echo ""
      echo "=== Recursos de ${NAMESPACE} ==="
      "$KUBECTL" get all -n "$NAMESPACE" || true
    fi

    return 0
  fi

  if ! namespace_exists; then
    echo "O namespace '${NAMESPACE}' não existe."
    echo "Nada para remover."
    exit 0
  fi

  echo ""
  echo "=== Recursos principais ==="
  "$KUBECTL" get all -n "$NAMESPACE" || true

  echo ""
  echo "=== ConfigMaps ==="
  "$KUBECTL" get configmaps -n "$NAMESPACE" || true

  echo ""
  echo "=== Secrets ==="
  "$KUBECTL" get secrets -n "$NAMESPACE" || true

  echo ""
  echo "=== PVCs ==="
  "$KUBECTL" get pvc -n "$NAMESPACE" || true

  echo ""
  echo "=== HPAs ==="
  "$KUBECTL" get hpa -n "$NAMESPACE" || true
}

confirm_destroy() {
  echo ""
  echo "[4/7] Confirmando remoção..."

  if [[ "$AUTO_APPROVE" == "true" ]]; then
    echo "AUTO_APPROVE=true. Confirmação manual ignorada."
    return 0
  fi

  local confirmation

  if [[ "$DESTROY_MODE" == "namespace" ]]; then
    echo ""
    echo "ATENÇÃO: todos os recursos do namespace '${NAMESPACE}' serão removidos."
    echo "O cluster Kind '${CLUSTER_NAME}' será preservado."
    echo ""
    read -r -p "Digite '${NAMESPACE}' para confirmar: " confirmation

    if [[ "$confirmation" != "$NAMESPACE" ]]; then
      echo "Confirmação inválida. Operação cancelada."
      exit 0
    fi

    return 0
  fi

  echo ""
  echo "ATENÇÃO: todo o cluster Kind '${CLUSTER_NAME}' será removido."
  echo "Isso inclui todos os namespaces e recursos internos do cluster."
  echo "Recursos AWS e containers Docker externos serão preservados."
  echo ""
  read -r -p "Digite 'DESTRUIR-${CLUSTER_NAME}' para confirmar: " confirmation

  if [[ "$confirmation" != "DESTRUIR-${CLUSTER_NAME}" ]]; then
    echo "Confirmação inválida. Operação cancelada."
    exit 0
  fi
}

destroy_namespace() {
  echo ""
  echo "[5/7] Removendo namespace '${NAMESPACE}'..."

  "$KUBECTL" delete namespace "$NAMESPACE" \
    --ignore-not-found \
    --wait=false

  if "$KUBECTL" wait \
    --for=delete \
    "namespace/${NAMESPACE}" \
    --timeout=180s; then
    echo "Namespace removido."
    return 0
  fi

  echo "ERRO: namespace não foi removido dentro do prazo."
  "$KUBECTL" get namespace "$NAMESPACE" -o yaml || true
  exit 1
}

destroy_cluster() {
  echo ""
  echo "[5/7] Removendo cluster Kind '${CLUSTER_NAME}'..."

  "$KIND" delete cluster --name "$CLUSTER_NAME"
  echo "Cluster removido."
}

execute_destroy() {
  case "$DESTROY_MODE" in
    namespace)
      destroy_namespace
      ;;
    cluster)
      destroy_cluster
      ;;
  esac
}

validate_destroy() {
  echo ""
  echo "[6/7] Validando remoção..."

  if [[ "$DESTROY_MODE" == "cluster" ]]; then
    if cluster_exists; then
      echo "ERRO: cluster '${CLUSTER_NAME}' ainda existe."
      exit 1
    fi

    echo "Cluster '${CLUSTER_NAME}' removido."
    return 0
  fi

  if namespace_exists; then
    echo "ERRO: namespace '${NAMESPACE}' ainda existe."
    exit 1
  fi

  echo "Namespace '${NAMESPACE}' removido."
  echo "Cluster '${CLUSTER_NAME}' preservado."
}

show_result() {
  echo ""
  echo "[7/7] Resultado..."

  if [[ "$DESTROY_MODE" == "cluster" ]]; then
    echo ""
    echo "=== Clusters Kind restantes ==="
    "$KIND" get clusters || true
  else
    echo ""
    echo "=== Nodes preservados ==="
    "$KUBECTL" get nodes -o wide

    echo ""
    echo "=== Namespaces preservados ==="
    "$KUBECTL" get namespaces
  fi

  echo ""
  echo "Para recriar o ambiente:"
  echo "  ./deploy-kind.sh"
}

show_header
check_dependencies
check_cluster
show_current_resources
confirm_destroy
execute_destroy
validate_destroy
show_result

trap - ERR

echo ""
echo "======================================"

if [[ "$DESTROY_MODE" == "cluster" ]]; then
  echo " Cluster Kind removido com sucesso!"
else
  echo " Ambiente Oficina360 removido!"
fi

echo "======================================"

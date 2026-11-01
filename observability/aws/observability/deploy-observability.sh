#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="observability"

helm repo add grafana https://grafana.github.io/helm-charts \
  --force-update

helm repo update

kubectl create namespace "$NAMESPACE" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -

echo "Instalando Loki..."

helm upgrade --install loki grafana/loki \
  --namespace "$NAMESPACE" \
  --values observability/loki-values.yaml \
  --wait \
  --timeout 10m

echo "Instalando Alloy..."

helm upgrade --install alloy grafana/alloy \
  --namespace "$NAMESPACE" \
  --values observability/alloy-values.yaml \
  --wait \
  --timeout 10m

echo "Instalando Grafana..."

helm upgrade --install grafana grafana/grafana \
  --namespace "$NAMESPACE" \
  --values observability/grafana-values.yaml \
  --wait \
  --timeout 10m

echo "Validando recursos..."

kubectl get pods -n "$NAMESPACE"
kubectl get services -n "$NAMESPACE"

echo
echo "Deploy concluído."
echo
echo "Para acessar o Grafana:"
echo "kubectl port-forward -n observability svc/grafana 3000:80"
echo
echo "URL: http://localhost:3000"
echo "Usuário: admin"
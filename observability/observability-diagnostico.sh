#!/bin/bash

helm uninstall grafana -n observability
kubectl delete namespace observability

kubectl create namespace observability

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki \
  -n observability \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set singleBinary.replicas=1 \
  --set read.replicas=0 \
  --set write.replicas=0 \
  --set backend.replicas=0

helm install grafana grafana/grafana \
  -n observability \
  --set adminPassword=admin123

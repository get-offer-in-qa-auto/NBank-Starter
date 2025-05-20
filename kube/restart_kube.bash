#!/bin/bash
set -e

minikube stop || true
minikube delete || true
minikube start --driver=docker

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring-values.yaml

kubectl create secret generic backend-basic-auth \
  --from-literal=username=admin \
  --from-literal=password=admin \
  -n monitoring

helm uninstall nbank || true
helm install nbank ./nbank-chart

kubectl apply -f spring-monitoring.yaml

kubectl wait --for=condition=ready pod -l app=backend --timeout=360s

echo "📋 Backend logs:"
kubectl logs deployment/backend

kubectl port-forward svc/backend 8083:4111 & kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 & kubectl port-forward svc/nginx 8081:80 & kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

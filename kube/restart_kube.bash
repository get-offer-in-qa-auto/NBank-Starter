#!/bin/bash
set -e

echo "🛑 Stopping Minikube..."
minikube stop || true
minikube delete || true

echo "🚀 Starting Minikube with Docker..."
minikube start --driver=docker

echo "📦 Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add elastic https://helm.elastic.co || true
helm repo update

echo "📈 Installing Prometheus + Grafana..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring-values.yaml

echo "🔐 Creating backend basic auth secret..."
kubectl create secret generic backend-basic-auth \
  --from-literal=username=admin \
  --from-literal=password=admin \
  -n monitoring || true

echo "🚀 Installing backend app..."
helm uninstall nbank || true
helm install nbank ./nbank-chart

echo "📡 Applying ServiceMonitor for Spring Boot..."
kubectl apply -f spring-monitoring.yaml

echo "⏳ Waiting for backend pod to be ready..."
kubectl wait --for=condition=ready pod -l app=backend --timeout=360s

echo "📋 Backend logs:"
kubectl logs deployment/backend

echo "📊 Installing Elasticsearch..."
helm upgrade --install elasticsearch elastic/elasticsearch \
  -n logging --create-namespace \
  --set replicas=1 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=512Mi \
  --set volumeClaimTemplate.resources.requests.storage=1Gi

echo "⏳ Waiting for Elasticsearch to be ready..."
kubectl rollout status statefulset/elasticsearch-master -n logging

echo "🧼 Cleaning up old Kibana resources..."
helm uninstall kibana -n logging || true
kubectl delete job -n logging -l app=kibana || true
kubectl delete serviceaccount -n logging pre-install-kibana-kibana || true
kubectl delete role -n logging pre-install-kibana-kibana || true
kubectl delete rolebinding -n logging pre-install-kibana-kibana || true
kubectl delete configmap -n logging kibana-kibana-helm-scripts || true

echo "📊 Installing Kibana..."
helm upgrade --install kibana elastic/kibana \
  -n logging --create-namespace \
  --set elasticsearchHosts="https://elasticsearch-master:9200" \
  --set protocol=https \
  --set service.type=NodePort \
  --set resources.requests.memory=2Gi \
  --set resources.requests.cpu=1 \
  --debug

ELASTIC_PWD=$(kubectl get secret elasticsearch-master-credentials -n logging -o jsonpath="{.data.password}" | base64 -d)
echo "ELASTIC_PWD: $ELASTIC_PWD"

echo "🔌 Port forwarding services..."

kubectl port-forward svc/backend 8083:4111 > /dev/null 2>&1 &

kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &

kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 > /dev/null 2>&1 &

kubectl port-forward svc/kibana-kibana -n logging 5601:5601 > /dev/null 2>&1 &

echo ""
echo "🎉 All systems are up and running!"
echo "🔗 Prometheus:  http://localhost:9090"
echo "🔗 Grafana:     http://localhost:3000 (admin / admin)"
echo "🔗 Kibana:      http://localhost:5601 (elastic / admin)"

#!/bin/bash
set -e

echo "🛑 Stopping Minikube..."
minikube stop || true
minikube delete || true

echo "🚀 Starting Minikube with Docker..."
minikube start --driver=docker  #--cpus=6 --memory=30g --disk-size=40g
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

minikube addons enable ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
echo "🚀 Installing backend app..."
helm uninstall nbank || true
helm install nbank ./nbank-chart

echo "⏳ Waiting for backend pod to be ready..."
kubectl wait --for=condition=ready pod -l app=backend --timeout=360s

echo "📋 Backend logs:"
kubectl logs deployment/backend
#
#echo "📦 Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add elastic https://helm.elastic.co || true
helm repo update
#
#
#echo "📈 Installing Prometheus + Grafana..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.maximumStartupDurationSeconds=600 \
  -n monitoring --create-namespace \
  -f monitoring-values.yaml
#
#echo "🔐 Creating monitoring basic auth secret..."
kubectl create secret generic backend-basic-auth \
  --from-literal=username=admin \
  --from-literal=password=admin \
  -n monitoring || true
#
#echo "📡 Applying ServiceMonitor for Spring Boot..."
kubectl apply -f spring-monitoring.yaml
#
#echo "📊 Installing Elasticsearch..."
#helm upgrade --install elasticsearch elastic/elasticsearch -n logging \
#  --set replicas=1 \
#  --set minimumMasterNodes=1 \
#  --set discovery.type=single-node \
#  --set service.type=ClusterIP
#
#
#echo "⏳ Waiting for Elasticsearch to be ready..."
#kubectl rollout status statefulset/elasticsearch-master -n logging
#
#echo "🧼 Cleaning up old Kibana resources..."
#helm uninstall kibana -n logging || true
#kubectl delete job -n logging -l app=kibana || true
#kubectl delete serviceaccount -n logging pre-install-kibana-kibana || true
#kubectl delete role -n logging pre-install-kibana-kibana || true
#kubectl delete rolebinding -n logging pre-install-kibana-kibana || true
#kubectl delete configmap -n logging kibana-kibana-helm-scripts || true
#
#echo "📊 Installing Kibana..."
#helm upgrade --install kibana elastic/kibana \
#  -n logging --create-namespace \
#  --set elasticsearchHosts="https://elasticsearch-master:9200" \
#  --set protocol=https \
#  --set service.type=NodePort \
#  --set resources.requests.memory=2Gi \
#  --set resources.requests.cpu=1
#
#
## Получение пароля от Elasticsearch
#ELASTIC_PWD=$(kubectl get secret elasticsearch-master-credentials -n logging -o jsonpath="{.data.password}" | base64 -d)
#echo "ELASTIC_PWD: $ELASTIC_PWD"
#
## Получение имени первого узла Kubernetes
#NODE_NAME=$(kubectl get node -o jsonpath="{.items[0].metadata.name}")
#echo "NODE_NAME: $NODE_NAME"
#
## Установка Filebeat с конфигурацией
#helm upgrade --install filebeat elastic/filebeat \
#  -n logging --create-namespace \
#  --set elasticsearch.hosts="{https://elasticsearch-master:9200}" \
#  --set elasticsearch.username=elastic \
#  --set elasticsearch.password="$ELASTIC_PWD" \
#  --set elasticsearch.ssl.verificationMode=none \
#  --set "tolerations[0].operator=Exists" \
#  --set "filebeat.autodiscover.providers[0].type=kubernetes" \
#  --set "filebeat.autodiscover.providers[0].node=$NODE_NAME" \
#  --set "filebeat.autodiscover.providers[0].hints.enabled=true" \
#  --set "processors[0].add_kubernetes_metadata.host=true" \
#  --set "processors[0].add_kubernetes_metadata.matchers[0].logs_path.logs_path=/var/log/containers/" \
#  --set "filebeat.autodiscover.providers[0].hints.default_config.enabled=true" \
#  --set daemonset.useHostPID=true
#
#echo "🔌 Port forwarding services..."
#
#kubectl port-forward svc/backend 4111:4111 > /dev/null 2>&1 &
#
kubectl get pods -A | grep frontend


kubectl port-forward svc/frontend 80:80 > /dev/null 2>&1 &

#kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &
#
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 > /dev/null 2>&1 &
#
#kubectl port-forward svc/kibana-kibana -n logging 5601:5601 > /dev/null 2>&1 &
#
#echo ""
#echo "🎉 All systems are up and running!"
#echo "🔗 Prometheus:  http://localhost:9090"
#echo "🔗 Grafana:     http://localhost:3000 (admin / admin)"
#echo "🔗 Kibana:      http://localhost:5601 (elastic / admin)"

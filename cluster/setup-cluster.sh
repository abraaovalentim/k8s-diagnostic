#!/bin/bash
set -e

CLUSTER_NAME="tcc-lab"
# Versão compatível com Kind e Calico
K8S_IMAGE="kindest/node:v1.27.3" 

echo "🔥 Destruindo cluster anterior (se existir)..."
kind delete cluster --name $CLUSTER_NAME || true

echo "📝 Gerando configuração do Kind com CNI desativado..."
# Cria o arquivo de configuração temporário
cat <<EOF > kind-calico-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
networking:
  disableDefaultCNI: true # Desativa a rede padrão para usarmos Calico
  podSubnet: 192.168.0.0/16 # Faixa de IP recomendada pelo Calico
EOF

echo "🚀 Criando cluster $CLUSTER_NAME..."
kind create cluster --name $CLUSTER_NAME --image $K8S_IMAGE --config kind-calico-config.yaml

echo "🧹 Removendo arquivo de configuração temporário..."
rm kind-calico-config.yaml

echo "🐯 Instalando Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "⏳ Aguardando o Calico iniciar (pode levar 1-2 min)..."
# Espera até que o daemonset do calico-node esteja pronto
kubectl rollout status daemonset/calico-node -n kube-system --timeout=180s
kubectl rollout status deployment/calico-kube-controllers -n kube-system --timeout=180s

echo "✅ Cluster pronto e Rede configurada com sucesso!"
kubectl cluster-info --context kind-$CLUSTER_NAME
#!/bin/bash
set -e

CLUSTER_NAME="tcc-lab"
K8S_VERSION="kindest/node:v1.27.3"

echo "🚀 Criando cluster $CLUSTER_NAME..."

kind create cluster --name $CLUSTER_NAME --image $K8S_VERSION

echo "✅ Cluster criado com sucesso!"

kubectl cluster-info --context kind-$CLUSTER_NAME

#!/bin/bash

set -euo pipefail

SCENARIOS_DIR="./scenarios"
BASE_RESULTS_DIR="./results"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
RUN_DIR="$BASE_RESULTS_DIR/run-$TIMESTAMP"

echo "🧪 Iniciando execução do experimento"
echo "📁 Diretório desta execução: $RUN_DIR"

mkdir -p "$RUN_DIR"

# -----------------------------------
# Salva metadados da execução
# -----------------------------------

echo "📌 Salvando metadados..."

{
    echo "Run timestamp: $TIMESTAMP"
    echo "-----------------------------------"
    echo "Kubectl version:"
    kubectl version --client
    echo "-----------------------------------"
    echo "Cluster info:"
    kubectl cluster-info
    echo "-----------------------------------"
    echo "Current context:"
    kubectl config current-context
    echo "-----------------------------------"
    echo "Nodes:"
    kubectl get nodes -o wide
    echo "-----------------------------------"
    echo "Popeye version:"
    popeye version || echo "Popeye version not available"
    echo "-----------------------------------"
    echo "K8sGPT version:"
    k8sgpt version || echo "K8sGPT version not available"
} > "$RUN_DIR/metadata.txt" 2>&1

# -----------------------------------
# Loop pelos cenários
# -----------------------------------

for scenario_path in "$SCENARIOS_DIR"/*; do
    scenario_name=$(basename "$scenario_path")
    SCENARIO_DIR="$RUN_DIR/$scenario_name"

    echo "--------------------------------------------------"
    echo "▶ Executando cenário: $scenario_name"
    echo "--------------------------------------------------"

    mkdir -p "$SCENARIO_DIR"

    echo "🧹 Limpando cenário anterior (se existir)..."
    kubectl delete -f "$scenario_path" --ignore-not-found=true >/dev/null 2>&1 || true
    sleep 5

    echo "📦 Aplicando cenário..."
    kubectl apply -f "$scenario_path" > "$SCENARIO_DIR/apply.txt" 2>&1

    # Descobre namespace definido no YAML (fallback: default)
    NAMESPACE=$(grep -m1 "namespace:" "$scenario_path" | awk '{print $2}' || echo "default")
    NAMESPACE=${NAMESPACE:-default}

    echo "📍 Namespace detectado: $NAMESPACE" | tee "$SCENARIO_DIR/namespace.txt"

    echo "⏳ Aguardando estabilização..."
    sleep 20

    # -----------------------------------
    # Coleta estado bruto do cluster
    # -----------------------------------

    echo "📊 Coletando estado do cluster..."

    kubectl get all -n "$NAMESPACE" -o wide > "$SCENARIO_DIR/get-all.txt" 2>&1
    kubectl get events -n "$NAMESPACE" > "$SCENARIO_DIR/events.txt" 2>&1
    kubectl describe pods -n "$NAMESPACE" > "$SCENARIO_DIR/describe-pods.txt" 2>&1
    kubectl get pvc -n "$NAMESPACE" > "$SCENARIO_DIR/pvc.txt" 2>&1

    # -----------------------------------
    # Popeye
    # -----------------------------------

    echo "🔍 Executando Popeye..."

    popeye -n "$NAMESPACE" > "$SCENARIO_DIR/popeye.txt" 2>&1 || true
    popeye -n "$NAMESPACE" -o json > "$SCENARIO_DIR/popeye.json" 2>&1 || true

    # -----------------------------------
    # K8sGPT
    # -----------------------------------

    echo "🤖 Executando K8sGPT..."

    k8sgpt analyze -n "$NAMESPACE" --explain > "$SCENARIO_DIR/k8sgpt.txt" 2>&1 || true
    k8sgpt analyze -n "$NAMESPACE" --output json > "$SCENARIO_DIR/k8sgpt.json" 2>&1 || true

    echo "🧹 Limpando cenário após execução..."
    kubectl delete -f "$scenario_path" --ignore-not-found=true >/dev/null 2>&1 || true
    sleep 5

    echo "✅ Cenário $scenario_name finalizado."
    echo ""
done

echo "🎯 Experimento concluído."
echo "📁 Resultados disponíveis em: $RUN_DIR"

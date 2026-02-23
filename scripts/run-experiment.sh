#!/bin/bash
set -euo pipefail

SCENARIOS_DIR="./scenarios"
BASE_RESULTS_DIR="./results"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
RUN_DIR="$BASE_RESULTS_DIR/run-$TIMESTAMP"

mkdir -p "$RUN_DIR"

echo "🏥 Verificando saúde do Cluster..."
if ! kubectl get pods -n kube-system -l k8s-app=calico-node | grep Running > /dev/null; then
  echo "❌ ERRO CRÍTICO: Calico não parece estar rodando."
  echo "Por favor, rode o script cluster/setup-cluster.sh primeiro."
  exit 1
fi
echo "✅ Ambiente validado."

echo "🧪 Iniciando experimento"
echo "📁 Run: $RUN_DIR"

# -------------------------
# Metadata
# -------------------------
{
  echo "Run: $TIMESTAMP"
  echo "---"
  kubectl version --client
  echo "---"
  popeye version || echo "Popeye not found/error"
  echo "---"
  k8sgpt version || echo "K8sGPT not found/error"
} > "$RUN_DIR/metadata.txt" 2>&1

# -------------------------
# Loop cenários
# -------------------------

for scenario_path in "$SCENARIOS_DIR"/*; do
  
  # SEGURANÇA: Pula se não for um diretório (ignora arquivos soltos)
  if [ ! -d "$scenario_path" ]; then
    continue
  fi

  scenario_name=$(basename "$scenario_path")
  SCENARIO_RESULT="$RUN_DIR/$scenario_name"
  mkdir -p "$SCENARIO_RESULT"

  # Usa o nome da pasta como nome do namespace (ex: 01-image-error)
  NAMESPACE="$scenario_name"
  
  echo "------------------------------------------------"
  echo "▶ Cenário: $scenario_name"
  echo "📍 Namespace alvo: $NAMESPACE"

  # Garante limpeza prévia (force delete se estiver preso)
  kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true

  echo "📦 Criando namespace e aplicando recursos..."
  kubectl create namespace "$NAMESPACE"
  
  # AQUI ESTÁ O SEGREDO: O -n força tudo para dentro do namespace
  kubectl apply -n "$NAMESPACE" -f "$scenario_path" > "$SCENARIO_RESULT/apply.txt" 2>&1

  echo "⏳ Aguardando 15s para estabilização..."
  sleep 15

  # Estado real do cluster (Evidence)
  kubectl get all,events,pvc,networkpolicies -n "$NAMESPACE" -o wide > "$SCENARIO_RESULT/cluster-state.txt" 2>&1

  # Popeye (Saída JSON é a mais importante para análise de dados)
  echo "🔍 Rodando Popeye..."
  popeye -n "$NAMESPACE" -o json > "$SCENARIO_RESULT/popeye.json" 2>&1 || true
  # Salva também o relatório legível para leitura rápida humana
  popeye -n "$NAMESPACE" > "$SCENARIO_RESULT/popeye_report.txt" 2>&1 || true

  # K8sGPT
  echo "🤖 Rodando K8sGPT..."
  k8sgpt analyze -n "$NAMESPACE" --output json --no-cache > "$SCENARIO_RESULT/k8sgpt.json" 2>&1 || true
  # Salva explicação textual
  k8sgpt analyze -n "$NAMESPACE" --explain --no-cache > "$SCENARIO_RESULT/k8sgpt_explain.txt" 2>&1 || true

  echo "🧹 Limpando namespace..."
  # Deleta em background (&) para o script ser mais rápido, já que o próximo loop cria um namespace novo
  kubectl delete namespace "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 &
  
  echo "✅ $scenario_name finalizado"

done

# Espera os processos de background (deletes) terminarem
wait

echo ""
echo "🎯 Experimento concluído com sucesso."
echo "📂 Resultados em: $RUN_DIR"
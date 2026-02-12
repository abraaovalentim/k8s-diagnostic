# Análise Comparativa de Ferramentas de Diagnóstico Kubernetes: IA vs Regras

Este repositório contém os artefatos experimentais do Trabalho de Conclusão de Curso (TCC) de **Abraão Valentim de Araújo**.

O objetivo é comparar empiricamente a eficácia de ferramentas de diagnóstico automatizado para Kubernetes, contrastando abordagens baseadas em regras com abordagens baseadas em Inteligência Artificial.

---

# Objetivo do Estudo

Comparar a eficácia de:

- **Popeye** — análise estática baseada em regras
- **K8sGPT** — análise baseada em Large Language Models (LLM)

A comparação é realizada através de uma suíte controlada de cenários de falhas com diferentes níveis de complexidade.

---

# Metodologia Experimental

Cada cenário:

1. É aplicado em um cluster Kubernetes (Kind)
2. O estado do cluster é coletado
3. Popeye é executado
4. K8sGPT é executado
5. Resultados são armazenados automaticamente
6. O cenário é removido antes do próximo

Toda a execução é automatizada via script.

---

# Ferramentas Avaliadas

## 1. Popeye
- Linter baseado em regras
- Detecta violações de boas práticas
- Não utiliza IA

## 2. K8sGPT
- Ferramenta baseada em LLM
- Analisa eventos, pods, falhas e recursos
- Produz diagnóstico contextual em linguagem natural

---

# Suíte Experimental

A suíte contém 8 cenários organizados por categoria e complexidade crescente.

| ID | Cenário | Categoria | Complexidade |
|----|----------|------------|---------------|
| 01 | ImagePullBackOff | Erro Sintático | Baixa |
| 02 | Ausência de Limits | Boa Prática | Baixa |
| 03 | ConfigMap Inexistente | Configuração | Média |
| 04 | Service Selector Incorreto | Falha Lógica | Alta |
| 05 | NetworkPolicy Restritiva | Rede | Alta |
| 06 | CrashLoopBackOff | Execução | Média |
| 07 | RBAC Incorreto | Segurança | Alta |
| 08 | PVC Pending | Infraestrutura | Alta |

Cada cenário possui namespace isolado para garantir reprodutibilidade.

---

# Métricas de Avaliação

## 1. Taxa de Detecção (TD)
- 1 = Detectou corretamente
- 0 = Não detectou

## 2. Precisão do Diagnóstico (PD)
Escala 1–5

## 3. Acionabilidade da Solução (AS)
- 0 = Não sugere
- 1 = Parcial
- 2 = Clara e aplicável

## 4. Clareza da Explicação (CE)
Escala 1–5

---

# Como Executar o Experimento

## Pré-requisitos

- Docker
- Kind
- Kubectl
- Popeye
- K8sGPT configurado

---

## 1. Criar Cluster

```bash
sh cluster/setup-cluster.sh
```

---

## 2. Executar Experimento Completo

```bash
chmod +x run-experiment.sh
./run-experiment.sh
```
---
# OU
## 2. Aplicar os Cenários

```bash
kubectl apply -f scenarios/
```

---

## 3. Executar as Ferramentas

### Popeye
```bash
popeye -A
```

### K8sGPT
```bash
k8sgpt analyze --explain
```

---
# Em caso de aplicação do experimento completo
## Estrutura dos Resultados
```pgsql
results/
  run-YYYY-MM-DD_HH-MM-SS/
      metadata.txt
      scenario-01/
          apply.txt
          get-all.txt
          events.txt
          popeye.txt
          popeye.json
          k8sgpt.txt
          k8sgpt.json
```

# Reprodutibilidade

Todos os cenários são declarativos e podem ser reaplicados com:

```bash
kubectl delete -f scenarios/
kubectl apply -f scenarios/
```

---

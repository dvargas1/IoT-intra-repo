#!/bin/bash

set -e

# Função para imprimir mensagens com cores
print_message() {
    local message=$1
    local color=$2
    case $color in
        "green") echo -e "\033[0;32m${message}\033[0m" ;;
        "red") echo -e "\033[0;31m${message}\033[0m" ;;
        "yellow") echo -e "\033[0;33m${message}\033[0m" ;;
        *) echo "${message}" ;;
    esac
}

# Função para criar um namespace
create_namespace() {
    local namespace=$1
    if kubectl get namespace $namespace > /dev/null 2>&1; then
        print_message "Namespace '$namespace' já existe." "yellow"
    else
        kubectl create namespace $namespace
        print_message "Namespace '$namespace' criado com sucesso." "green"
    fi
}

# Criar cluster k3d
print_message "Criando cluster k3d..." "yellow"
k3d cluster create iot-cluster --servers 3 --agents 2 --port "80:80@loadbalancer" --port "443:443@loadbalancer"


# Criar namespaces
print_message "Criando namespaces..." "yellow"
create_namespace argocd
create_namespace dev

# Instalar ArgoCD
print_message "Instalando ArgoCD..." "yellow"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods do ArgoCD ficarem prontos
print_message "Aguardando pods do ArgoCD ficarem prontos..." "yellow"
sleep 10  # Espera inicial para garantir que os pods comecem a ser criados
kubectl wait --timeout=200s --for=condition=Ready -n argocd --all pod
print_message "Pods do ArgoCD prontos!!!" "green"

# Obter senha inicial do ArgoCD
print_message "Obtendo senha inicial do ArgoCD..." "yellow"
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)
print_message "ArgoCD initial-admin-password: ${ARGOCD_PASSWORD}" "red"

# Aplicando yamls das apps
print_message "Aplicando configuração do fliperama..." "yellow"
kubectl apply -f ../confs/fliperama-argo.yaml -n argocd

print_message "Aplicando configuração do wil-app..." "yellow"
kubectl apply -f ../confs/wil-argo.yaml -n argocd

print_message "Criando app para o ingress" "yellow"
kubectl apply -f ../confs/ingress-argo.yaml -n argocd

print_message "Setup concluído com sucesso!" "green"

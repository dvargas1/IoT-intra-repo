#!/bin/bash

set -e  # Exit on error

# Obter o diretório do script para caminhos relativos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Função para imprimir mensagens com cores
print_message() {
    local message=$1
    local color=$2
    case $color in
        "green") echo -e "\033[0;32m${message}\033[0m" ;;
        "red") echo -e "\033[0;31m${message}\033[0m" ;;
        "yellow") echo -e "\033[0;33m${message}\033[0m" ;;
        "blue") echo -e "\033[0;34m${message}\033[0m" ;;
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

# Função para aguardar pods estarem prontos
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    local label=${3:-""}

    print_message "Aguardando pods no namespace '$namespace' ficarem prontos..." "yellow"
    sleep 10  # Espera inicial

    # Aguarda apenas pods que NÃO estão em Completed/Succeeded (exclui Jobs finalizados)
    local wait_cmd="kubectl wait --timeout=${timeout}s --for=condition=Ready -n $namespace"

    if [ -n "$label" ]; then
        wait_cmd="$wait_cmd -l $label pod"
    else
        # Aguarda apenas pods que não são Jobs completados
        wait_cmd="$wait_cmd --field-selector=status.phase!=Succeeded --all pod"
    fi

    # Tentar aguardar, mas verificar se há pods primeiro
    if kubectl get pods -n $namespace 2>/dev/null | grep -q .; then
        if $wait_cmd 2>/dev/null; then
            print_message "Pods no namespace '$namespace' prontos!" "green"
            return 0
        else
            print_message "AVISO: Timeout aguardando pods em '$namespace'" "yellow"
            kubectl get pods -n $namespace
            return 1
        fi
    else
        print_message "AVISO: Nenhum pod encontrado no namespace '$namespace'" "yellow"
        return 1
    fi
}


# Main script
print_message "=== IoT Bonus - Setup do Ambiente ===" "blue"

# Criar cluster k3d
print_message "\n[1/8] Criando cluster k3d..." "yellow"
if k3d cluster list | grep -q iot-bonus; then
    print_message "Cluster iot-bonus já existe." "yellow"
else
    k3d cluster create iot-bonus --servers 3 --agents 2
    print_message "Cluster k3d criado!" "green"
fi

# Criar namespaces
print_message "\n[2/8] Criando namespaces..." "yellow"
create_namespace argocd
create_namespace dev
create_namespace gitlab

# Instalar ArgoCD
print_message "\n[3/8] Instalando ArgoCD..." "yellow"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
wait_for_pods argocd 300

# Instalar GitLab via Helm
print_message "\n[4/8] Instalando GitLab..." "yellow"
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
    --timeout 1200s \
    --values "$PROJECT_DIR/confs/gitlab.yaml" \
    -n gitlab

wait_for_pods gitlab 600

# Obter senhas
print_message "\n[5/8] Obtendo credenciais..." "yellow"

if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)
    print_message "ArgoCD Admin Password: ${ARGOCD_PASSWORD}" "red"
else
    print_message "AVISO: Secret do ArgoCD não encontrado" "yellow"
fi

if kubectl get secret gitlab-gitlab-initial-root-password -n gitlab >/dev/null 2>&1; then
    GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode)
    print_message "GitLab Root Password: ${GITLAB_PASSWORD}" "red"
else
    print_message "AVISO: Secret do GitLab não encontrado" "yellow"
fi

# Aplicar configurações do ArgoCD
print_message "\n[6/8] Aplicando configurações do ArgoCD..." "yellow"

print_message "Aplicando configuração do fliperama..." "blue"
kubectl apply -f "$PROJECT_DIR/confs/fliperama-argo.yaml" -n argocd

print_message "Aplicando configuração do wil-app..." "blue"
kubectl apply -f "$PROJECT_DIR/confs/wil-argo.yaml" -n argocd

print_message "Criando app para o ingress..." "blue"
kubectl apply -f "$PROJECT_DIR/confs/ingress-argo.yaml" -n argocd

print_message "Criando appProject para o gitlab..." "blue"
kubectl apply -f "$PROJECT_DIR/confs/appProject.yaml" -n argocd

# Aguardar aplicações do ArgoCD estarem criadas
print_message "\n[7/7] Aplicações do ArgoCD criadas com sucesso!" "green"
print_message "As aplicações estão configuradas mas precisam ser sincronizadas manualmente." "yellow"

# Resumo final
print_message "\n=== Setup da Infraestrutura Concluído! ===" "green"

print_message "\n=== PRÓXIMOS PASSOS (IMPORTANTE!) ===" "yellow"
print_message "\n1. Configure o GitOps:" "blue"
print_message "   a) Acesse o GitLab: http://gitlab.local:8181" "blue"
print_message "      User: root | Password: ${GITLAB_PASSWORD:-'<execute o comando abaixo>'}" "blue"
print_message "      kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath=\"{.data.password}\" | base64 --decode" "blue"
print_message "\n   b) Crie um Personal Access Token (Settings → Access Tokens)" "blue"
print_message "      Scopes: read_repository, write_repository" "blue"
print_message "\n   c) Crie o repositório 'projeto1' no GitLab" "blue"
print_message "\n   d) Adicione os manifestos K8s (deployment, service, ingress) ao repositório" "blue"
print_message "      Estrutura: projeto1/fliperama/, projeto1/wil-app/, projeto1/ingress/" "blue"

print_message "\n2. Configure o ArgoCD:" "blue"
print_message "   a) Acesse o ArgoCD: https://localhost:8080" "blue"
print_message "      User: admin | Password: ${ARGOCD_PASSWORD:-'<não obtido>'}" "blue"
print_message "      Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443" "yellow"
print_message "\n   b) Conecte o repositório GitLab (Settings → Repositories)" "blue"
print_message "      URL: http://gitlab-webservice-default.gitlab.svc:8181/root/projeto1.git" "blue"
print_message "      Username: root | Password: [TOKEN criado no passo 1b]" "blue"
print_message "      Skip TLS: ✓" "blue"
print_message "\n   c) Sincronize as aplicações (Applications → Sync)" "blue"

print_message "\n3. Configure o /etc/hosts:" "blue"
print_message "   Após as aplicações sincronizarem e o ingress ser criado, execute:" "blue"
print_message "   ./scripts/setup-hosts.sh" "green"

print_message "\n=== Aplicações estarão disponíveis em: ===" "blue"
print_message "  • http://fliperama.com" "blue"
print_message "  • http://wil-app.com" "blue"
print_message "  • http://gitlab.local" "blue"

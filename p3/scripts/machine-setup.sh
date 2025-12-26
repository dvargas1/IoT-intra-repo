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

# Atualizar pacotes
print_message "Atualizando pacotes..." "yellow"
apt-get update -y
print_message "Pacotes atualizados" "yellow"

# Instalar Docker
if ! command -v docker &> /dev/null; then
    print_message "Docker não encontrado, instalando..." "yellow"
    curl -fsSL https://get.docker.com/ | sh
    print_message "Docker instalado com sucesso." "green"
else
    print_message "Docker já está instalado." "green"
fi

# Instalar k3d
if ! command -v k3d &> /dev/null; then
    print_message "k3d não encontrado, instalando..." "yellow"
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
    print_message "k3d instalado com sucesso." "green"
else
    print_message "k3d já está instalado." "green"
fi

# Instalar kubectl
if ! command -v kubectl &> /dev/null; then
    print_message "kubectl não encontrado, instalando..." "yellow"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    mv kubectl /usr/local/bin
    chmod +x /usr/local/bin/kubectl
    print_message "kubectl instalado com sucesso." "green"
else
    print_message "kubectl já está instalado." "green"
fi

# Instalar k9s
if ! command -v k9s &> /dev/null; then
    print_message "k9s não encontrado, instalando..." "yellow"
    wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
    tar -xzf k9s_Linux_amd64.tar.gz -C /usr/local/bin k9s
    rm k9s_Linux_amd64.tar.gz
    chmod +x /usr/local/bin/k9s
    print_message "k9s instalado com sucesso." "green"
else
    print_message "k9s já está instalado." "green"
fi

print_message "Setup da máquina concluído com sucesso!" "green"

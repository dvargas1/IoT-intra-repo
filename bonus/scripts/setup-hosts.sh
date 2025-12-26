#!/bin/bash

set -e  # Exit on error

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

# Função para adicionar entradas no /etc/hosts
update_hosts_file() {
    print_message "Aguardando ingress estar pronto..." "yellow"

    # Aguardar o ingress ser criado
    local max_retries=30
    local count=0
    while [ $count -lt $max_retries ]; do
        if kubectl get ingress apps-ingress -n dev >/dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 2
        count=$((count + 1))
    done
    echo ""

    if [ $count -eq $max_retries ]; then
        print_message "ERRO: Ingress 'apps-ingress' não foi encontrado no namespace 'dev'" "red"
        print_message "Certifique-se que as aplicações do ArgoCD foram sincronizadas com sucesso." "yellow"
        return 1
    fi

    # Aguardar o IP do LoadBalancer
    print_message "Aguardando IP do ingress..." "yellow"
    count=0
    while [ $count -lt $max_retries ]; do
        IP=$(kubectl get ingress apps-ingress -n dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$IP" ]; then
            break
        fi
        echo -n "."
        sleep 2
        count=$((count + 1))
    done
    echo ""

    if [ -z "$IP" ]; then
        print_message "ERRO: Não foi possível obter o IP do Ingress." "red"
        print_message "Verifique se o ingress controller está funcionando corretamente." "yellow"
        return 1
    fi

    print_message "IP do Ingress: $IP" "green"
    print_message "Atualizando /etc/hosts..." "yellow"

    DOMAINS=("fliperama.com" "will-app.com")
    HOSTS_FILE="/etc/hosts"

    for DOMAIN in "${DOMAINS[@]}"; do
        if ! grep -q "$DOMAIN" "$HOSTS_FILE" 2>/dev/null; then
            print_message "Adicionando $IP $DOMAIN ao $HOSTS_FILE" "blue"
            echo "$IP $DOMAIN" | sudo tee -a "$HOSTS_FILE" > /dev/null
        else
            print_message "$DOMAIN já está presente em $HOSTS_FILE" "yellow"
        fi
    done

    print_message "/etc/hosts atualizado com sucesso!" "green"
}

# Main script
print_message "=== IoT Bonus - Configuração do /etc/hosts ===" "blue"
print_message "Este script configura o /etc/hosts para acessar as aplicações via domínio.\n" "yellow"

update_hosts_file

print_message "\n=== Configuração Concluída! ===" "green"
print_message "\nVocê pode acessar as aplicações em:" "blue"
print_message "  - http://fliperama.com" "blue"
print_message "  - http://will-app.com" "blue"

#!/bin/bash

echo "Atualizando lista de pacotes..."
sudo apt-get update -y -qq

echo "Instalando net-tools..."
sudo apt-get install -y net-tools -qq

echo "Instalando OpenSSH Server..."
sudo apt-get install -y openssh-server -qq

echo "Habilitando e iniciando o serviço SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

echo "Configurando regras UFW..."
sudo ufw allow ssh
sudo ufw allow 6443/tcp # Porta usada pelo K3s
sudo ufw enable

echo "Adicionando alias para kubectl..."
echo "alias k='kubectl'" >> /etc/profile.d/00-aliases.sh

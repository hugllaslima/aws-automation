#!/bin/bash

# Script profissional de preparação de EC2 Ubuntu para uso com pipeline Docker + AWS ECR
# Autor: Hugllas & GPT-5
# Data: 2025

set -euo pipefail

## Função para exibir cabeçalho
show_header() {
  clear
  echo "================================================="
  echo " SCRIPT DE PREPARAÇÃO DA INSTÂNCIA EC2 (UBUNTU)"
  echo "================================================="
  echo ""
}

## Função para configurar o fuso horário para São Paulo
configure_timezone() {
  echo "[1/5] Configurando timezone para America/Sao_Paulo (São Paulo)..."
  sudo timedatectl set-timezone America/Sao_Paulo
  echo "Timezone atual: $(timedatectl | grep 'Time zone')"
}

## Função para instalar Docker
install_docker() {
  echo "[2/5] Instalando Docker..."
  if ! command -v docker &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "Docker instalado com sucesso!"
  else
    echo "Docker já está instalado."
  fi
}

## Função para instalar AWS CLI
install_awscli() {
  echo "[3/5] Instalando AWS CLI..."
  if ! command -v aws &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y awscli
    echo "AWS CLI instalado com sucesso!"
  else
    echo "AWS CLI já está instalado."
  fi
}

## Função para adicionar usuário ao grupo Docker
add_user_to_docker_group() {
  echo "[4/5] Garantindo que o usuário '$USER' está no grupo docker..."
  if groups $USER | grep &>/dev/null '\bdocker\b'; then
    echo "Usuário já faz parte do grupo docker."
  else
    sudo usermod -aG docker $USER
    echo "Usuário adicionado ao grupo docker. (É necessário RELOGAR para efetivar)"
  fi
}

## Função para login opcional no ECR
ecr_login() {
  echo "[5/5] Login opcional no Amazon ECR"
  read -p "Deseja realizar login automático no Amazon ECR agora? [s/N]: " -r LOGIN_ECR
  if [[ "$LOGIN_ECR" =~ ^([sS][iI][mM]|[sS])$ ]]; then
    read -p "Informe a REGIÃO AWS (ex: us-east-1): " -r AWS_REGION
    read -p "Informe o ENDPOINT ECR (ex: 1234.dkr.ecr.us-east-1.amazonaws.com): " -r ECR_REPO
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
    echo "Login no ECR realizado!"
  else
    echo "Login no ECR não realizado. Pule para o próximo passo da pipeline por SSH."
  fi
}

## Função main para controlar o fluxo
main() {
  show_header

  read -p "Esse script vai PREPARAR esta EC2 para deploy (Docker, AWS CLI, TZ). Continuar? [s/N]: " -r CONT
  if [[ ! "$CONT" =~ ^([sS][iI][mM]|[sS])$ ]]; then
    echo "Cancelado pelo usuário. Nenhuma ação executada."
    exit 0
  fi

  configure_timezone
  install_docker
  install_awscli
  add_user_to_docker_group
  ecr_login

  echo ""
  echo "=============================================="
  echo "Setup concluído! Se adicionou usuário ao grupo docker, faça LOGOUT e LOGIN novamente."
  echo "Agora sua EC2 está pronta para deploy automático via pipeline!"
  echo "=============================================="
}

main

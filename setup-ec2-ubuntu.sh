#!/bin/bash
#
# setup-ec2-ubuntu.sh - Script de Configuracao de instãncia EC2
#
# - Autor....................: Hugllas RS Lima 
# - Data.....................: 2025-08-12
# - Versão...................: 1.0.0
#
# Etapas:
#    - $ ./ansible_config_host.sh
#        - {Função para exibir cabeçalho}
#        - {Testando a conexão com a Internet}
#        - {Função para configurar o fuso horário para São Paulo}
#        - {Instalando dependências}
#        - {Função para instalar Docker}
#        - {Função para instalar AWS CLI}
#        - {Função para adicionar usuário ao grupo Docker}
#        - {Função para login opcional no ECR}
#        - {Função main para controlar o fluxo}
#
# Histórico:
#    - v1.0.0 2025-08-12, Hugllas Lima
#        - Cabeçalho
#        - Discrição
#        - Funções
#
# Uso:
#   - sudo ./setup-ec2-ubuntu.sh 
#
# Licença: GPL-3.0
#

set -euo pipefail

## Função para exibir cabeçalho
show_header() {
  clear
  echo "================================================"
  echo " SCRIPT DE PREPARAÇÃO DA INSTÂNCIA EC2 (UBUNTU)"
  echo "================================================"
  echo ""
}

## Testando a conexão com a Internet
test_internet() {
  echo -n "Testando conectividade externa... "
  if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo "[ERRO] Sem acesso à internet. Interrompendo script."
    exit 1
  fi
  echo "OK"
}

## Função para configurar o fuso horário para São Paulo
configure_timezone() {
  echo "[1/5] Configurando timezone para America/Sao_Paulo (São Paulo)..."
  sudo timedatectl set-timezone America/Sao_Paulo
  echo "Timezone atual: $(timedatectl | grep 'Time zone')"
}

## Instalando dependências
install_dependencies() {
  echo "[2/6] Instalando dependências básicas (ca-certificates, curl, gnupg, unzip)..."
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release unzip
}

## Função para instalar Docker
install_docker_official() {
  echo "[3/6] Instalando Docker do repositório oficial..."
  if ! command -v docker &>/dev/null; then
    # Adiciona a chave GPG
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    # Adiciona o repo
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "Docker instalado com sucesso a partir do repositório oficial!"
  else
    echo "Docker já está instalado."
  fi
}

## Função para instalar AWS CLI
install_awscli() {
  echo "[4/6] Instalando AWS CLI pelo instalador oficial da Amazon..."
  if ! command -v aws &> /dev/null; then
    tmpdir=$(mktemp -d)
    cd "$tmpdir"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    cd -
    rm -rf "$tmpdir"
    if command -v aws &> /dev/null; then
      echo "AWS CLI v2 instalado com sucesso!"
    else
      echo "[ERRO] Não foi possível instalar o AWS CLI." >&2
      exit 1
    fi
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

  test_internet
  configure_timezone
  install_dependencies
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

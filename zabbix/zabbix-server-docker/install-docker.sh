#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root ou com sudo." >&2
    exit 1
fi

# Função para verificar e instalar em sistemas baseados em Debian/Ubuntu
install_on_debian() {
    echo "Detectado sistema Debian/Ubuntu. Preparando instalação do Docker..."
    
    ## Remover versões antigas
    echo "Removendo versões antigas do Docker..."
    apt-get remove docker docker-engine docker.io containerd runc -y
    
    ## Atualizar repositórios e instalar dependências
    echo "Instalando dependências..."
    apt-get update -y
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    ## Adicionar chave GPG do Docker
    echo "Configurando repositório do Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    ## Configurar repositório
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    ## Instalar Docker
    echo "Instalando Docker Engine..."
    apt-get update -y
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    echo "Docker instalado com sucesso!"
}

# Função para verificar e instalar em sistemas baseados em RHEL/CentOS
install_on_rhel() {
    echo "Detectado sistema RHEL/CentOS. Preparando instalação do Docker..."
    
    ## Remover versões antigas
    echo "Removendo versões antigas do Docker..."
    yum remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine
    
    ## Instalar dependências
    echo "Instalando dependências..."
    yum install -y yum-utils
    
    ## Configurar repositório
    echo "Configurando repositório do Docker..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    ## Instalar Docker
    echo "Instalando Docker Engine..."
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    ## Iniciar e habilitar serviço
    systemctl start docker
    systemctl enable docker
    
    echo "Docker instalado com sucesso!"
}

# Detectar distribuição
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    VERSION=$(lsb_release -sr)
else
    OS=$(uname -s)
    VERSION=$(uname -r)
fi

echo "Detectado sistema: $OS versão $VERSION"

# Instalar conforme a distribuição
case $OS in
    ubuntu|debian)
        install_on_debian
        ;;
    rhel|centos|fedora|rocky|almalinux)
        install_on_rhel
        ;;
    *)
        echo "Sistema operacional não suportado: $OS"
        exit 1
        ;;
esac

# Verificar instalação
echo "Verificando a instalação do Docker..."
docker --version
docker-compose --version

echo "Configurando usuário atual para usar Docker sem sudo..."
usermod -aG docker $SUDO_USER
echo "Recomenda-se fazer logout e login novamente para que as alterações tenham efeito."

echo "Instalação concluída com sucesso!"
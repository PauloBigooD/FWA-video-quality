#!/bin/bash

## Author:   Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br - Tel: +55 (84) 9 8808-0933
## GitHub:   https://github.com/PauloBigooD
## Linkedin: https://www.linkedin.com/in/paulo-eduardo-5a18b3174/

set -e

## Variável de escolha de opção
COMMAND="$1"
## Work directory path is the current directory
WORK_DIR=$PWD
REPO_OCUDU="https://gitlab.com/ocudu/ocudu.git"

DOCKER_CMD="docker compose"
[[ $# -eq 2 ]] && DOCKER_CMD="docker compose"

# Função para verificar se um pacote está instalado
function is_installed(){
    dpkg -l | grep -q "$1"
    }

# Função para instalar pacotes se não estiverem instalados
function install_package() {
    for package in "$@"; do
        if ! is_installed "$package"; then
            echo "Instalando $package..."
            sudo apt-get install -y "$package"
        else
            echo "$package já está instalado."
        fi
    done
    }

# Função para gerenciar performance mode
function performance_mode(){
    install_package "linux-image-lowlatency" "linux-headers-lowlatency"
    if grep -m 1 'vendor_id' /proc/cpuinfo | grep -q 'GenuineIntel'; then
        echo "========================================"
        echo "Intel CPU detectado. Configurando..."
        echo "========================================"
        sudo sed -i '/^GRUB_CMDLINE_LINUX=/d' /etc/default/grub
        echo 'GRUB_CMDLINE_LINUX="quiet intel_pstate=disable processor.max_cstate=1 intel_idle.max_cstate=0"' | sudo tee -a /etc/default/grub
        echo 'blacklist intel_powerclamp' | sudo tee -a /etc/modprobe.d/blacklist.conf
        echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
        sudo update-grub
        install_package "i7z"
        install_package "cpufrequtils"
        sudo systemctl restart cpufrequtils
    elif grep -m 1 'vendor_id' /proc/cpuinfo | grep -q 'AuthenticAMD'; then
        echo "========================================"
        echo "AMD CPU detectado. Configurando..."
        echo "========================================"
        sudo sed -i '/^GRUB_CMDLINE_LINUX=/d' /etc/default/grub
        echo 'GRUB_CMDLINE_LINUX="quiet amd_pstate=disable processor.max_cstate=1 idle=nomwait processor.max_cstate=0"' | sudo tee -a /etc/default/grub
        echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
        sudo update-grub
        install_package "cpufrequtils"
        sudo systemctl restart cpufrequtils
    else
        echo "CPU não identificada."
    fi
    }

# Função para verificar dispositivos USRP
function check_usrp_device(){
    echo "========================================"
    echo "Realizando a verificação da USRP"
    echo "========================================"
    uhd_find_devices 2>&1 | {
    skip=1  # Variável para controlar a primeira linha
    output=""

    while read -r line; do
        if [ $skip -eq 1 ]; then
            skip=0  # Ignora a primeira linha
            continue
        fi
        if echo "$line" | grep -q "No UHD Devices Found"; then
            echo "================================================================"
            echo "Verifique se a USRP encontra-se conectada a uma porta USB 3.0"
            echo "================================================================"
        fi
    done
    }
    uhd_find_devices
    echo "--------------------------------------------------"
    }

function init_performance(){
    ## Performance mode
	sudo /etc/init.d/cpufrequtils restart
    ## Configuration of the packer forwarding
	sudo sysctl net.ipv4.conf.all.forwarding=1
	sudo iptables -P FORWARD ACCEPT
    }

# Função para compilar e instalar UHD
function install_libuhd() {
    # Verifica se a UHD já está instalada
    if command -v uhd_find_devices &> /dev/null; then
        echo "========================================"
        echo "A biblioteca UHD já está instalada."
        echo "========================================"
        read -p "Deseja reinstalá-la? (s/n): " resposta
        case "$resposta" in
            [Ss]* )
                echo "Reinstalando a biblioteca UHD..."
                ;;
            [Nn]* )
                echo "Nenhuma ação será realizada."
                return 0
                ;;
            * )
                echo "Resposta inválida. Nenhuma ação será realizada."
                return 1
                ;;
        esac
    fi
    echo "========================================"
    echo "Removendo instalações anteriores..."
    echo "========================================"
    sudo rm -rf /usr/local/lib/cmake/uhd
    sudo rm -rf /usr/local/share/doc/uhd
    sudo rm -rf /usr/share/uhd
    sudo rm -rf /usr/share/doc/uhd
    sudo rm -rf /usr/lib/cmake/uhd
    sudo rm -rf ./uhd
    sudo rm -rf /usr/local/lib/uhd
    sudo rm -rf /usr/local/include/uhd
    sudo rm -rf /usr/local/share/uhd
    echo "==============================================================="
    echo "Escolha a versão da UHD para instalar (Recomendada - v4.6.0.0):"
    echo "==============================================================="
    for i in "${!VERSION_UHD[@]}"; do
        echo "$((i+1)). ${VERSION_UHD[i]}"
    done
    read -p "Digite o número correspondente à versão desejada: " escolha
    if [[ "$escolha" -ge 1 && "$escolha" -le "${#VERSION_UHD[@]}" ]]; then
        VERSAO_SELECIONADA="${VERSION_UHD[$((escolha-1))]}"
    else
        echo "Escolha inválida. Tente novamente."
        escolher_versao
    fi
    echo "========================================"
    echo "Instalando dependências..."
    echo "========================================"
    sudo apt-get update
    install_package "autoconf" "automake" "ccache" "build-essential" "cmake" "doxygen" "ethtool" "g++" "inetutils-tools" "libboost-all-dev" "libncurses5-dev" "libusb-1.0-0" "libusb-1.0-0-dev" "libusb-dev" "python3-dev" "python3-mako" "python3-numpy" "python3-requests" "python3-scipy" "python3-setuptools" "python3-ruamel.yaml"
    echo "Instalando UHD versão: $VERSAO_SELECIONADA"
    git clone --branch "$VERSAO_SELECIONADA" https://github.com/EttusResearch/uhd.git
    cd uhd/host || exit
    mkdir build
    cd build || exit
    cmake ../
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
    cd /usr/local/lib/uhd/utils/
    sudo ./uhd_images_downloader.py
    # Verificação da instalação
    echo "Verificando a instalação..."
    sudo uhd_find_devices
    sudo uhd_usrp_probe
    }

function install_RAN_ocudu(){
    echo "========================="
    echo "Instalando dependências OCUDU"
    echo "========================="
    install_package "cmake" \
                    "make" \
                    "gcc" \
                    "g++" \
                    "pkg-config" \
                    "libmbedtls-dev" \
                    "libsctp-dev" \
                    "libyaml-cpp-dev" \
                    "libgtest-dev" \
                    "libfftw3-dev" \
                    "build-essential" \
                    "python3-dev" \
                    "python3-dev" \
                    "python3-mako" \
                    "python3-numpy" \
                    "python3-requests" \
                    "python3-ruamel.yaml" \
                    "libusb-1.0-0-dev" \
                    "libboost-all-dev"
    performance_mode
    install_libuhd
    cd $WORK_DIR
    sudo rm -rf libzmq
    echo "========================="
    echo "Clonando libzmq"
    echo "========================="
    export CXXFLAGS="-Wno-stringop-overflow -Wno-error=stringop-overflow"
    git clone https://github.com/zeromq/libzmq.git
    cd libzmq
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ..
    sudo rm -rf czmq
    echo "========================="
    echo "Clonando czmq"
    echo "========================="
    git clone https://github.com/zeromq/czmq.git
    cd czmq
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo ldconfig
    cd $WORK_DIR || exit
    clone_ocudu
    sudo rm -rf build &>/dev/null
    mkdir build
    cd build
    echo "========================="
    echo "Build ocudu"
    echo "========================="
    sudo cmake ../
    sudo make -j $(nproc)
    #echo "========================="
    #echo "Realizando teste do build ocudu"
    #echo "========================="
    #sudo make test -j $(nproc)
    sudo make install
    echo "========================="
    echo "OCUDU instalado com sucesso!"
    echo "========================="
    }

function clone_ocudu(){
    cd $WORK_DIR || exit
    if [ -d "ocudu_Project" ]; then
        echo "====================================================="
        echo "Removendo diretório existente 'OCUDU'..."
        echo "====================================================="
        sudo rm -rf ocudu
    fi
    if [ ! -d "ocudu" ]; then
        echo "====================================================="
        echo "Clone OCUDU 5G RAN repository"
        echo "====================================================="
        git clone "$REPO_OCUDU"
        cd ocudu || exit
        echo "====================================================="
        echo "Clonado com sucesso!"
        echo "====================================================="
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

function start_ocudu_metrics(){
    echo "======================================="
    echo "Iniciando o coletor de metricas ocudu"
    echo "======================================="
    cd $WORK_DIR/utils_ocudu/docker/
    docker compose -f docker-compose.yaml up grafana influxdb metrics-server -d
    }

function stop_ocudu_metrics(){
    echo "======================================="
    echo "Encerrando o coletor de metricas ocudu"
    echo "======================================="
    cd $WORK_DIR/utils_ocudu/docker/
    docker compose -f docker-compose.yaml down grafana influxdb metrics-server
    }

function gNB_b106_bm_ocudu(){
    echo "======================================="
    echo "Iniciando gNB ocudu Baremetal" 
    echo "======================================="
    cd $WORK_DIR/utils_ocudu/
    ./gnb_up_b210_256QAM_MIMO_30Mhz.sh
    }

function gNB_ocudu_docker(){    
    validate_ip() {
        local ip=$1
        local valid_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        
        if [[ $ip =~ $valid_regex ]]; then
            # Divide o IP em octetos
            IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
            
            # Verifica se cada octeto está entre 0 e 255
            if [[ $o1 -le 255 && $o2 -le 255 && $o3 -le 255 && $o4 -le 255 ]]; then
                return 0
            fi
        fi
        return 1
    }
	
    echo "======================================="
    echo "Iniciando gNB ocudu docker" 
    echo "======================================="
    
        # Pergunta se quer configurar a macvlan
    echo "=========================="
    echo "Configuração da rede macvlan"
    echo "=========================="
    read -p "Deseja configurar a rede macvlan? (s/N): " CONFIG_MACVLAN
    
    if [[ $CONFIG_MACVLAN =~ ^[Ss]$ ]]; then
        echo "=========================="
        echo "Provisionando macvlan-dhcp"
        echo "=========================="
        read -p "Informe a subnet da rede local. Ex - 192.168.210.0/24: " SUBNET
        read -p "Informe o gateway da rede local. Ex - 192.168.210.1: " GATEWAY
        read -p "Informe a interface da rede. Ex - enp0s31f6: " PARENT

        echo "========================================"
        echo "Instalando com os seguintes parâmetros:"
        echo "Subnet: $SUBNET"
        echo "Gateway: $GATEWAY"
        echo "Interface: $PARENT"
        echo "========================================"

        if sudo docker network inspect macvlan-dhcp &>/dev/null; then
            sudo docker network rm macvlan-dhcp
        fi
        
        if ! sudo docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$PARENT macvlan-dhcp 2>/dev/null; then
            echo "Aviso: Não foi possível criar/reconfigurar a rede macvlan_net. Continuando mesmo assim..."
        fi
    else
        echo "========================================"
        echo "Pulando configuração da rede macvlan"
        echo "Verificando se a rede macvlan-dhcp já existe..."
        echo "========================================"
        
        # Verifica se a rede existe, se não existir, avisa mas continua
        if ! sudo docker network inspect macvlan-dhcp &>/dev/null; then
            echo "Aviso: A rede macvlan-dhcp não existe! O container pode não funcionar corretamente."
            echo "Você precisará criar a rede manualmente ou executar o script novamente escolhendo 's'"
        else
            echo "Rede macvlan-dhcp encontrada! Continuando..."
        fi
    fi

    echo "==================================="
    echo "Ajustando IP da gNB ocudu - Docker"
    echo "==================================="

    # Loop para validar o IP
    while true; do
        read -p "Informe o IP da gNB. Obs - IP na faixa da macvlan: " ocudu_IP
        
        if validate_ip "$ocudu_IP"; then
            echo "IP válido: $ocudu_IP"
            break
        else
            echo "========================================"
            echo "ERRO: IP inválido! '$ocudu_IP' não é um endereço IP válido."
            echo "O IP deve estar no formato: xxx.xxx.xxx.xxx"
            echo "Cada octeto deve ser um número entre 0 e 255."
            echo "Exemplos válidos: 192.168.210.231, 10.0.0.1, 172.31.0.154"
            echo "========================================"
        fi
    done
    echo "========================================"
    echo "gNB ocudu IP: $ocudu_IP"
    echo "========================================"

    # Atualiza o docker-compose da gNB
    COMPOSE_FILE="$WORK_DIR/utils_ocudu/docker/docker-compose.yaml"

    if [ -f "$COMPOSE_FILE" ]; then
        # Faz backup
        BACKUP_FILE="${COMPOSE_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$COMPOSE_FILE" "$BACKUP_FILE"
        echo "Backup criado: $BACKUP_FILE"
        
        # Verifica se o serviço gnb existe no arquivo
        if grep -q "^  gnb:" "$COMPOSE_FILE"; then
            # Substitui o IP apenas no serviço gnb
            # Procura pelo bloco gnb, depois por networks, macvlan-dhcp e ipv4_address
            sed -i "/^  gnb:/,/^  [a-z]/ {
                /networks:/,/^  [a-z]/ {
                    /macvlan-dhcp:/,/^      [a-z]/ {
                        s/ipv4_address: [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/ipv4_address: $ocudu_IP/
                    }
                }
            }" "$COMPOSE_FILE"
            
            echo "========================================"
            echo "Arquivo docker-compose.yaml atualizado!"
            echo "IP configurado: $ocudu_IP"
            
            # Mostra a linha alterada para confirmação
            echo "========================================"
            echo "Linha alterada:"
            grep -A2 -B2 "ipv4_address:" "$COMPOSE_FILE" | grep -E "(gnb:|ipv4_address:)"
            echo "========================================"
        else
            echo "ERRO: Serviço 'gnb' não encontrado no docker-compose.yaml"
            return 1
        fi
    else
        echo "ERRO: Arquivo docker-compose.yaml não encontrado em: $COMPOSE_FILE"
        return 1
    fi

    # 2. Atualiza o arquivo de configuração da gNB
    CONFIG_FILE="$WORK_DIR/utils_ocudu/gnb_conf_256QAM_SISO_30Mhz.yaml"

    if [ -f "$CONFIG_FILE" ]; then
        # Faz backup do arquivo de configuração
        BACKUP_CONFIG="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$BACKUP_CONFIG"
        echo "Backup da configuração criado: $BACKUP_CONFIG"
        
        # Substitui o bind_addr no bloco cu_cp
        sed -i "s/bind_addr: [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/bind_addr: $ocudu_IP/" "$CONFIG_FILE"
        
        echo "Arquivo de configuração atualizado! bind_addr configurado: $ocudu_IP"
        
        # Verifica se a alteração foi feita corretamente
        if grep -q "bind_addr: $ocudu_IP" "$CONFIG_FILE"; then
            echo "Configuração do bind_addr verificada com sucesso!"
        else
            echo "AVISO: Não foi possível verificar a alteração do bind_addr"
        fi
    else
        echo "ERRO: Arquivo de configuração não encontrado em: $CONFIG_FILE"
        return 1
    fi

    echo "========================================"
    echo "   IP da gNB configurado com sucesso!"
    echo "   Docker Compose: \${ocudu_IP:-$ocudu_IP}"
    echo "   Arquivo YAML: bind_addr: $ocudu_IP"
    echo "========================================"

    # Função auxiliar para executar comandos com segurança
    safe_run() {
        local cmd="$1"
        local error_msg="${2:-Comando falhou}"
        
        if ! eval "$cmd" 2>/dev/null; then
            echo "AVISO: $error_msg (continuando...)"
            return 1
        fi
        return 0
    }
    
    # Função auxiliar para verificar arquivos/diretórios
    check_required() {
        if [ ! -f "$1" ]; then
            echo "ERRO: Arquivo obrigatório não encontrado: $1"
            return 1
        fi
        return 0
    }
    
    # Executa operações não críticas (podem falhar)
    safe_run "docker rm -f ocudu_gnb" "Remoção do container"
    safe_run "rm $WORK_DIR/ocudu/docker/docker-compose.yaml" "Remoção do compose antigo"
    
    # Verifica arquivo obrigatório
    check_required "$WORK_DIR/utils_ocudu/docker/docker-compose.yaml" || return 1
    
    # Operações críticas (não podem falhar)
    cp "$WORK_DIR/utils_ocudu/docker/docker-compose.yaml" "$WORK_DIR/ocudu/docker/" || {
        echo "ERRO: Falha crítica ao copiar docker-compose.yaml"
        return 1
    }
    
    cd "$WORK_DIR/ocudu/docker" || {
        echo "ERRO: Falha crítica ao acessar diretório"
        return 1
    }
    
    # Preparação do log
    safe_run "sudo rm -f /tmp/gnb.log" "Remoção do log antigo"
    sudo touch /tmp/gnb.log || {
        echo "ERRO: Falha ao criar /tmp/gnb.log"
        return 1
    }
    safe_run "sudo chmod 666 /tmp/gnb.log" "Permissão do arquivo de log"
    
    # Inicia container
    docker compose -f docker-compose.yaml up -d || {
        echo "ERRO: Falha ao iniciar o container"
        return 1
    }
    
    echo "Container ocudu_gnb iniciado com sucesso!"
    echo "======================================="
    echo "Acompanhando logs (Ctrl+C para sair):"
    
    docker logs -f ocudu_gnb || {
        echo "AVISO: Container pode estar rodando, mas falha ao mostrar logs"
        return 0
    }
}

function logs_gNB_ocudu_docker(){
    echo "======================================="
    echo "Logs gNB ocudu"
    echo "======================================="
    sudo docker logs -f ocudu_gnb
    }

function stop_gNB_ocudu_docker(){
    echo "======================================="
    echo "Encerrando gNB ocudu"
    echo "======================================="
    cd $WORK_DIR/utils_ocudu/docker
    docker compose -f docker-compose.yaml down
    }
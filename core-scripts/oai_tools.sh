#!/bin/bash

## Author:   Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br - Tel: +55 (84) 9 8808-0933
## GitHub:   https://github.com/PauloBigooD
## Linkedin: https://www.linkedin.com/in/paulo-eduardo-5a18b3174/

set -e

## Variável de escolha de opção
COMMAND="$1"
## Work directory path is the current directory
WORK_DIR=$PWD
## Lista de versões disponíveis
VERSION_UHD=("UHD-4.7" "UHD-4.6" "UHD-4.5" "UHD-4.4" "UHD-4.3" "UHD-4.2" "UHD-4.1")
## Definindo o URL do repositório OAI - RAN
REPO_OAI_RAN="https://gitlab.eurecom.fr/oai/openairinterface5g.git"
REPO_SRS_RAN="https://github.com/srsran/srsRAN_Project.git"
REPO_OCUDU="https://gitlab.com/ocudu/ocudu.git"
VERSION_SRS_RAN="release_24_10"
## Versão da branch OAI - RAN
VERSION_RAN="2024.w42" #"develop"
## Definindo o URL do repositório OAI - CORE
REPO_OAI_CORE="https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed.git"
## Versão da imagem Docker
DOCKER_IMAGE_OAI="v1.5.0"
## Interface de rede
INTERFACE_PC="enp3s"

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

# Função que verifica acionamento da dashboard OAI
function dashboard_check(){
    # Condição que verifica o uso da Dashboard
    if [ "$2" = "-d" ];then
        dash="$2"
        echo -e "Dashboard \e[92mON\e[0m"
    elif [[ "$2" == -* ]];then
        dash=" "
        echo -e "Parâmetro inválido, este deve ser igual a \e[33m-d\e[0m"
    else
        dash=" "
        echo -e "Dashboard \e[31mOFF\e[0m"
    fi
    }

# Função que instala o modo performance
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

# Função que instala o Docker (Ubuntu/Debian e derivados)
function install_docker() {
    if is_installed docker; then
        echo "Docker já instalado."
        return 0
    fi
    echo "========================================"
    echo "Instalando Docker..."
    echo "========================================"

    # Instalar dependências necessárias
    install_package \
        "ca-certificates" \
        "curl" \
        "gnupg" \
        "lsb-release" \
        "python3-pip"

    # Detectar distribuição e codename
    DISTRO=$(lsb_release -si)
    CODENAME=$(lsb_release -cs)
    ARCH=$(dpkg --print-architecture)

    # Criar diretório para armazenar a chave GPG
    sudo mkdir -p /etc/apt/keyrings

    # Remover chaves e repositórios antigos (evita conflitos)
    sudo rm -f /etc/apt/keyrings/docker.asc
    sudo rm -f /etc/apt/keyrings/docker.gpg
    sudo rm -f /etc/apt/sources.list.d/docker.list

    # Baixar e converter a chave GPG para o formato correto
    if [[ "$DISTRO" == "Ubuntu" ]]; then
        echo "====================================================="
        echo "Distribuição Ubuntu detectada."
        echo "====================================================="
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
        "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    elif [[ "$DISTRO" == "Debian" ]]; then
        echo "====================================================="
        echo "Distribuição Debian detectada."
        echo "====================================================="
        curl -fsSL https://download.docker.com/linux/debian/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
        "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian ${CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    elif [[ "$DISTRO" == "CentOS" || "$DISTRO" == "RHEL" || "$DISTRO" == "Fedora" ]]; then
        echo "====================================================="
        echo "Distribuição baseada em RedHat detectada."
        echo "====================================================="
        curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo \
            | sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null

        sudo yum install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin

        sudo systemctl enable --now docker
        sudo usermod -aG docker "$USER"

        # Instala docker-compose legado (opcional)
        sudo pip3 install docker-compose
        echo "====================================================="
        echo "Docker instalado com sucesso."
        echo "====================================================="
        echo "Faça logout e login novamente para usar Docker sem sudo."
        return 0
    else
        echo "Distribuição não suportada para instalação automatizada."
        return 1
    fi

    # Ajustar permissões da chave
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Limpar cache e atualizar repositórios
    sudo apt-get clean
    sudo apt-get update

    # Instalar Docker
    install_package \
        "docker-ce" \
        "docker-ce-cli" \
        "containerd.io" \
        "docker-buildx-plugin" \
        "docker-compose-plugin"

    # Habilitar e iniciar o serviço
    sudo systemctl enable --now docker

    # Adicionar usuário atual ao grupo docker
    sudo usermod -aG docker "$USER"

    echo "Docker instalado com sucesso."
    echo "Faça logout e login novamente para usar Docker sem sudo."

    # Login opcional
    docker login
}
# Função que clona o repositorio da RAN do oai
function clone_repo_RAN(){
    cd $WORK_DIR || exit
    if [ -d "openairinterface5g" ]; then
        echo "====================================================="
        echo "Removendo diretório existente 'openairinterface5g'..."
        echo "====================================================="
        sudo rm -rf openairinterface5g
    fi
    if [ ! -d "openairinterface5g" ]; then
        echo "====================================================="
        echo "Clone OpenAirInterface 4G/5G RAN repository"
        echo "====================================================="
        git clone "$REPO_OAI_RAN"
        cd openairinterface5g || exit
        echo "====================================================="
        echo "git checkout $VERSION_RAN"
        echo "====================================================="
        git checkout $VERSION_RAN
        git submodule update --init --recursive
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

function clone_srs_RAN(){
    cd $WORK_DIR || exit
    if [ -d "srsRAN_Project" ]; then
        echo "====================================================="
        echo "Removendo diretório existente 'srsRAN_Project'..."
        echo "====================================================="
        sudo rm -rf srsRAN_Project
    fi
    if [ ! -d "srsRAN_Project" ]; then
        echo "====================================================="
        echo "Clone srsRAN_Project 5G RAN repository"
        echo "====================================================="
        git clone "$REPO_SRS_RAN"
        cd srsRAN_Project || exit
        echo "====================================================="
        echo "git checkout $VERSION_SRS_RAN"
        echo "====================================================="
        git checkout $VERSION_SRS_RAN
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

# Função que clona repositorio do CORE do 
function clone_REPO_OAI_CORE(){
    if [ -d "oai-cn5g-fed" ]; then
        echo "====================================================="
        echo "Removendo o diretório existente ' oai-cn5g-fed'..."
        echo "====================================================="
        sudo rm -rf  oai-cn5g-fed
    fi
    if [ ! -d "oai-cn5g-fed" ]; then
        echo "====================================================="
        echo "Clone OpenAirInterface 5G Core repository"
        echo "====================================================="
        git clone "$REPO_OAI_CORE"
        cd oai-cn5g-fed || exit
        git checkout -f $DOCKER_IMAGE_OAI
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

# Função para configurar e compilar a RAN do OpenAirInterface
function build_oai_RAN(){
    echo "==========================================="
    echo "Install OAI dependencies and Build OAI RAN"
    echo "==========================================="
    cd $WORK_DIR || exit
    cd openairinterface5g || exit
    source oaienv
    cd cmake_targets || exit
    sudo ./build_oai -I
    sudo ./build_oai -I --install-optional-packages
    sudo ./build_oai -w USRP --ninja --build-e2 --gNB --eNB --nrUE -C --build-lib "uescope nrscope enbscope telnetsrv"
    }

# Função que realiza o deploy da RAN e CORE do OAI
function start_5g_oai_mono(){
    echo "============================"
    echo "Iniciando 5GC local Docker"
    echo "============================"
    init_performance
    stop_5g_oai
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.core.wmem_max=33554432
    sudo sysctl -w net.core.rmem_max=33554432
    sudo sysctl -w net.core.wmem_default=33554432
    sudo sysctl -w net.core.rmem_default=33554432
    cd $WORK_DIR/core-scripts || exit
    sudo python3 core-network.py --type start-basic --scenario 1
    sleep 20
    docker ps -a
    echo "Exibindo logs do 5G Core..."
    sudo docker logs -f oai-amf
    }

# Função que realiza o deploy da RAN e CORE do OAI
function start_5g_oai_dist(){
    echo "============================"
    echo "Iniciando 5GC local Docker"
    echo "============================"
    stop_5g_oai
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.core.wmem_max=33554432
    sudo sysctl -w net.core.rmem_max=33554432
    sudo sysctl -w net.core.wmem_default=33554432
    sudo sysctl -w net.core.rmem_default=33554432
    cd $WORK_DIR/core-scripts || exit
    sudo sudo docker compose -f docker-compose-basic-nrf-macvlan.yaml up -d
    docker ps -a
    }

# Função para realizar pull imagens docker 5G
function pull_docker_5g(){
    echo "===================================="
    echo "Pulling the images from Docker Hub"  
    echo "====================================" 
    ## Pulling the images from Docker Hub
    sudo docker pull oaisoftwarealliance/oai-amf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-nrf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-smf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-udr:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-udm:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-ausf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-spgwu-tiny:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/trf-gen-cn5g:latest
    ## Tag Docker Images
    sudo docker image tag oaisoftwarealliance/trf-gen-cn5g:latest trf-gen-cn5g:latest
    sudo docker image tag oaisoftwarealliance/oai-amf:$DOCKER_IMAGE_OAI oai-amf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-nrf:$DOCKER_IMAGE_OAI oai-nrf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-smf:$DOCKER_IMAGE_OAI oai-smf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-udr:$DOCKER_IMAGE_OAI oai-udr:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-udm:$DOCKER_IMAGE_OAI oai-udm:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-ausf:$DOCKER_IMAGE_OAI oai-ausf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-spgwu-tiny:$DOCKER_IMAGE_OAI oai-spgwu-tiny:$DOCKER_IMAGE_OAI
    }

# Função que pausa o 5G OAI
function stop_5g_oai(){
    echo "============================"
    echo "Encerrando 5GC Docker"
    echo "============================"
    cd $WORK_DIR/core-scripts
    sudo docker rm -f rfsim5g-oai-gnb
    sudo python3 core-network.py --type stop-basic
    }

# Função que gera o log do AMF 5G OAI
function logs_5g_oai() {
    ## Verifica se o contêiner 5G Core está em execução
    if sudo docker inspect -f '{{.State.Running}}' oai-amf | grep true > /dev/null; then
        ## Exibe os logs do 5G Core
        echo "============================"
        echo "Exibindo logs do 5G Core..."
        echo "============================"
        sudo docker logs -f oai-amf
    else
        ## Exibe mensagem se o 5G Core não estiver em execução
        echo "O 5G Core não está em execução. Por favor, selecione a opção 6 do menu para iniciar o Core 5G."
    fi
    }

# Função para checar mcc, mnc e IP do arquivo de configuração da gNB
function chek_gNB_conf(){
    #check_usrp_device
    if [ "$4" = "docker" ]; then
        sudo docker rm -f rfsim5g-oai-gnb
        sudo docker rm -f oai-gnb oai-gnb-2 
        cd "$WORK_DIR" || exit
        ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-"$1""$2"-PRB"$3""$5".yaml up -d
        docker logs -f rfsim5g-oai-gnb
    else
        cd openairinterface5g/cmake_targets/ran_build/build/
        # Iniciar o softmodem
        #sudo ./nr-softmodem -E --sa -O ../../../../conf/${1}${2}PRB${3}_bm${5}.conf --gNBs.[0].min_rxtxtime 6 --continuous-tx $dash
	sudo ./nr-softmodem -E -O ../../../../conf/${1}${2}PRB${3}_bm${5}.conf --gNBs.[0].min_rxtxtime 6 --continuous-tx
    fi
    }

function start_nearRT-RIC(){
    cd flexric
    ./build/examples/ric/nearRT-RIC
    }

function start_E2Agent(){
    cd flexric
    ./build/examples/emulator/agent/emu_agent_gnb
    }

function start_gNB_rfsim_docker(){
    echo "============================"
    echo "Encerrando gNB rfSIM Docker"
    echo "============================"
    cd "$WORK_DIR" || exit
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml down
    echo "============================"
    echo "Iniciando gNB rfSIM Docker"
    echo "============================"
    mkdir -p "$PWD/openairinterface5g/cmake_targets/ran_build/build"
    sudo touch "$PWD/openairinterface5g/cmake_targets/ran_build/build/nrMAC_docker_stats.log"
    sudo touch "$PWD/openairinterface5g/cmake_targets/ran_build/build/nrRRC_docker_stats.log"
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml up -d
    docker logs -f rfsim5g-oai-gnb
    }

function start_gNB_rfsim(){
    echo "==============================="
    echo "Iniciando gNB rfSIM Baremetal"
    echo "==============================="
    cd openairinterface5g/cmake_targets/ran_build/build/
    # Iniciar o softmodem
    sudo ./nr-softmodem -O ../../../../conf/b210PRB106_rfsim_bm.conf -E --gNBs.[0].min_rxtxtime 6 --rfsimulator server --rfsim
    #sudo ./nr-softmodem --rfsimulator server --rfsim --sa -O ../../../../conf/b210PRB106_rfsim_bm.conf --continuous-tx --gNBs.[0].min_rxtxtime 6 
    }

function logs_gNB_rfsim_docker(){
    sudo docker logs -f rfsim5g-oai-gnb
    }
    
function stop_gNB_rfsim_docker(){
    cd "$WORK_DIR" || exit
    echo "=============================="
    echo "Encerrando gNB rfSIM Docker"
    echo "=============================="
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml down   
    }


function start_UE_rfsim(){
    echo "==============================="
    echo "Iniciando UE rfSIM Baremetal"
    echo "==============================="

    read -rp "Informe o IP da gNB: " GNB_IP

    cd openairinterface5g/cmake_targets/ran_build/build/ || return 1

    sudo ./nr-uesoftmodem \
        --rfsimulator.serveraddr $GNB_IP \
        -r 106 \
        --numerology 1 \
        --band 78 \
        -C 3619200000 \
        --rfsim \
        --sa \
        -O ../../../../conf/ue.conf
}

function start_UE_rfsim_docker(){
    echo "============================"
    echo "Encerrando UE rfSIM Docker"
    echo "============================"
    cd "$WORK_DIR" || exit
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-ue.yaml down
    echo "============================"
    echo "Iniciando UE rfSIM Docker"
    echo "============================"
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-ue.yaml up -d
    #docker logs -f rfsim5g-oai-ue
    }

function stop_UE_rfsim_docker(){
    echo "============================"
    echo "Encerrando UE rfSIM Docker"
    echo "============================"
    cd "$WORK_DIR" || exit
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-ue.yaml down
    }

function FlexRIC() {
    echo "================================================"
    echo "Instalando dependências do FlexRIC"
    echo "================================================"
    sudo apt-get update
    install_package "automake" "g++" "make" "libpcre2-dev" "byacc" "cmake" "python3-dev" "libsctp-dev" "bison" "libconfig-dev" "cmake-curses-gui" "pkg-config" "libconfig++-dev"
    cd $WORK_DIR || exit
    if [ -d "swig" ]; then
        echo "========================================"
        echo "Removendo diretório existente 'swig'..."
        echo "========================================"
        sudo rm -rf swig
    fi
    if [ ! -d "swig" ]; then
    echo "================================================"
    echo "Instalando SWIG"
    echo "================================================"
    git clone https://github.com/swig/swig.git
    cd "$WORK_DIR"/swig || { echo "Erro ao acessar o diretório swig"; exit 1; }
    git checkout release-4.1
    ./autogen.sh || { echo "Erro no autogen.sh do SWIG"; exit 1; }
    ./configure --prefix=/usr/ || { echo "Erro na configuração do SWIG"; exit 1; }
    make -j8 || { echo "Erro ao compilar SWIG"; exit 1; }
    sudo make install || { echo "Erro ao instalar SWIG"; exit 1; }
    cd $WORK_DIR || exit
    else
        echo "==========================================="
        echo "Erro: Não foi possível remover o diretório."
        echo "==========================================="
    fi

    if [ -d "flexric" ]; then
        echo "[INFO] Removendo FlexRIC antigo..."
        sudo rm -rf flexric
    fi

    echo "============================================"
    echo "  Escolha a branch do FlexRIC"
    echo "============================================"
    echo "1) 37e85a00 (OAI compatível)"
    echo "2) dev       (OAI compatível)"
    echo "3) br-flexric (srsRAN compatível)"
    read -p "Selecione [1-3]: " BRANCH_OPT

    case $BRANCH_OPT in
        1) FLEXRIC_BRANCH="37e85a00" ;;
        2) FLEXRIC_BRANCH="dev" ;;
        3) FLEXRIC_BRANCH="br-flexric" ;;
        *)
            echo "Opção inválida. Abortando."
            return 1
            ;;
    esac   
    echo "================================================"
    echo "[INFO] Clonando FlexRIC branch: $FLEXRIC_BRANCH"
    echo "================================================"
    git clone https://gitlab.eurecom.fr/mosaic5g/flexric.git
    cd flexric || exit 1
    git checkout "$FLEXRIC_BRANCH"

    ############################################
    # xAPP COPY LOGIC
    ############################################
    rm -f examples/xApp/c/monitor/CMakeLists.txt
    echo "================================================"
    echo "[INFO] Copiando xApp MONITOR"
    echo "================================================"

    if [[ "$FLEXRIC_BRANCH" == "37e85a00" || "$FLEXRIC_BRANCH" == "dev" ]]; then
        echo "[INFO] xApp para OAI"
        cp -f $WORK_DIR/xApp/flexRIC/oai/* examples/xApp/c/monitor/
        mkdir -p build
        cd build || { echo "Erro ao acessar diretório build"; exit 1; }
        cmake -DSWIG_EXECUTABLE=/usr/bin/swig .. || { echo "Erro no comando cmake"; exit 1; }
        make -j8 || { echo "Erro ao compilar FlexRIC"; exit 1; }
        sudo make install || { echo "Erro ao instalar FlexRIC"; exit 1; }

    elif [[ "$FLEXRIC_BRANCH" == "br-flexric" ]]; then
        echo "[INFO] xApp para srsRAN"
        cp -f $WORK_DIR/xApp/flexRIC/srsRAN/* examples/xApp/c/monitor/
        mkdir build
        export LibConfig_INCLUDE_DIR=/usr/include
        export LibConfig_LIBRARY=/usr/lib/x86_64-linux-gnu/libconfig.so
        cd build || { echo "Erro ao acessar diretório build"; exit 1; }
        cmake -DKPM_VERSION=KPM_V3_00 -DXAPP_DB=NONE_XAPP -DSWIG_EXECUTABLE=/usr/bin/swig ../ || { echo "Erro no comando cmake"; exit 1; }
        make || { echo "Erro ao compilar FlexRIC"; exit 1; }
        sudo make install || { echo "Erro ao instalar FlexRIC"; exit 1; }
    fi

    if type clone_repo_RAN >/dev/null 2>&1; then
        clone_repo_RAN
    else
        echo "Função clone_repo_RAN não encontrada. Certifique-se de que está definida."
    fi
    # Chamada para build_oai_RAN (necessário definir antes de usar)
    if type build_oai_RAN >/dev/null 2>&1; then
        build_oai_RAN
    else
        echo "Função build_oai_RAN não encontrada. Certifique-se de que está definida."
    fi
    }

function xApps(){
    while true; do
        echo -e "
        --------------------------------------------------------------------------------------------------------------------------------------------------
        | 1 - xapp_kpm_moni               <-> Start the KPM monitor xApp - measurements stated in 2.1.1 E2SM-KPM.                                        |
        | 2 - xapp_rc_moni                <-> Start the RC monitor xApp - aperiodic subscription for UE RRC State Change.                                |
        | 3 - xapp_kpm_rc                 <-> Start the RC control xApp - RAN control function QoS flow mapping configuration (e.g. creating a new DRB). |
        | 4 - xapp_gtp_mac_rlc_pdcp_moni  <-> Start the (MAC + RLC + PDCP + GTP) monitor xApp.                                                           |
        | 5 - xappMON_RAN_OAI             <-> Collect the E2SMs capabilities E2 Node OAI                                                                 |
        | 6 - xappMON_RAN_srsRAN          <-> Collect the E2SMs capabilities E2 Node OAI                                                                 |
        --------------------------------------------------------------------------------------------------------------------------------------------------
        "
    read -p "Escolha uma opção para deploy: " escolha
    case $escolha in
        1) ./flexric/build/examples/xApp/c/monitor/xapp_kpm_moni ;;
        2) ./flexric/build/examples/xApp/c/monitor/xapp_rc_moni ;;
        3) ./flexric/build/examples/xApp/c/kpm_rc/xapp_kpm_rc ;;
        4) ./flexric/build/examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni ;;
        5) ./flexric/build/examples/xApp/c/monitor/xappMON ;;
        6) ./flexric/build/examples/xApp/c/monitor/xappMON_srs ;;
        *) echo "Opção inválida! Tente novamente." ;;
        esac
        echo ""
    done    
    }

function startZabbix(){
    cd zabbix/zabbix-server-docker/
    docker compose up -d
    }

function stopZabbix(){
    cd zabbix/zabbix-server-docker/
    docker compose down
    }

function installZabbix(){
    cd zabbix/zabbix-agent/ || return

    echo "=========================================="
    echo "Instalação do coletor de KPIs Zabbix Agent"
    echo "=========================================="

    read -p "Informe o hostname: " HOSTNAME
    read -p "Informe o IP do Zabbix Server: " SERVER
    read -p "Informe o metadata (ex: O-RAN): " METADATA

    echo ""
    echo "Instalando com os seguintes parâmetros:"
    echo "Hostname: $HOSTNAME"
    echo "Server: $SERVER"
    echo "Metadata: $METADATA"
    echo ""

    sudo ./install_zabbix_agent2.sh \
        --hostname "$HOSTNAME" \
        --server "$SERVER" \
        --metadata "$METADATA"
    
    sudo usermod -aG sudo zabbix
}

function install_scRIC(){
    sudo rm -rf oran-sc-ric
    echo "Instalando dependências do O-RAN SC RIC"
    git clone https://github.com/srsran/oran-sc-ric
    cd ./oran-sc-ric
    echo "Copiando xAppMON"
    cp $WORK_DIR/xApp/scRIC/xappMON-SC.py ./xApps/python/
    }

function start_scRIC(){
    echo "========================="
    echo "Iniciando O-RAN SC RIC"
    echo "========================="
    cd ./oran-sc-ric
    docker compose up -d
    }

function logs_scRIC(){
    echo "========================="
    echo "Logs SC-RIC"
    echo "========================="
    cd ./oran-sc-ric
    docker compose logs -f
    }

function stop_scRIC(){
    echo "========================="
    echo "Encerrando SC-RIC"
    echo "========================="
    cd ./oran-sc-ric
    docker compose down
    }

function start_video(){
    echo "========================="
    echo "Iniciando Video-Server"
    echo "========================="
    cd $WORK_DIR/open5GS
    docker compose --env-file open5gs/open5gs.env -f docker-compose-macvlan.yml up -d video-server
    }

function stop_video(){
    echo "========================="
    echo "Encerrando Video-Server"
    echo "========================="
    cd $WORK_DIR/open5GS
    docker compose --env-file open5gs/open5gs.env -f docker-compose-macvlan.yml down video-server
    }


function start_Open5GS(){
    cd ./open5GS
    
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.core.wmem_max=33554432
    sudo sysctl -w net.core.rmem_max=33554432
    sudo sysctl -w net.core.wmem_default=33554432
    sudo sysctl -w net.core.rmem_default=33554432
    
    # Função para validar IP
    validate_ip() {
        local ip=$1
        local valid_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
        
        if [[ $ip =~ $valid_regex ]]; then
            IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
            if [[ $o1 -le 255 && $o2 -le 255 && $o3 -le 255 && $o4 -le 255 ]]; then
                return 0
            fi
        fi
        return 1
    }
    
    # Função para validar subnet
    validate_subnet() {
        local subnet=$1
        local cidr_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$'
        
        if [[ $subnet =~ $cidr_regex ]]; then
            local ip=${subnet%/*}
            if validate_ip "$ip"; then
                return 0
            fi
        fi
        return 1
    }
    
    # Função genérica para ler e validar IP
    read_ip() {
        local prompt="$1"
        local ip=""
        
        while true; do
            read -p "$prompt" ip
            if validate_ip "$ip"; then
                echo "$ip"
                return 0
            else
                echo "========================================"
                echo "ERRO: IP inválido! Formato esperado: xxx.xxx.xxx.xxx"
                echo "Cada octeto deve ser um número entre 0 e 255."
                echo "========================================"
            fi
        done
    }
    
    # Função genérica para ler e validar subnet
    read_subnet() {
        local prompt="$1"
        local subnet=""
        
        while true; do
            read -p "$prompt" subnet
            if validate_subnet "$subnet"; then
                echo "$subnet"
                return 0
            else
                echo "========================================"
                echo "ERRO: Subnet inválida! Formato esperado: xxx.xxx.xxx.xxx/xx"
                echo "Exemplos: 192.168.210.0/24, 10.0.0.0/8"
                echo "========================================"
            fi
        done
    }
    
    # Pergunta se quer configurar a macvlan
    echo "=========================="
    echo "Configuração da rede macvlan"
    echo "=========================="
    read -p "Deseja configurar a rede macvlan? (s/N): " CONFIG_MACVLAN
    
    if [[ $CONFIG_MACVLAN =~ ^[Ss]$ ]]; then
        echo "=========================="
        echo "Provisionando macvlan_net"
        echo "=========================="
        
        SUBNET=$(read_subnet "Informe a subnet da rede local. Ex - 192.168.210.0/24: ")
        GATEWAY=$(read_ip "Informe o gateway da rede local. Ex - 192.168.210.1: ")
        read -p "Informe a interface da rede. Ex - enp0s31f6: " PARENT

        echo "========================================"
        echo "Instalando com os seguintes parâmetros:"
        echo "Subnet: $SUBNET"
        echo "Gateway: $GATEWAY"
        echo "Interface: $PARENT"
        echo "========================================"

        if sudo docker network inspect macvlan_net &>/dev/null; then
            sudo docker network rm macvlan_net
        fi
        
        if ! sudo docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$PARENT macvlan_net 2>/dev/null; then
            echo "Aviso: Não foi possível criar/reconfigurar a rede macvlan_net. Continuando mesmo assim..."
        fi
    else
        echo "========================================"
        echo "Pulando configuração da rede macvlan"
        echo "Verificando se a rede macvlan_net já existe..."
        echo "========================================"
        
        if ! sudo docker network inspect macvlan_net &>/dev/null; then
            echo "Aviso: A rede macvlan_net não existe! O container pode não funcionar corretamente."
            echo "Você precisará criar a rede manualmente ou executar o script novamente escolhendo 's'"
        else
            echo "Rede macvlan_net encontrada! Continuando..."
        fi
    fi

    echo "================================="
    echo "Ajustando IP do Open5GS"
    echo "================================="
    
    OPEN5GS_IP=$(read_ip "Informe o IP do Open5GS. Ex - 192.168.210.231: ")
    echo "Open5GS IP: $OPEN5GS_IP"
    echo "========================================"

    # Atualiza open5gs.env
    if [ -f "open5gs/open5gs.env" ]; then
        sed -i "s/^OPEN5GS_IP=.*/OPEN5GS_IP=$OPEN5GS_IP/" open5gs/open5gs.env 2>/dev/null || echo "OPEN5GS_IP=$OPEN5GS_IP" >> open5gs/open5gs.env
        sed -i "s/^UPF_ADVERTISE_IP=.*/UPF_ADVERTISE_IP=$OPEN5GS_IP/" open5gs/open5gs.env 2>/dev/null || echo "UPF_ADVERTISE_IP=$OPEN5GS_IP" >> open5gs/open5gs.env
        echo "Arquivo open5gs.env atualizado!"
    fi

    # Atualiza APENAS o IP do 5gc no docker-compose
    if [ -f "docker-compose-macvlan.yml" ]; then
        cp docker-compose-macvlan.yml docker-compose-macvlan.yml.bak
        sed -i "/^  5gc:/,/^  [a-z]/ s/ipv4_address: \${OPEN5GS_IP:-[^}]*}/ipv4_address: \${OPEN5GS_IP:-$OPEN5GS_IP}/" docker-compose-macvlan.yml
        echo "Arquivo docker-compose-macvlan.yml atualizado!"
    fi

    echo "========================="
    echo "Iniciando Open5GS"
    echo "========================="
    sudo docker compose --env-file open5gs/open5gs.env -f docker-compose-macvlan.yml up -d 5gc
    sleep 10
    sudo docker logs -f open5gs_5gc_macvlan
}

function stop_Open5GS(){
    echo "========================="
    echo "Encerrando Open5GS"
    echo "========================="

    cd ./open5GS
    sudo docker compose --env-file open5gs/open5gs.env -f docker-compose-macvlan.yml down 5gc
    #OPEN_5GS_ENV_FILE=open5gs/open5gs.env docker compose -f docker-compose.yml down
    }

function logs_Open5GS(){
    sudo docker logs -f open5gs_5gc_macvlan
    }

function configure_metallb() {

    read -rp "Deseja alterar a faixa de IP do Metalab? [y/N]: " CHANGE_IPS

    if [[ ! "$CHANGE_IPS" =~ ^[Yy]$ ]]; then
        return 0
    fi

    echo "=========================================="
    echo "Validando configuração do MetalLB"
    echo "=========================================="

    #
    # Verifica se o MetalLB está instalado
    #
    if ! sudo microk8s kubectl get namespace metallb-system >/dev/null 2>&1; then

        echo "[INFO] MetalLB não encontrado."

        if [[ -z "$METALLB_RANGE" ]]; then
            echo ""
            read -rp "Informe a faixa IP do MetalLB (ex: 192.168.110.240-192.168.110.250): " METALLB_RANGE
        fi

        echo "=========================================="
        echo "Habilitando MetalLB: ${METALLB_RANGE}"
        echo "=========================================="

        echo "[INFO] Habilitando MetalLB com faixa ${METALLB_RANGE}"

        sudo microk8s enable metallb:${METALLB_RANGE}

        return $?
    fi

    echo "[INFO] MetalLB já está habilitado."

    #
    # Descobre automaticamente o IPAddressPool
    #
    POOL_NAME=$(sudo microk8s kubectl get ipaddresspools \
        -n metallb-system \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    #
    # Caso não exista pool
    #
    if [[ -z "${POOL_NAME}" ]]; then

        echo "[INFO] Nenhum IPAddressPool encontrado."
        echo "[INFO] Aplicando configuração..."
        

        sudo microk8s enable metallb:${METALLB_RANGE}

        return $?
    fi

    echo "[INFO] Pool encontrado: ${POOL_NAME}"

    #
    # Obtém faixa atual
    #
    EXISTING_RANGE=$(sudo microk8s kubectl get ipaddresspool "${POOL_NAME}" \
        -n metallb-system \
        -o jsonpath='{.spec.addresses[0]}' 2>/dev/null)

    #
    # Obtém quantidade de IPs já atribuídos
    #
    ASSIGNED_IPS=$(sudo microk8s kubectl get ipaddresspool "${POOL_NAME}" \
        -n metallb-system \
        -o jsonpath='{.status.assignedIPv4}' 2>/dev/null)

    ASSIGNED_IPS=${ASSIGNED_IPS:-0}

    echo "[INFO] Faixa atual: ${EXISTING_RANGE}"
    echo "[INFO] IPs atualmente atribuídos: ${ASSIGNED_IPS}"

    #
    # Faixa já configurada
    #
    if [[ "${EXISTING_RANGE}" == "${METALLB_RANGE}" ]]; then

        echo "[INFO] A faixa informada já está configurada."
        return 0
    fi

    echo ""
    echo "[AVISO] O MetalLB já possui uma faixa configurada."
    echo "        Atual: ${EXISTING_RANGE}"
    echo "        Nova : ${METALLB_RANGE}"

    if [[ "${ASSIGNED_IPS}" -gt 0 ]]; then
        echo ""
        echo "[ATENÇÃO] Existem ${ASSIGNED_IPS} IP(s) atualmente atribuídos."
        echo "[ATENÇÃO] Alterar a faixa poderá impactar serviços LoadBalancer."
    fi

    echo ""

    read -rp "Deseja substituir a faixa atual? [y/N]: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[INFO] Mantendo configuração atual."
        return 0
    fi

    echo "[INFO] Atualizando faixa do MetalLB..."

    sudo microk8s kubectl patch ipaddresspool "${POOL_NAME}" \
        -n metallb-system \
        --type merge \
        -p "{\"spec\":{\"addresses\":[\"${METALLB_RANGE}\"]}}"

    echo "[INFO] Faixa atualizada com sucesso."

    #
    # Exibe resultado final
    #
    NEW_RANGE=$(sudo microk8s kubectl get ipaddresspool "${POOL_NAME}" \
        -n metallb-system \
        -o jsonpath='{.spec.addresses[0]}')

    echo "[INFO] Nova faixa configurada: ${NEW_RANGE}"
}

function configure_open5gs_ips() {

    local VALUES_FILE="$WORK_DIR/open5gs_k8s/values.yaml"

    read -rp "Deseja alterar os IPs do Open5GS? [y/N]: " CHANGE_IPS

    if [[ ! "$CHANGE_IPS" =~ ^[Yy]$ ]]; then
        return 0
    fi

    read -rp "IP WebUI: " WEBUI_IP
    read -rp "IP AMF: " AMF_IP
    read -rp "IP UPF: " UPF_IP

    sed -i \
        -e "/webui:/,/provider:/ s/loadBalancerIP:.*/loadBalancerIP: ${WEBUI_IP}/" \
        -e "/ngap:/,/provider:/ s/loadBalancerIP:.*/loadBalancerIP: ${AMF_IP}/" \
        -e "/gtpu:/,/provider:/ s/loadBalancerIP:.*/loadBalancerIP: ${UPF_IP}/" \
        "$VALUES_FILE"
}

function start_Open5GS_k8s() {

    local NAMESPACE="open5gs"
    local METALLB_RANGE="${1:-}"

    echo "=========================================="
    echo "Iniciando deploy do Open5GS em Kubernetes"
    echo "=========================================="

    install_package "python3-pymongo"

    if ! command -v microk8s >/dev/null 2>&1; then
        sudo snap install microk8s --classic
    fi

    echo "=========================================="
    echo "Configurando permissões"
    echo "=========================================="

    sudo usermod -a -G microk8s "$USER"
    sudo chown -f -R "$USER" "$HOME/.kube"

    echo "=========================================="
    echo "Aguardando MicroK8s inicializar"
    echo "=========================================="

    sudo microk8s status --wait-ready

    echo "=========================================="
    echo "Habilitando storage"
    echo "=========================================="

    sudo microk8s enable storage
    
    sudo microk8s enable dns

    configure_metallb

    echo "=========================================="
    echo "Criando namespace ${NAMESPACE}"
    echo "=========================================="

    sudo microk8s kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | sudo microk8s kubectl apply -f -

    #configure_open5gs_ips

    echo "=========================================="
    echo "Iniciando Open5GS"
    echo "=========================================="

    sudo microk8s helm3 upgrade \
        --install open5gs \
        "$WORK_DIR/open5gs_k8s/open5gs-0.3.4.tgz" \
        -n "${NAMESPACE}" \
        -f "$WORK_DIR/open5gs_k8s/values.yaml"

    echo "=========================================="
    echo "Aguardando banco Open5GS ficar pronto"
    echo "=========================================="

    until sudo microk8s kubectl get pod -n open5gs | grep open5gs-db-deployment >/dev/null 2>&1; do
        echo "[INFO] Pod do banco ainda não criado..."
        sleep 5
    done

    DB_POD=$(sudo microk8s kubectl get pods -n open5gs -o name | grep open5gs-db-deployment | head -n1)

    echo "[INFO] Banco encontrado: $DB_POD"

    sudo microk8s kubectl wait \
        --for=condition=Ready \
        "$DB_POD" \
        -n open5gs \
        --timeout=300s

    echo "[OK] Banco pronto"

    sleep 10

    echo "=========================================="
    echo "Provisionando UEs no Open5GS"
    echo "=========================================="

    cd "$WORK_DIR/open5gs_k8s/utils"
    ./register_ues_open5gs_k8s.sh

    echo "=========================================="
    echo "Open5GS provisionado com sucesso"
    echo "=========================================="
    logs_Open5GS_k8s
    }

function stop_Open5GS_k8s() {
    echo "=========================================="
    echo "Removendo namespace Open5GS_k8s"
    echo "=========================================="
    sudo microk8s kubectl delete namespace open5gs
    echo "=========================================="
    echo "Removendo IPs externos Open5GS_k8s"
    echo "=========================================="
    sudo microk8s kubectl get svc -A
    echo "=========================================="
    echo "Removendo metalab Open5GS_k8s"
    echo "=========================================="
    sudo microk8s disable metallb
    #sudo microk8s enable metallb
    #echo "=========================================="
    #echo "Reiniciando microk8s"
    #echo "=========================================="
    #sudo microk8s reset
    echo "=========================================="
    echo "Encerrado com sucesso!"
    echo "=========================================="
    }

function logs_Open5GS_k8s() {

    echo "=========================================="
    echo "Exibindo logs AMF Open5GS_k8s"
    echo "=========================================="
    local NAMESPACE="open5gs"

    AMF_POD=$(sudo microk8s kubectl get pods -n ${NAMESPACE} \
        --no-headers \
        -o custom-columns=":metadata.name" | grep "open5gs-amf-deployment" | head -n 1)

    if [[ -z "$AMF_POD" ]]; then
        echo "[ERRO] Pod do AMF não encontrado no namespace ${NAMESPACE}"
        return 1
    fi

    echo "[INFO] Exibindo logs do pod ${AMF_POD}"
    sudo microk8s kubectl logs -f -n ${NAMESPACE} ${AMF_POD}
    }

function install_RAN_srsRAN(){
    echo "Instalando dependências"
    install_package "cmake" "make" "g++" "libgtest-dev" "pkg-config" "libfftw3-dev" "libboost-program-options-dev" "libconfig++-dev" "libmbedtls-dev" "libsctp-dev" "libyaml-cpp-dev" "libdw-dev" "libbfd-dev" "libdwarf-dev" "binutils-dev"
    #sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100
    #sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100
    sudo rm -rf mbedtls
    echo "Clonando mbedtls"
    git clone https://github.com/Mbed-TLS/mbedtls.git
    cd mbedtls
    git checkout v3.5.2
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ../..
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
    cd $WORK_DIR
    echo "========================="
    echo "Ativar modo performance"
    echo "========================="
    cd $WORK_DIR/utils_srsRAN/
    ./srsran_performance.sh
    cd ..
    clone_srs_RAN
    sudo rm -rf build
    mkdir build
    cd build
    echo "========================="
    echo "Build srsRAN"
    echo "========================="
    #export CC=/usr/bin/gcc-13
    #export CXX=/usr/bin/g++-13
    cmake ../  -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
    make -j $(nproc)
    sudo make install
    echo "========================="
    echo "Instalado com sucesso"
    echo "========================="
    }

function start_srsRAN_metrics(){
    echo "======================================="
    echo "Iniciando o coletor de metricas srsRAN"
    echo "======================================="
    cd $WORK_DIR/utils_srsRAN/docker/
    docker compose -f docker-compose.yaml up grafana influxdb metrics-server -d
    }

function stop_srsRAN_metrics(){
    echo "======================================="
    echo "Encerrando o coletor de metricas srsRAN"
    echo "======================================="
    cd $WORK_DIR/utils_srsRAN/docker/
    docker compose -f docker-compose.yaml down grafana influxdb metrics-server
    }

function gNB_b106_bm_srsRAN(){
    echo "======================================="
    echo "Iniciando gNB srsRAN Baremetal" 
    echo "======================================="
    cd $WORK_DIR/utils_srsRAN/
    ./gnb_up_b210_256QAM_MIMO_30Mhz.sh
    }


function gNB_srsRAN_docker(){
    
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
    echo "Iniciando gNB srsRAN docker" 
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
    echo "Ajustando IP da gNB srsRAN - Docker"
    echo "==================================="

    # Loop para validar o IP
    while true; do
        read -p "Informe o IP da gNB. Obs - IP na faixa da macvlan: " SRSRAN_IP
        
        if validate_ip "$SRSRAN_IP"; then
            echo "IP válido: $SRSRAN_IP"
            break
        else
            echo "========================================"
            echo "ERRO: IP inválido! '$SRSRAN_IP' não é um endereço IP válido."
            echo "O IP deve estar no formato: xxx.xxx.xxx.xxx"
            echo "Cada octeto deve ser um número entre 0 e 255."
            echo "Exemplos válidos: 192.168.210.231, 10.0.0.1, 172.31.0.154"
            echo "========================================"
        fi
    done
    echo "========================================"
    echo "gNB srsRAN IP: $SRSRAN_IP"
    echo "========================================"

    # Atualiza o docker-compose da gNB
    COMPOSE_FILE="$WORK_DIR/utils_srsRAN/docker/docker-compose.yaml"

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
                        s/ipv4_address: [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/ipv4_address: $SRSRAN_IP/
                    }
                }
            }" "$COMPOSE_FILE"
            
            echo "========================================"
            echo "Arquivo docker-compose.yaml atualizado!"
            echo "IP configurado: $SRSRAN_IP"
            
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
    CONFIG_FILE="$WORK_DIR/utils_srsRAN/gnb_conf_256QAM_SISO_30Mhz.yaml"

    if [ -f "$CONFIG_FILE" ]; then
        # Faz backup do arquivo de configuração
        BACKUP_CONFIG="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$BACKUP_CONFIG"
        echo "Backup da configuração criado: $BACKUP_CONFIG"
        
        # Substitui o bind_addr no bloco cu_cp
        sed -i "s/bind_addr: [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/bind_addr: $SRSRAN_IP/" "$CONFIG_FILE"
        
        echo "Arquivo de configuração atualizado! bind_addr configurado: $SRSRAN_IP"
        
        # Verifica se a alteração foi feita corretamente
        if grep -q "bind_addr: $SRSRAN_IP" "$CONFIG_FILE"; then
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
    echo "   Docker Compose: \${SRSRAN_IP:-$SRSRAN_IP}"
    echo "   Arquivo YAML: bind_addr: $SRSRAN_IP"
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
    safe_run "docker rm -f srsran_gnb" "Remoção do container"
    #safe_run "rm $WORK_DIR/srsRAN_Project/docker/docker-compose.yaml" "Remoção do compose antigo"
    safe_run "rm $WORK_DIR/ocudu/docker/.env" "Remoção do .env"

    # Verifica arquivo obrigatório
    check_required "$WORK_DIR/utils_srsRAN/docker/docker-compose.yaml" || return 1
    
    cp "$WORK_DIR/utils_ocudu/docker/.env" "$WORK_DIR/ocudu/docker/" || {
        echo "ERRO: Falha crítica ao copiar .env"
        return 1
    }

    # Operações críticas (não podem falhar)
    cp "$WORK_DIR/utils_srsRAN/docker/docker-compose.yaml" "$WORK_DIR/srsRAN_Project/docker/" || {
        echo "ERRO: Falha crítica ao copiar docker-compose.yaml"
        return 1
    }
    
    cd "$WORK_DIR/srsRAN_Project/docker" || {
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
    
    echo "Container srsran_gnb iniciado com sucesso!"
    echo "======================================="
    echo "Acompanhando logs (Ctrl+C para sair):"
    
    docker logs -f srsran_gnb || {
        echo "AVISO: Container pode estar rodando, mas falha ao mostrar logs"
        return 0
    }
}

function logs_gNB_srsRAN_docker(){
    echo "======================================="
    echo "Logs gNB srsRAN"
    echo "======================================="
    sudo docker logs -f srsran_gnb
    }

function stop_gNB_srsRAN_docker(){
    echo "======================================="
    echo "Encerrando gNB srsRAN"
    echo "======================================="
    cd $WORK_DIR/utils_srsRAN/docker
    docker compose -f docker-compose.yaml down
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
    sudo cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
    sudo make -j $(nproc)
    #echo "========================="
    #echo "Realizando teste do build ocudu"
    #echo "========================="
    #sudo make test -j $(nproc)
    sudo make install
    echo "========================="
    echo "Instalado com sucesso!"
    echo "========================="
    }

function clone_ocudu(){
    cd $WORK_DIR || exit
    if [ -d "srsRAN_Project" ]; then
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
    docker compose -f docker-compose.yaml down grafana influxdb telegraf

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
    safe_run "sudo docker rm -f ocudu_gnb" "Remoção do container"
    #safe_run "sudo rm $WORK_DIR/ocudu/docker/docker-compose.yaml" "Remoção do compose antigo"
    safe_run "sudo rm $WORK_DIR/ocudu/docker/.env" "Remoção do .env antigo"

    # Verifica arquivo obrigatório
    check_required "$WORK_DIR/utils_ocudu/docker/docker-compose.yaml" || return 1

    cp "$WORK_DIR/utils_ocudu/docker/.env" "$WORK_DIR/ocudu/docker/" || {
        echo "ERRO: Falha crítica ao copiar .env"
        return 1
    }

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
    
    stop_gNB_ocudu_docker 
    
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

# Case principal
case "${COMMAND}" in
    "--install")
        install_package "git"
        performance_mode
        install_docker
        install_libuhd
        ;;
    "--stop_srsRAN_docker")
        stop_gNB_srsRAN_docker
        ;;
    "--logs_srsRAN_docker")
        logs_gNB_srsRAN_docker
        ;;
    "--gNB_srsRAN_docker")
        gNB_srsRAN_docker
        ;;
    "--gNB_b106_bm_srsRAN")
        gNB_b106_bm_srsRAN
        ;;
    "--start_srsRAN_metrics")
        start_srsRAN_metrics
        ;;
    "--stop_srsRAN_metrics")
        stop_srsRAN_metrics
        ;;
    "--install_RAN_srsRAN")
        install_RAN_srsRAN
        ;;
    "--install_RAN_ocudu")
        install_RAN_ocudu
        ;;
    "--stop_ocudu_docker")
        stop_gNB_ocudu_docker
        ;;
    "--logs_ocudu_docker")
        logs_gNB_ocudu_docker
        ;;
    "--gNB_ocudu_docker")
        gNB_ocudu_docker
        ;;
    "--gNB_b106_bm_ocudu")
        gNB_b106_bm_ocudu
        ;;
    "--start_ocudu_metrics")
        start_ocudu_metrics
        ;;
    "--stop_ocudu_metrics")
        stop_ocudu_metrics
        ;;
    "--install_RAN_ocudu")
        install_RAN_ocudu
        ;; 
    "--start_Open5GS")
        start_Open5GS
        ;;    
    "--logs_Open5GS")
        logs_Open5GS
        ;;
    "--stop_Open5GS")
        stop_Open5GS
        ;;
    "--start_Open5GS_k8s")
        start_Open5GS_k8s
        ;;
    "--stop_Open5GS_k8s")
        stop_Open5GS_k8s
        ;;
    "--logs_Open5GS_k8s")
        logs_Open5GS_k8s
        ;;
    "--start_scRIC")
        start_scRIC
        ;;
    "--stop_scRIC")
        stop_scRIC
        ;;
    "--install_scRIC")
        install_scRIC
        ;;
    "--logs_scRIC")
        logs_scRIC
        ;;
    "--installZabbix")
        installZabbix
        ;;
    "--startZabbix")
        startZabbix
        ;;
    "--stopZabbix")
        stopZabbix
        ;;
    "--install_5gc_oai")
        pull_docker_5g
        ;;
    "--install_RAN_oai")
        clone_repo_RAN
        build_oai_RAN       
        ;;
    "--start_5g_oai_mono")
        start_5g_oai_mono
        ;;
    "--start_5g_oai_dist")
        init_performance
        start_5g_oai_dist
        ;;
    "--stop_5g_oai")
        stop_5g_oai
        ;;
    "--logs_5g_oai")
        logs_5g_oai
        ;;
    "--gNB_b106")
        chek_gNB_conf "b" "210" "106" "docker" ""      
        ;;
    "--gNB_b106_bm")
        chek_gNB_conf "b" "210" "106" "" ""      
        ;;
    "--FlexRIC")
        FlexRIC
        ;;
    "--start_nearRT-RIC")
        start_nearRT-RIC
        ;;
    "--start_E2Agent")
        start_E2Agent
        ;;
    "--start_gNB_rfsim")
        start_gNB_rfsim
        ;;
    "--start_gNB_rfsim_docker")
        start_gNB_rfsim_docker
        ;;
    "--stop_gNB_rfsim_docker")
        stop_gNB_rfsim_docker
        ;;
    "--logs_gNB_rfsim_docker")
        logs_gNB_rfsim_docker
        ;;
    "--start_UE_rfsim")
        start_UE_rfsim
        ;;
    "--start_UE_rfsim_docker")
        start_UE_rfsim_docker
        ;;
    "--stop_UE_rfsim_docker")
        stop_UE_rfsim_docker
        ;;
    "--start_video")
        start_video
        ;;
    "--stop_video")
        stop_video
	;;
    "--xApps")
        xApps
        ;;
        *)
echo " COMMAND not Found."
show_help
exit 127;
;;
esac

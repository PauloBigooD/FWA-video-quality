#!/bin/bash

## Author:   Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br - Tel: +55 (84) 9 8808-0933
## GitHub:   https://github.com/PauloBigooD
## Linkedin: https://www.linkedin.com/in/paulo-eduardo-5a18b3174/

set -e

## Variável de escolha de opção
COMMAND="$1"
## Work directory path is the current directory
WORK_DIR=$PWD
REPO_SRS_RAN="https://github.com/srsran/srsRAN_Project.git"
VERSION_SRS_RAN="release_24_10"

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

function start_Open5GS(){
    cd ./open5GS
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
    sudo microk8s enable metallb
    echo "=========================================="
    echo "Reiniciando microk8s"
    echo "=========================================="
    sudo microk8s reset
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
    install_package "cmake" "make" "g++" "g++-13" "libgtest-dev" "pkg-config" "libfftw3-dev" "libboost-program-options-dev" "libconfig++-dev" "libmbedtls-dev" "libsctp-dev" "libyaml-cpp-dev" "libdw-dev" "libbfd-dev" "libdwarf-dev" "binutils-dev"
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
    safe_run "rm $WORK_DIR/srsRAN_Project/docker/docker-compose.yaml" "Remoção do compose antigo"
    
    # Verifica arquivo obrigatório
    check_required "$WORK_DIR/utils_srsRAN/docker/docker-compose.yaml" || return 1
    
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
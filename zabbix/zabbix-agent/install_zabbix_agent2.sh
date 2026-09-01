#!/bin/bash

# Script completo de instalação/configuração do Zabbix Agent 2 (7.2)
# Parâmetros:
#   --hostname [Nome do Host] (obrigatório)
#   --server [IP do Zabbix Server] (obrigatório)
#   --metadata [HostMetadata] (opcional)
#   --force (força reinstalação)

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis padrão
ZABBIX_SERVER=""
HOSTNAME=""
HOST_METADATA=""
FORCE_INSTALL=false
EXTERNAL_SCRIPTS_DIR="/etc/zabbix/externalscripts"

# UserParameters customizados (OAI + monitoração de processos/disco)
CUSTOM_USER_PARAMS=(
  "UserParameter=oai.flexric.SM[*],$EXTERNAL_SCRIPTS_DIR/oai-flexric-SM-NearRT.py"
  "UserParameter=srs.flexric.SM[*],$EXTERNAL_SCRIPTS_DIR/srs-flexric-SM-NearRT.py"
  "UserParameter=oai.e2node.SM[*],$EXTERNAL_SCRIPTS_DIR/oai-flexric-SM-E2Node.py \$1"
  "UserParameter=srs.e2node.SM[*],$EXTERNAL_SCRIPTS_DIR/srs-flexric-SM-E2Node.py \$1"
  "UserParameter=oai.ue.kpi.MAC[*],$EXTERNAL_SCRIPTS_DIR/ue-kpis-MAC.py \$1"
  "UserParameter=oai.ue.kpi.RRC[*],$EXTERNAL_SCRIPTS_DIR/ue-kpis-RRC.py \$1"
  "UserParameter=oai.gnb.kpi[*],$EXTERNAL_SCRIPTS_DIR/gNB-kpis-oai.py \$1"
  "UserParameter=srs.gnb.kpi[*],$EXTERNAL_SCRIPTS_DIR/gNB-kpis-srsRAN.py \$1"
  "UserParameter=oai.smf.ue[*],$EXTERNAL_SCRIPTS_DIR/smf-kpis-ue.py"
  "UserParameter=oai.amf.gnb[*],$EXTERNAL_SCRIPTS_DIR/amf-kpis-gnb.py \$1"
  "UserParameter=oai.amf.ue[*],$EXTERNAL_SCRIPTS_DIR/amf-kpis-ue.py \$1"
  "UserParameter=oai.amf.log[*],$EXTERNAL_SCRIPTS_DIR/oai-logs.sh"
  "UserParameter=custom.vfs.dev.discovery[*],$EXTERNAL_SCRIPTS_DIR/queryDisks.pl"
  "UserParameter=custom.vfs.dev.read.ops[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$4}'"
  "UserParameter=custom.vfs.dev.read.sectors[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$6}'"
  "UserParameter=custom.vfs.dev.read.ms[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$7}'"
  "UserParameter=custom.vfs.dev.write.ops[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$8}'"
  "UserParameter=custom.vfs.dev.write.sectors[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$10}'"
  "UserParameter=custom.vfs.dev.write.ms[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$11}'"
  "UserParameter=custom.vfs.dev.io.active[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$12}'"
  "UserParameter=custom.vfs.dev.io.ms[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$13}'"
)

# Processar parâmetros
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --server)
            ZABBIX_SERVER="$2"
            shift 2
            ;;
        --metadata)
            HOST_METADATA="$2"
            shift 2
            ;;
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            echo -e "${RED}Erro: Parâmetro desconhecido: $1${NC}"
            exit 1
            ;;
    esac
done

# Validar parâmetros obrigatórios
if [[ -z "$HOSTNAME" || -z "$ZABBIX_SERVER" ]]; then
    echo -e "${RED}Erro: --hostname e --server são obrigatórios!${NC}"
    echo "Exemplo: $0 --hostname meu-host --server 192.168.1.100 [--metadata OAI-gNB]"
    exit 1
fi

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Este script deve ser executado como root!${NC}" 
    exit 1
fi

# Função para verificar instalação existente
check_existing_installation() {
    if command -v zabbix_agent2 &> /dev/null; then
        CURRENT_VERSION=$(zabbix_agent2 --version | grep -oP '(\d+\.\d+\.\d+)')
        echo -e "${YELLOW}[!] Zabbix Agent ${CURRENT_VERSION} já instalado.${NC}"
        
        if $FORCE_INSTALL; then
            echo -e "${BLUE}[i] Modo --force ativado. Removendo versão existente...${NC}"
            remove_existing
            return
        fi

        read -p "Deseja (1) Manter, (2) Atualizar, ou (3) Cancelar? [1/2/3]: " choice
        case $choice in
            1) exit 0 ;;
            2) remove_existing ;;
            3) exit 0 ;;
            *) echo -e "${RED}Opção inválida. Saindo.${NC}"; exit 1 ;;
        esac
    fi
}

# Função para remover instalação existente
remove_existing() {
    echo -e "${YELLOW}[!] Removendo instalação existente...${NC}"
    
    DISTRO=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
    
    case $DISTRO in
        ubuntu|debian)
            apt-get remove --purge -y zabbix-agent* > /dev/null
            ;;
        rhel|centos|ol)
            yum remove -y zabbix-agent* > /dev/null
            ;;
    esac
    
    # Manter scripts customizados durante reinstalação
    if [ -d "$EXTERNAL_SCRIPTS_DIR" ]; then
        mv "$EXTERNAL_SCRIPTS_DIR" /tmp/zabbix_externalscripts_backup
    fi
    
    rm -rf /etc/zabbix
    echo -e "${GREEN}[✓] Remoção concluída.${NC}"
}

# Função para configurar UserParameters
configure_user_parameters() {
    echo -e "${YELLOW}[+] Configurando UserParameters customizados...${NC}"
    
    # Criar diretório para scripts externos
    mkdir -p "$EXTERNAL_SCRIPTS_DIR"
    chown zabbix:zabbix "$EXTERNAL_SCRIPTS_DIR"
    chmod 755 "$EXTERNAL_SCRIPTS_DIR"
    
    # Restaurar backup de scripts se existir
    if [ -d "/tmp/zabbix_externalscripts_backup" ]; then
        cp -r /tmp/zabbix_externalscripts_backup/* "$EXTERNAL_SCRIPTS_DIR"/
        rm -rf /tmp/zabbix_externalscripts_backup
    fi
    
    # Adicionar configurações ao arquivo
    echo -e "\n# Custom User Parameters (OAI + Process/Disk Monitoring)" >> /etc/zabbix/zabbix_agent2.d/userparams.conf
    for param in "${CUSTOM_USER_PARAMS[@]}"; do
        echo "$param" >> /etc/zabbix/zabbix_agent2.d/userparams.conf
    done
    
    echo -e "${GREEN}[✓] UserParameters configurados em:${NC}"
    echo "/etc/zabbix/zabbix_agent2.d/userparams.conf"
}

# Função para copiar scripts customizados para /etc/zabbix/externalscripts
copy_externalscripts() {
    echo -e "${YELLOW}[+] Copiando scripts para ${EXTERNAL_SCRIPTS_DIR}...${NC}"

    SOURCE_DIR="$(dirname "$0")/externalscripts"

    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${RED}[!] Diretório de origem não encontrado: $SOURCE_DIR${NC}"
        exit 1
    fi

    mkdir -p "$EXTERNAL_SCRIPTS_DIR"
    cp -r "$SOURCE_DIR"/* "$EXTERNAL_SCRIPTS_DIR"/
    chown -R zabbix:zabbix "$EXTERNAL_SCRIPTS_DIR"
    chmod -R 755 "$EXTERNAL_SCRIPTS_DIR"

    echo -e "${GREEN}[✓] Scripts copiados com sucesso para ${EXTERNAL_SCRIPTS_DIR}.${NC}"
}

# Função principal de instalação
install_zabbix() {
    DISTRO=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
    
    case $DISTRO in
        ubuntu|debian)
            echo -e "${YELLOW}[+] Detectado Ubuntu/Debian. Instalando...${NC}"
            wget -q "https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu$(lsb_release -rs)_all.deb" -O /tmp/zabbix-release.deb
            dpkg -i /tmp/zabbix-release.deb > /dev/null
            apt-get update > /dev/null
            apt-get install -y zabbix-agent2 zabbix-agent2-plugin-* > /dev/null
            ;;
        rhel|centos|ol)
            echo -e "${YELLOW}[+] Detectado RHEL/CentOS. Instalando...${NC}"
            rpm -Uvh "https://repo.zabbix.com/zabbix/7.2/rhel/$(rpm -E %{rhel})/x86_64/zabbix-release-7.2-1.el$(rpm -E %{rhel}).noarch.rpm" > /dev/null
            yum install -y zabbix-agent2 > /dev/null
            ;;
        *)
            echo -e "${RED}Distribuição não suportada: $DISTRO${NC}"
            exit 1
            ;;
    esac
    
    # Configuração principal
    echo -e "${YELLOW}[+] Configurando zabbix_agent2.conf...${NC}"
    cat > /etc/zabbix/zabbix_agent2.conf <<EOL
Server=${ZABBIX_SERVER}
ServerActive=${ZABBIX_SERVER}
Hostname=${HOSTNAME}
HostMetadata=${HOST_METADATA}
LogType=file
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=50
PidFile=/run/zabbix/zabbix_agent2.pid
Include=/etc/zabbix/zabbix_agent2.d/*.conf
ControlSocket=/tmp/agent.sock
EOL

    # Configurar UserParameters
    configure_user_parameters
    
    # Configurar SELinux (RHEL/CentOS)
    if command -v setenforce &> /dev/null; then
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    fi
    
}



# Restart agent
restart_agent(){
    # Iniciar serviço
    systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2 > /dev/null
}


# --- Execução principal ---
check_existing_installation
install_zabbix
copy_externalscripts
sudo usermod -aG docker zabbix
restart_agent

# Verificação final
if systemctl is-active --quiet zabbix-agent2; then
    echo -e "\n${GREEN}[✓] Instalação concluída com sucesso!${NC}"
    echo -e "Versão: ${BLUE}$(zabbix_agent2 --version | head -n 1)${NC}"
    echo -e "Hostname: ${YELLOW}${HOSTNAME}${NC}"
    echo -e "Server: ${YELLOW}${ZABBIX_SERVER}${NC}"
    [[ -n "$HOST_METADATA" ]] && echo -e "Metadata: ${YELLOW}${HOST_METADATA}${NC}"
    echo -e "UserParameters: ${BLUE}$(grep -c '^UserParameter=' /etc/zabbix/zabbix_agent2.d/userparams.conf) configurados${NC}"
else
    echo -e "${RED}[!] Falha na instalação. Verifique os logs:${NC}"
    tail -n 10 /var/log/zabbix/zabbix_agent2.log
    exit 1
fi

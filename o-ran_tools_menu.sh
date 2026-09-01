#!/bin/bash

set -e

WORK_DIR=$PWD
LOG_DIR="$WORK_DIR/logs"
mkdir -p "$LOG_DIR"

TMUX_CONF_FILE="$HOME/.tmux.conf"
[[ ! -f "$TMUX_CONF_FILE" ]] && echo "set -g mouse on" > "$TMUX_CONF_FILE"

log_exec() {
    local log_name="$1"
    shift
    bash -c "$@" 2>&1 | tee "$LOG_DIR/${log_name}_$(date +%Y%m%d_%H%M%S).log"
}

function open_terminal() {
    TMUX_CONF_FILE="$HOME/.tmux.conf"
    [[ ! -f "$TMUX_CONF_FILE" ]] && echo "set -g mouse on" > "$TMUX_CONF_FILE"

    if [[ -n "$SSH_CONNECTION" ]]; then
        tmux new-session -d -s session_$2 "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit"
        tmux attach-session -t session_$2
    else
        if [[ -n "$DISPLAY" && $XDG_SESSION_TYPE == "x11" ]]; then
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal -- bash -c "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit" & disown
            else
                x-terminal-emulator -e bash -c "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit" & disown
            fi
        else
            tmux new-session -d -s session_$2 "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit"
            tmux attach-session -t session_$2
        fi
    fi
}

run() {
    local option="$1"
    open_terminal "./core-scripts/oai_tools.sh $option" "$(echo $option | tr -d -- -)"
}

menu() {
    while true; do
        echo -e "\n===================== 🛠 \e[1;36m O-RAN_tools \e[0m🛠 ====================="
        echo  "1) Instalar componentes Git, Docker e UHD"
        echo  "2) Iniciar Servidor de Monitoramento (Zabbix Server; Grafana)"
        echo  "3) Parar Servidor de Monitoramento (Zabbix Server; Grafana)"
        echo -e "\n======================= Open5GS Docker ======================"
        echo "4) Iniciar 5GC Open5GS"
        echo "5) Logs 5GC Open5GS"
        echo "6) Parar 5GC Open5GS"
        echo -e "\n===================== Open5GS Kubernets ====================="
        echo "7) Iniciar 5GC Open5GS_k8s"
        echo "8) Logs 5GC Open5GS_k8s"
        echo "9) Parar 5GC Open5GS_k8s"
        echo -e "\n========================== srsRAN ==========================="
        echo "10) Dependências 5G RAN srsRAN (Bare Metal/Docker 🐳)"
        echo "11) Iniciar metrics srsRAN"
        echo "12) Encerrar metrics srsRAN"
        echo "13) Iniciar gNB srsRAN b210 106_PRBs (Bare Metal)"
        echo "14) Iniciar gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo "15) Logs gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo "16) Parar gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo -e "\n========================== OCUDU ============================"
        echo "17) Dependências 5G RAN OCUDU (Bare Metal/Docker 🐳)"
        echo "18) Iniciar metrics OCUDU"
        echo "19) Encerrar metrics OCUDU"
        echo "20) Iniciar gNB OCUDU b210 106_PRBs (Bare Metal)"
        echo "21) Iniciar gNB OCUDU b210 106_PRBs (Docker 🐳)"
        echo "22) Logs gNB OCUDU b210 106_PRBs (Docker 🐳)"
        echo "23) Parar gNB OCUDU b210 106_PRBs (Docker 🐳)"
        echo -e "\n======================= Zabbix Agent ========================"
        echo "24) Instalar Coletor de KPIs (Zabbix Agent)"
	    echo -e "\n============== Video server (open5gs docker) ================"
        echo "25) Iniciar Video Server"
        echo "26) Encerrar Video Server"
        echo -e "\n================================================================="
        echo -e "27) \e[1;31mSair\e[0m"
        read -p "Escolha uma opção: " opt
        case $opt in
            1) run --install ;;
            2) run --startZabbix ;;
            3) run --stopZabbix ;;    
            4) run --start_Open5GS ;;
            5) run --logs_Open5GS ;;
            6) run --stop_Open5GS ;;
            7) run --start_Open5GS_k8s ;;
            8) run --logs_Open5GS_k8s;;
            9) run --stop_Open5GS_k8s;;
            10) run --install_RAN_srsRAN ;;
            11) run --start_srsRAN_metrics ;;
            12) run --stop_srsRAN_metrics ;;
            13) run --gNB_b106_bm_srsRAN ;;
            14) run --gNB_srsRAN_docker ;; 
            15) run --logs_srsRAN_docker ;;
            16) run --stop_srsRAN_docker ;;
            17) run --install_RAN_ocudu ;;
            18) run --start_ocudu_metrics ;;
            19) run --stop_ocudu_metrics ;;
            20) run --gNB_b106_bm_ocudu ;;
            21) run --gNB_ocudu_docker ;; 
            22) run --logs_ocudu_docker ;;
            23) run --stop_ocudu_docker ;;            
            24) run --installZabbix ;;
            25) run --start_video ;;
            26) run --stop_video ;;
            27) echo "Saindo..."; break ;;
            *) echo "Opção inválida!" ;;
	esac
    done
}

menu

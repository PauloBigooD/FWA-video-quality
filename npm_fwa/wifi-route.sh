#!/bin/bash
# ================================================================
# Script de conexão WiFi + rota — funciona em qualquer notebook
# ================================================================
# Detecta automaticamente a interface WiFi, conecta no SSID "video"
# e adiciona rota estática para o servidor DASH via WiFi/5G.
#
# Uso:
#   bash wifi-route.sh              # Conecta e adiciona rota
#   bash wifi-route.sh --status     # Mostra estado atual
#   bash wifi-route.sh --cron       # Gera linha pra adicionar no crontab
# ================================================================

WIFI_SSID="${WIFI_SSID:-video}"
WIFI_PASS="${WIFI_PASS:-fwa12345}"
DASH_SERVER="${DASH_SERVER:-172.31.0.220}"

detect_wifi_iface() {
    # Detecta a interface WiFi ativa (qualquer nome: wlp, wlx, wlo)
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        if [ -d "/sys/class/net/$iface/wireless" ] || \
           [ -d "/sys/class/net/$iface/phy80211" ] || \
           iw dev "$iface" info >/dev/null 2>&1; then
            echo "$iface"
            return 0
        fi
    done
    # Fallback: interfaces que começam com wl
    ip -br a show 2>/dev/null | grep -E "^wl" | awk '{print $1}' | head -1
}

status() {
    echo "=== Status WiFi ==="
    WIFI=$(detect_wifi_iface)
    echo "Interface WiFi: ${WIFI:-NÃO DETECTADA}"

    if [ -n "$WIFI" ]; then
        echo "IP WiFi: $(ip -br a show $WIFI 2>/dev/null | awk '{print $3}')"
        echo "WiFi SSID: $(nmcli -t -f ACTIVE,SSID dev wifi list 2>/dev/null | grep -E "^(sim|yes)" | cut -d: -f2)"
    fi

    echo ""
    echo "=== Rota para $DASH_SERVER ==="
    ip route get "$DASH_SERVER" 2>/dev/null
}

connect_wifi() {
    local iface="$1"

    echo "🔍 Interface WiFi detectada: $iface"

    # Avisa se o sudo não está sem senha (em cron não há TTY para digitar)
    sudo -v 2>/dev/null || echo "⚠️ sudo está pedindo senha — configure NOPASSWD para nmcli, ip e rfkill (cron não tem TTY)"

    # Subir interface se necessário
    sudo ip link set "$iface" up 2>/dev/null || true

    # Desbloquear RF-kill
    sudo rfkill unblock wifi 2>/dev/null || true

    # Forçar desconexão da rede atual (se houver) — nmcli imprime yes/no em inglês
    local current_ssid
    current_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi list 2>/dev/null | grep -E "^(sim|yes)" | cut -d: -f2)

    # Já está na rede certa? Então pula a conexão (idempotente)
    if [ "$current_ssid" = "$WIFI_SSID" ]; then
        echo "✅ Já conectado em '$WIFI_SSID'"
        return 0
    fi

    if [ -n "$current_ssid" ]; then
        echo "📴 Desconectando de '$current_ssid'..."
        sudo nmcli device disconnect "$iface" 2>/dev/null || true
        sleep 2
    fi

    # Conectar (erro visível agora — sem 2>/dev/null, para diagnosticar)
    echo "📡 Conectando em '$WIFI_SSID'..."
    if sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" ifname "$iface"; then
        echo "✅ Conectado ao WiFi"
        return 0
    fi

    # Fallback: rescan e tenta de novo
    echo "Tentando fallback..."
    nmcli device wifi rescan 2>/dev/null
    sleep 3
    sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" ifname "$iface" || {
        echo "❌ Não foi possível conectar ao WiFi '$WIFI_SSID'"
        return 1
    }
}

add_route() {
    local iface="$1"

    # Obter gateway do WiFi
    local wifi_gw
    wifi_gw=$(ip route show | grep "$iface" | grep default | awk '{print $3}' | head -1)

    if [ -z "$wifi_gw" ]; then
        echo "❌ Gateway do WiFi não encontrado. A interface obteve IP?"
        return 1
    fi

    echo "🚏 Gateway WiFi: $wifi_gw"

    # Remover rota antiga se existir
    sudo ip route del "$DASH_SERVER" 2>/dev/null || true

    # Adicionar nova rota
    sudo ip route add "$DASH_SERVER" via "$wifi_gw" dev "$iface"

    echo "✅ Rota adicionada: $DASH_SERVER → via $wifi_gw dev $iface"
}

print_cron() {
    local self
    self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    cat << CRON
# Adicionar no topo do crontab (@reboot):
@reboot sleep 15 && bash $self >> /tmp/wifi-route.log 2>&1
CRON
}

# ==============================
case "${1:-}" in
    --status|-s)
        status
        ;;
    --cron|-c)
        print_cron
        ;;
    *)
        echo "=== WiFi + Rota para experimento DASH ==="
        echo ""

        WIFI=$(detect_wifi_iface)
        if [ -z "$WIFI" ]; then
            echo "❌ Nenhuma interface WiFi detectada"
            exit 1
        fi

        connect_wifi "$WIFI" || exit 1

        # Aguardar WiFi obter IP
        sleep 3

        add_route "$WIFI" || exit 1

        echo ""
        echo "=== Teste de conectividade ==="
        if curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" --connect-timeout 10 "http://$DASH_SERVER"; then
            echo "✅ Servidor DASH alcançável via WiFi!"
        else
            echo "❌ Servidor DASH NÃO alcançável"
        fi

        echo ""
        status
        ;;
esac


#!/bin/bash
# ================================================================
# Teste de velocidade fast.com (Netflix) amarrado a uma interface
# ================================================================
# Uso:
#   sudo bash fast-wifi.sh            # interface WiFi detectada automaticamente
#   sudo bash fast-wifi.sh wlo1       # interface específica
#
# Com sudo: adiciona rotas /32 temporárias para os servidores da
# Netflix via o gateway do WiFi (a rota default costuma sair pelo
# cabo — sem as rotas, o teste iria pelo caminho errado).
# As rotas são removidas automaticamente ao final.
# ================================================================

IFACE="${1:-}"
FAST_TOKEN="${FAST_TOKEN:-YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm}"   # token default do fast.com
WIFI_GW="${WIFI_GW:-}"                                          # override: WIFI_GW=192.168.1.1
ROUNDS="${ROUNDS:-2}"

detect_wifi_iface() {
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        if [ -d "/sys/class/net/$iface/wireless" ] || \
           [ -d "/sys/class/net/$iface/phy80211" ] || \
           iw dev "$iface" info >/dev/null 2>&1; then
            echo "$iface"; return 0
        fi
    done
    ip -br a show 2>/dev/null | grep -E "^wl" | awk '{print $1}' | head -1
}

IFACE="${IFACE:-$(detect_wifi_iface)}"
[ -z "$IFACE" ] && { echo "❌ Nenhuma interface WiFi detectada"; exit 1; }

WIFI_GW="${WIFI_GW:-$(ip route show | grep "$IFACE" | grep default | awk '{print $3}' | head -1)}"
IP_IFACE=$(ip -br a show "$IFACE" 2>/dev/null | awk '{print $3}')

echo "=== fast.com via WiFi ==="
echo "Interface: $IFACE ($IP_IFACE)"
echo "Gateway WiFi: ${WIFI_GW:-não encontrado}"

# ====== 1. Pega os servidores de teste da Netflix ======
url=$(curl -s --max-time 10 "https://api.fast.com/netflix/speedtest/v2?https=true&token=$FAST_TOKEN&urlCount=1" \
      | grep -oE '"url":"https://[^"]+"' | head -1 | cut -d'"' -f4)
[ -z "$url" ] && { echo "❌ API do fast.com não respondeu"; exit 1; }

host=$(echo "$url" | sed -E 's|https://([^/]+)/.*|\1|')
echo "Servidor Netflix: $host"

# ====== 2. Rotas /32 via WiFi para os IPs do servidor (precisa sudo) ======
added=""
cleanup() { for ip in $added; do sudo ip route del "$ip/32" 2>/dev/null; done; }
trap cleanup EXIT

if sudo -n true 2>/dev/null; then
    if [ -z "$WIFI_GW" ]; then
        echo "❌ Sem default route via $IFACE — informe WIFI_GW=... manualmente"
        exit 1
    fi
    for ip in $(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u); do
        sudo ip route add "$ip/32" via "$WIFI_GW" dev "$IFACE" 2>/dev/null && added="$added $ip"
    done
    [ -n "$added" ] && echo "✅ Rotas /32 via WiFi adicionadas:$(echo $added | tr ' ' '\n' | sed 's/^/  /')"
else
    echo "⚠️ sudo sem senha não disponível — teste seguirá a rota default (pode sair pelo CABO!)"
fi

# ====== 3. Medição ======
echo ""
echo "⏳ Medindo ($ROUNDS rodadas)..."
total=0; max=0
for i in $(seq 1 "$ROUNDS"); do
    r=$(curl -s --interface "$IFACE" --max-time 25 -o /dev/null -w '%{speed_download}' "$url")
    if [ -n "$r" ] && [ "$r" -gt 0 ] 2>/dev/null; then
        printf "   rodada %d: %d B/s (%.1f MB/s = %.1f Mbps)\n" "$i" "$r" \
               "$(echo "$r" | awk '{printf "%.1f", $1/1048576}')" \
               "$(echo "$r" | awk '{printf "%.1f", $1*8/1000000}')"
        total=$((total + r)); [ "$r" -gt "$max" ] && max=$r
    else
        echo "   rodada $i: falhou"
    fi
done

if [ "$max" -gt 0 ] 2>/dev/null; then
    echo ""
    printf "🏁 Máxima: %.1f MB/s = %.1f Mbps via %s\n" \
           "$(echo "$max" | awk '{printf "%.1f", $1/1048576}')" \
           "$(echo "$max" | awk '{printf "%.1f", $1*8/1000000}')" "$IFACE"
fi


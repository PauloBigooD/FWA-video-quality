#!/bin/bash
# ================================================================
# run-phase.sh — uma fase do experimento DASH (versão canônica)
# ================================================================
# WiFi deve estar conectado antes (wifi-route.sh no @reboot).
# Este script: limpa monitores → inicia monitor → executa DASH → mata monitor.
#
# Variáveis esperadas no crontab (o cron sabe a fase — não adivinhe):
#   CLIENT_ID=nb1                 # identificação do cliente
#   PHASE=1_cliente               # fase: 1_cliente | 3_clientes | 5_clientes
#   DASH_URL=https://172.31.0.220 # https é obrigatório p/ QUIC/HTTP3
#
# Uso manual:
#   PHASE=5_clientes bash run-phase.sh
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/run-phase-${CLIENT_ID:-$(hostname)}.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

export CLIENT_ID="${CLIENT_ID:-$(hostname)}"
export PHASE="${PHASE:-?}"
export DASH_URL="${DASH_URL:-https://172.31.0.220}"
# ⚠️ TEMPORÁRIO (18/Ago): UDP 443 bloqueado no caminho WiFi → fallback h2.
# Quando o QUIC voltar (probe UDP responder), troque o default para true.
export FORCE_QUIC="${FORCE_QUIC:-false}"
PING_TARGET="${PING_TARGET:-172.31.0.220}"
METRICS_URL="${METRICS_URL:-http://192.168.110.41:8888/metrics}"

log "▶ Iniciando fase — $CLIENT_ID ($PHASE)"

# ── 0. Limpa monitores antigos ─────────────────────
pkill -f "wifi-monitor.py" 2>/dev/null || true
sleep 1

# ── 1. Inicia monitor (fase explícita vinda do cron) ──
log "📊 Iniciando wifi-monitor (phase=$PHASE)..."
python3 "$SCRIPT_DIR/wifi-monitor.py" \
    --id "$CLIENT_ID" \
    --phase "$PHASE" \
    --ping-target "$PING_TARGET" \
    --server "$METRICS_URL" \
    >> /tmp/wifi-monitor-${CLIENT_ID}.log 2>&1 &
MONITOR_PID=$!
sleep 2

# ── 2. Experimento DASH ────────────────────────────
log "🎬 DASH: $DASH_URL"
cd "$SCRIPT_DIR" || exit 1
export HEADLESS="${HEADLESS:-true}"
export COLLECTOR_URL="${COLLECTOR_URL:-http://192.168.110.41:9999/upload}"
/usr/bin/npm start >> /tmp/dash-${CLIENT_ID}.log 2>&1
log "🎬 DASH finalizado (exit=$?)"

# ── 3. Mata monitor ────────────────────────────────
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true
log "✅ Fase concluída"

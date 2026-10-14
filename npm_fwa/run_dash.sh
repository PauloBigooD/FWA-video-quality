#!/bin/bash
# ============================================================
# Script de coleta DASH — roda em cada notebook cliente
# ============================================================
# Uso:
#   DASH_URL=https://172.31.0.220 DURATION_SEC=180 CLIENT_ID=nb1 bash run_dash.sh
#
# Ou via cron (a cada 10 min):
#   */10 * * * * DURATION_SEC=180 CLIENT_ID=nb1 bash ~/fwa/run_dash.sh

export PATH=$PATH:/usr/local/bin:/usr/bin
cd "$(dirname "$0")"   # funciona de qualquer diretório (~/fwa, /tmp/fwa, etc.)

# Configurações via env vars (com defaults)
export DASH_URL="${DASH_URL:-https://172.31.0.220}"   # https é obrigatório p/ QUIC/HTTP3 (http cai em HTTP/1.1)
export DURATION_SEC="${DURATION_SEC:-180}"
export CLIENT_ID="${CLIENT_ID:-$(hostname)}"
export COLLECTOR_URL="${COLLECTOR_URL:-http://192.168.110.41:9999/upload}"
export HEADLESS="${HEADLESS:-false}"

echo "[$(date)] 🚀 Iniciando coleta DASH — $CLIENT_ID ($DASH_URL, ${DURATION_SEC}s)" >> ~/har_logs/cron.log
/usr/bin/npm start >> ~/har_logs/cron.log 2>&1
echo "[$(date)] ✅ Coleta finalizada — $CLIENT_ID" >> ~/har_logs/cron.log


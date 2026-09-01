#!/usr/bin/env bash

set -u
set -o pipefail

CACHE_DIR="/tmp/speedtest-lan"
LOCK_FILE="/tmp/speedtest-lan.lock"

PING_COUNT=4
PING_TIMEOUT=2

IPERF_TIMEOUT=15
IPERF_TIME=5
UDP_BANDWIDTH="100M"

mkdir -p "$CACHE_DIR"

# Lista de servidores
declare -A SERVERS=(
  ["172.31.0.61"]="Server Web"
)

log_error() {
  echo "[ERROR] $1" >&2
}

acquire_lock() {
  if [ -e "$LOCK_FILE" ]; then
    log_error "Another test is running"
    exit 2
  fi
  touch "$LOCK_FILE"
  trap "rm -f $LOCK_FILE" EXIT
}

# ==========================
# PING (fallback simples)
# ==========================
run_ping() {
  local ip="$1"
  local output

  output=$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$ip" 2>/dev/null | tail -1 | awk '{print $4}') || true

  if [ -z "$output" ]; then
    echo "0"
  else
    echo "$output" | cut -d '/' -f 2
  fi
}

# ==========================
# TCP TEST (Download/Upload)
# ==========================
run_iperf_tcp() {
  local ip="$1"
  local mode="$2"
  local json

  if [ "$mode" = "download" ]; then
    json=$(timeout "$IPERF_TIMEOUT" iperf3 -c "$ip" -R -t "$IPERF_TIME" --json 2>/dev/null) || true
  else
    json=$(timeout "$IPERF_TIMEOUT" iperf3 -c "$ip" -t "$IPERF_TIME" --json 2>/dev/null) || true
  fi

  if [ -z "$json" ]; then
    echo "0"
    return
  fi

  echo "$json" | jq -r '.end.sum_received.bits_per_second // 0' 2>/dev/null | awk '{print $1/1000000}'
}

# ==========================
# UDP TEST (JITTER REAL)
# ==========================
run_iperf_udp() {
  local ip="$1"
  local json

  json=$(timeout "$IPERF_TIMEOUT" iperf3 -c "$ip" -u -b "$UDP_BANDWIDTH" -t "$IPERF_TIME" --json 2>/dev/null) || true

  if [ -z "$json" ]; then
    echo "0 0 0"
    return
  fi

  jitter=$(echo "$json" | jq -r '.end.sum.jitter_ms // 0')
  loss=$(echo "$json" | jq -r '.end.sum.lost_percent // 0')
  bitrate=$(echo "$json" | jq -r '.end.sum.bits_per_second // 0')

  bitrate_mbps=$(echo "$bitrate" | awk '{print $1/1000000}')

  echo "$jitter $loss $bitrate_mbps"
}

# ==========================
# EXECUÇÃO COMPLETA
# ==========================
run_test() {
  local ip="$1"
  local name="$2"
  local file="$CACHE_DIR/$ip.json"

  ping=$(run_ping "$ip")

  download=$(run_iperf_tcp "$ip" "download")
  upload=$(run_iperf_tcp "$ip" "upload")

  read jitter loss udp_bw < <(run_iperf_udp "$ip")

  timestamp=$(date +%s)

  cat <<EOF > "$file"
{
  "server": "$name",
  "ip": "$ip",
  "timestamp": $timestamp,
  "metrics": {
    "ping_ms": $ping,
    "tcp": {
      "download_mbps": $download,
      "upload_mbps": $upload
    },
    "udp": {
      "jitter_ms": $jitter,
      "packet_loss_percent": $loss,
      "bandwidth_mbps": $udp_bw
    }
  }
}
EOF
}

run_all() {
  acquire_lock
  for ip in "${!SERVERS[@]}"; do
    run_test "$ip" "${SERVERS[$ip]}"
  done
}

# ==========================
# GETTERS
# ==========================
get_json() {
  cat "$CACHE_DIR/$1.json"
}

get_metric() {
  local ip="$1"
  local jq_filter="$2"

  if [ ! -f "$CACHE_DIR/$ip.json" ]; then
    log_error "No data"
    exit 2
  fi

  jq -r "$jq_filter // 0" "$CACHE_DIR/$ip.json"
}

# ==========================
# DISCOVERY
# ==========================
discovery() {
  echo '{ "data": ['
  local first=1
  for ip in "${!SERVERS[@]}"; do
    [ $first -ne 1 ] && echo ","
    first=0
    echo -n "{\"{#IP}\":\"$ip\",\"{#NAME}\":\"${SERVERS[$ip]}\"}"
  done
  echo '] }'
}

# ==========================
# CLI
# ==========================
case "${1:-}" in
  -a)
    run_all
    ;;
  -l)
    acquire_lock
    run_test "$2" "${SERVERS[$2]:-Unknown}"
    ;;
  -j)
    get_json "$2"
    ;;
  -p)
    get_metric "$2" '.metrics.ping_ms'
    ;;
  -d)
    get_metric "$2" '.metrics.tcp.download_mbps'
    ;;
  -u)
    get_metric "$2" '.metrics.tcp.upload_mbps'
    ;;
  -t)
    get_metric "$2" '.metrics.udp.jitter_ms'
    ;;
  -loss)
    get_metric "$2" '.metrics.udp.packet_loss_percent'
    ;;
  -g)
    discovery
    ;;
  *)
    echo "Usage:"
    echo "  -a                Run all tests"
    echo "  -l <ip>           Run test"
    echo "  -j <ip>           Full JSON"
    echo "  -p <ip>           Ping"
    echo "  -d <ip>           Download TCP"
    echo "  -u <ip>           Upload TCP"
    echo "  -t <ip>           UDP Jitter"
    echo "  -loss <ip>        Packet loss"
    echo "  -g                Discovery"
    ;;
esac

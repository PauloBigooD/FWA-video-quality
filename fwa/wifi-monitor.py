#!/usr/bin/env python3
"""
Monitor de throughput WiFi + latência — envia métricas para o wifi-collector.
Roda em cada notebook durante os experimentos.

Uso (via run-phase.sh, que passa a fase vinda do cron):
  python3 wifi-monitor.py --id nb1 --phase 5_clientes --ping-target 172.31.0.220

--phase explícito é o caminho correto: o cron sabe a fase de cada linha.
--auto-phase (fallback) detecta pelo minuto local na grade 0/4/8 min
dentro de cada bloco de 12 min (0→1_cliente, 4→3_clientes, 8→5_clientes).
"""

import time
import sys
import re
import socket
import argparse
import urllib.request
import subprocess
from datetime import datetime
from pathlib import Path


def get_wifi_stats(iface: str) -> dict:
    """Lê RX/TX bytes da interface WiFi."""
    base = Path(f"/sys/class/net/{iface}/statistics")
    if not base.exists():
        return None
    return {
        "rx_bytes": int((base / "rx_bytes").read_text().strip()),
        "tx_bytes": int((base / "tx_bytes").read_text().strip()),
    }


def detect_wifi_iface() -> str:
    """Detecta interface WiFi automaticamente."""
    out = subprocess.run(["ip", "-br", "a", "show"], capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("wl"):
            return line.split()[0]
    return None


def detect_phase() -> str:
    """Fase pelo minuto local: bloco de 12 min, slots em 0/4/8 min."""
    minute = datetime.now().minute % 12
    return {0: "1_cliente", 4: "3_clientes", 8: "5_clientes"}.get(minute, "")


def measure_rtt(target):
    """Pinga o alvo uma vez e retorna RTT em ms, ou None se falhar."""
    try:
        out = subprocess.run(
            ["ping", "-c", "1", "-W", "1", target],
            capture_output=True, text=True, timeout=2,
        )
        if out.returncode == 0:
            match = re.search(r"time=([\d.]+)\s*ms", out.stdout)
            if match:
                return float(match.group(1))
    except Exception:
        pass
    return None


def send_metrics(server_url, metrics):
    """Envia métricas no formato linha por linha."""
    try:
        data = "\n".join(metrics).encode()
        req = urllib.request.Request(server_url, data=data, method="POST")
        req.add_header("Content-Type", "text/plain")
        urllib.request.urlopen(req, timeout=2)
    except Exception:
        pass  # silencioso — não atrapalha o experimento


def main():
    parser = argparse.ArgumentParser(description="WiFi throughput + latency monitor")
    parser.add_argument(
        "--server", default="http://192.168.110.41:8888/metrics",
        help="WiFi collector endpoint")
    parser.add_argument("--id", default=None, help="Client ID (ex: nb1)")
    parser.add_argument("--phase", default="",
                        help="Fase manual (ex: 5_clientes). Use este — o cron sabe a fase.")
    parser.add_argument("--auto-phase", action="store_true",
                        help="Detectar fase automaticamente pelo minuto da hora (fallback)")
    parser.add_argument("--ping-target", default=None,
                        help="IP do alvo para medir latência (ex: 172.31.0.220)")
    parser.add_argument("--interval", type=float, default=1.0,
                        help="Intervalo de coleta em segundos")
    args = parser.parse_args()

    client_id = args.id or socket.gethostname()
    auto_phase = args.auto_phase
    manual_phase = args.phase
    iface = detect_wifi_iface()
    if not iface:
        print("❌ Nenhuma interface WiFi detectada", file=sys.stderr)
        sys.exit(1)

    ping_target = args.ping_target

    def current_phase() -> str:
        """Retorna a fase atual (manual do cron ou auto-detectada)."""
        if auto_phase:
            return detect_phase()
        return manual_phase

    phase = current_phase()
    print(f"📡 Monitorando {iface} → {args.server} "
          f"(client: {client_id}, phase: {phase or '?'}, "
          f"auto: {auto_phase})",
          file=sys.stderr)
    if ping_target:
        print(f"   🏓 Ping target: {ping_target}", file=sys.stderr)

    prev = get_wifi_stats(iface)
    prev_time = time.time()
    prev_rtt = None       # para calcular jitter
    ping_counter = 0      # ping a cada 2 ciclos (~2s)
    iteration = 0

    while True:
        time.sleep(args.interval)
        curr = get_wifi_stats(iface)
        curr_time = time.time()
        if not curr:
            continue

        # Reavaliar fase a cada 60 iterações (~60s)
        iteration += 1
        if auto_phase and iteration % 60 == 0:
            new_phase = detect_phase()
            if new_phase != phase:
                phase = new_phase
                print(f"   🔄 Fase alterada → {phase or '?'}", file=sys.stderr)

        phase_tag = f",phase={phase}" if phase else ""
        delta_t = curr_time - prev_time
        lines = []

        # WiFi throughput (sempre)
        if delta_t > 0 and prev:
            lines.append(
                f"wifi_rx_bps,client={client_id}{phase_tag} "
                f"value={int((curr['rx_bytes'] - prev['rx_bytes']) * 8 / delta_t)}"
            )
            lines.append(
                f"wifi_tx_bps,client={client_id}{phase_tag} "
                f"value={int((curr['tx_bytes'] - prev['tx_bytes']) * 8 / delta_t)}"
            )

        # Latência + jitter (a cada 2 ciclos, pra não poluir a rede)
        if ping_target:
            ping_counter += 1
            if ping_counter >= 2:
                ping_counter = 0
                rtt = measure_rtt(ping_target)
                if rtt is not None:
                    lines.append(
                        f"wifi_rtt_ms,client={client_id}{phase_tag} value={round(rtt, 2)}"
                    )
                    if prev_rtt is not None:
                        jitter = abs(rtt - prev_rtt)
                        lines.append(
                            f"wifi_jitter_ms,client={client_id}{phase_tag} value={round(jitter, 2)}"
                        )
                    prev_rtt = rtt

        if lines:
            send_metrics(args.server, lines)

        prev = curr
        prev_time = curr_time


if __name__ == "__main__":
    main()


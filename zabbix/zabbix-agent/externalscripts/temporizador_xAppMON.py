#!/usr/bin/env python3

import subprocess
import time
import csv
import re
import shutil

NUM_SAMPLES = 50
XAPP_PATH = "/home/paulo/O-RAN_Monitoring/flexric/build/examples/xApp/c/monitor/xappMON"
OUTPUT_CSV = "/tmp/xapp_benchmark_results.csv"

ENABLE_ZABBIX = True
ZABBIX_SERVER = "172.31.0.61"
ZABBIX_PORT = "10051"
ZABBIX_HOST = "NexusAI"
ZABBIX_KEY  = "oran.e2.latency"

def send_to_zabbix_real(value):
    if not ENABLE_ZABBIX:
        return 0.0

    zabbix_sender_bin = shutil.which("zabbix_sender")
    if not zabbix_sender_bin:
        return 0.0

    cmd = [
        zabbix_sender_bin,
        "-z", ZABBIX_SERVER,
        "-p", ZABBIX_PORT,
        "-s", ZABBIX_HOST,
        "-k", ZABBIX_KEY,
        "-o", str(value)
    ]

    t_start = time.perf_counter()
    subprocess.run(cmd, capture_output=True, text=True)
    t_end = time.perf_counter()

    return (t_end - t_start) * 1000.0


def parse_c_output(stdout_text):
    e42_init = 0.0
    e2_query = 0.0
    total_xapp = 0.0

    match_init  = re.search(r"E42 API Init Time:\s*([\d\.]+)\s*ms", stdout_text)
    match_e2    = re.search(r"E2 Request/Response:\s*([\d\.]+)\s*ms", stdout_text)
    match_total = re.search(r"Total C-Core Execution:\s*([\d\.]+)\s*ms", stdout_text)

    if match_init:  e42_init = float(match_init.group(1))
    if match_e2:    e2_query = float(match_e2.group(1))
    if match_total: total_xapp = float(match_total.group(1))

    return e42_init, e2_query, total_xapp


data_samples = []

print(f"[*] Iniciando benchmark de {NUM_SAMPLES} execuções...")

for i in range(1, NUM_SAMPLES + 1):
    t_start_wall = time.perf_counter()
    
    try:
        # Usa 'stdbuf' para forçar o descarte imediato do buffer de stdout do C
        res = subprocess.run(
            ["stdbuf", "-oL", XAPP_PATH],
            capture_output=True,
            text=True,
            timeout=15
        )
        t_end_wall = time.perf_counter()
        t_wall_os = (t_end_wall - t_start_wall) * 1000.0
        
        e42_init_ms, e2_query_ms, total_xapp_ms = parse_c_output(res.stdout)

    except Exception as e:
        print(f"Erro na iteração {i}: {e}")
        continue

    t_zabbix_update = send_to_zabbix_real(value=total_xapp_ms)
    t_pipeline_total = total_xapp_ms + t_zabbix_update

    data_samples.append({
        "Sample": i,
        "E42 Init (ms)": round(e42_init_ms, 3),
        "E2 Query (ms)": round(e2_query_ms, 3),
        "xAppMON Total (ms)": round(total_xapp_ms, 2),
        "Process OS Time (ms)": round(t_wall_os, 2),
        "Zabbix Update (ms)": round(t_zabbix_update, 2),
        "Pipeline Total (ms)": round(t_pipeline_total, 2)
    })

    print(
        f"Amostra {i:02d}/{NUM_SAMPLES:02d} | "
        f"E2 Query: {e2_query_ms:.3f}ms | "
        f"xAppMON Total: {total_xapp_ms:.2f}ms | "
        f"Zabbix: {t_zabbix_update:.2f}ms | "
        f"Pipeline Total: {t_pipeline_total:.2f}ms"
    )

fieldnames = [
    "Sample", "E42 Init (ms)", "E2 Query (ms)", 
    "xAppMON Total (ms)", "Process OS Time (ms)", 
    "Zabbix Update (ms)", "Pipeline Total (ms)"
]

with open(OUTPUT_CSV, mode="w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(data_samples)

print(f"\n[+] Benchmark concluído! Dados salvos em '{OUTPUT_CSV}'.")


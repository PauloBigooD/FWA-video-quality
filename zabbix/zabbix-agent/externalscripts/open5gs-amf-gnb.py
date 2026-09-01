#!/usr/bin/env python3

## Author:    Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br
## Adaptado para Open5GS (Tratamento preciso de Conexão/Desconexão)

import json
import subprocess
import re
import sys
from typing import List


def get_docker_logs(container_name: str, tail: int = 5000) -> str:
    try:
        logs = subprocess.check_output(
            ["docker", "logs", container_name, "--tail", str(tail)],
            stderr=subprocess.STDOUT,
            text=True
        )
        return logs
    except subprocess.CalledProcessError:
        return ""

def find_containers_by_pattern(pattern: str) -> List[str]:
    try:
        output = subprocess.check_output(
            ["docker", "ps", "--format", "{{.Names}}"],
            text=True
        )
        containers = output.strip().splitlines()
        regex = re.compile(pattern)
        return [c for c in containers if regex.match(c)]
    except subprocess.CalledProcessError:
        return []

# --------------------------------------------------
# Descoberta dinâmica do container Open5GS
# --------------------------------------------------
container_pattern = r"^open5gs_5gc$"
containers = find_containers_by_pattern(container_pattern)

if not containers:
    print(json.dumps({"data": []}))
    sys.exit(0)

# --------------------------------------------------
# Coleta de logs
# --------------------------------------------------
logs = ""
for container in containers:
    container_logs = get_docker_logs(container, tail=5000)
    if container_logs:
        logs += container_logs + "\n"

if not logs.strip():
    print(json.dumps({"data": []}))
    sys.exit(0)

# --------------------------------------------------
# Parsing dos logs do Open5GS (Regex Calibrado)
# --------------------------------------------------
# Captura: gNB-N2 accepted[172.31.0.52]
connect_pattern = re.compile(r"gNB-N2 accepted\[([\d\.]+)\]")

# Captura: gNB-N2[172.31.0.54] connection refused!!! ou variações de fechamento
disconnect_pattern = re.compile(r"gNB-N2\[([\d\.]+)\] (?:connection refused|closed|released|disconnected)")

gnb_registry = {}

# Processa linha por linha cronologicamente
for line in logs.splitlines():
    # Testa Conexão
    conn_match = connect_pattern.search(line)
    if conn_match:
        ip = conn_match.group(1)
        gnb_registry[ip] = "Connected"
        continue
    
    # Testa Desconexão
    disc_match = disconnect_pattern.search(line)
    if disc_match:
        ip = disc_match.group(1)
        gnb_registry[ip] = "Disconnected"

# --------------------------------------------------
# Montagem do JSON no padrão Zabbix LLD
# --------------------------------------------------
data = {"data": []}

for idx, (ip, status) in enumerate(gnb_registry.items(), start=1):
    data["data"].append({
        "{#GNB_INDEX}": idx,
        "{#GNB_IP}": ip,
        "{#GNB_STATUS}": status
    })

# --------------------------------------------------
# Saída JSON
# --------------------------------------------------
print(json.dumps(data, indent=4))

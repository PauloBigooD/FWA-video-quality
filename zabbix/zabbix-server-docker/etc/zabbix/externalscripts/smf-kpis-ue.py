#!/usr/bin/env python3

import json
import subprocess
import re
import sys

# --------------------------------------------------
# JSON vazio padrão para exceções
# --------------------------------------------------

def print_empty_json_and_exit():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --------------------------------------------------
# Funções Docker
# --------------------------------------------------

def get_docker_logs(container_name: str, tail: int = 200000000) -> str:
    try:
        return subprocess.check_output(
            ["docker", "logs", container_name, "--tail", str(tail)],
            stderr=subprocess.STDOUT,
            text=True
        )
    except subprocess.CalledProcessError:
        return ""

def find_containers_by_pattern(pattern: str):
    try:
        output = subprocess.check_output(
            ["docker", "ps", "--format", "{{.Names}}"],
            text=True
        )
        regex = re.compile(pattern)
        return [c for c in output.splitlines() if regex.match(c)]
    except subprocess.CalledProcessError:
        return []

# --------------------------------------------------
# Descoberta dinâmica dos SMFs
# --------------------------------------------------

containers = find_containers_by_pattern(r"^oai-smf.*")

if not containers:
    print_empty_json_and_exit()

# --------------------------------------------------
# Coleta agregada de logs
# --------------------------------------------------

log_text = ""
for container in containers:
    container_logs = get_docker_logs(container)
    if container_logs:
        log_text += container_logs + "\n"

if not log_text.strip():
    print_empty_json_and_exit()

# --------------------------------------------------
# Parsing dos logs do SMF
# --------------------------------------------------

ue_pattern = re.compile(
    r"SUPI:\s*(\S+).*?"
    r"PDU Session ID:\s*(\d+).*?"
    r"DNN:\s*(\S+).*?"
    r"S-NSSAI:\s*SST=(\d+),\s*SD=([0-9A-Fa-f]+).*?"
    r"PDN type:\s*(\S+).*?"
    r"PAA IPv4:\s*(\d+\.\d+\.\d+\.\d+).*?"
    r"Default QFI:\s*(\d+).*?"
    r"UL FTEID:\s*TEID=\d+,\s*IPv4=(\d+\.\d+\.\d+\.\d+).*?"
    r"DL FTEID:\s*TEID=\d+,\s*IPv4=(\d+\.\d+\.\d+\.\d+)",
    re.DOTALL
)

ue_data = []

for match in ue_pattern.finditer(log_text):
    ue_data.append({
        "{#SUPI}": match.group(1),
        "{#PDU_SESSION_ID}": int(match.group(2)),
        "{#DNN}": match.group(3),
        "{#SST}": int(match.group(4)),
        "{#SD}": match.group(5),
        "{#PDN_TYPE}": match.group(6),
        "{#UE_IPV4}": match.group(7),
        "{#QFI}": int(match.group(8)),
        "{#UL_AMF_IP}": match.group(9),
        "{#DL_GNB_IP}": match.group(10),
    })

# --------------------------------------------------
# Saída JSON (LLD-safe)
# --------------------------------------------------

if not ue_data:
    print_empty_json_and_exit()

json_data = {"data": ue_data}
print(json.dumps(json_data, indent=4))

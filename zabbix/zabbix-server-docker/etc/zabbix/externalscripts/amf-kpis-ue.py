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

def get_docker_logs(container_name: str, tail: int = 11) -> str:
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
# Descoberta dinâmica dos AMFs
# --------------------------------------------------

containers = find_containers_by_pattern(r"^oai-amf.*")

if not containers:
    print_empty_json_and_exit()

# --------------------------------------------------
# Coleta agregada de logs
# --------------------------------------------------

logs = ""
for container in containers:
    container_logs = get_docker_logs(container)
    if container_logs:
        logs += container_logs + "\n"

if not logs.strip():
    print_empty_json_and_exit()

# --------------------------------------------------
# Parsing dos UEs
# --------------------------------------------------

ue_pattern = re.compile(
    r"\|\s*(\d+)\s*\|\s*(5GMM-[A-Z]+)\s*\|\s*(\d+)\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|\s*([\d, ]+)\s*\|\s*(\d*)\s*\|"
)

data = {"data": []}

ue_matches = list(ue_pattern.finditer(logs))

for match in ue_matches:
    index, state, imsi, guti, ran_ue_ngap_id, amf_ue_id, plmn, cell_id = match.groups()
    data["data"].append({
        "{#UE_INDEX}": int(index),
        "{#UE_5GMM}": state,
        "{#UE_IMSI}": imsi,
        "{#UE_GUTI}": guti if guti else None,
        "{#UE_RAN_NGAP_ID}": int(ran_ue_ngap_id) if ran_ue_ngap_id else None,
        "{#UE_AMF_ID}": int(amf_ue_id) if amf_ue_id else None,
        "{#UE_PLMN}": plmn.strip(),
        "{#UE_CELL_ID}": int(cell_id) if cell_id else None
    })

# --------------------------------------------------
# Saída JSON (LLD-safe)
# --------------------------------------------------

if not data["data"]:
    print_empty_json_and_exit()

print(json.dumps(data, indent=4))

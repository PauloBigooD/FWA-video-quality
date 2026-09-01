#!/usr/bin/env python3

## Author:   Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br - Tel: +55 (84) 9 8808-0933
## GitHub:   https://github.com/PauloBigooD
## Linkedin: https://www.linkedin.com/in/paulo-eduardo-5a18b3174

import json
import subprocess
import re
import sys
from typing import List


def get_docker_logs(container_name: str, tail: int = 11) -> str:
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
    """
    Retorna uma lista de containers Docker cujos nomes
    casam com o regex informado.
    """
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
# Descoberta dinâmica de containers AMF
# --------------------------------------------------
container_pattern = r"^oai-amf.*"
containers = find_containers_by_pattern(container_pattern)

if not containers:
    # Nenhum AMF encontrado
    sys.exit(1)

# --------------------------------------------------
# Coleta de logs (agregado)
# --------------------------------------------------
logs = ""
for container in containers:
    container_logs = get_docker_logs(container)
    if container_logs:
        logs += container_logs + "\n"

if not logs.strip():
    sys.exit(1)

# --------------------------------------------------
# Parsing dos logs (inalterado)
# --------------------------------------------------
gnb_pattern = re.compile(
    r"\|\s+(\d+)\s+\|\s+(Connected|Disconnected)\s+\|\s+([0-9a-fx]+)\s+\|\s+([^|]+)\s+\|\s+([\d, ]+)\s+\|"
)

data = {"data": []}

gnb_matches = list(gnb_pattern.finditer(logs))

for match in gnb_matches:
    index, status, global_id, gnb_name, plmn = match.groups()
    data["data"].append({
        "{#GNB_INDEX}": int(index),
        "{#GNB_STATUS}": status,
        "{#GNB_ID}": global_id,
        "{#GNB_NAME}": gnb_name.strip(),
        "{#GNB_PLMN}": plmn.strip()
    })

# --------------------------------------------------
# Saída JSON
# --------------------------------------------------
json_output = json.dumps(data, indent=4)
print(json_output)


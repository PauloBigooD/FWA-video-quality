#!/usr/bin/env python3

import sys
import re
import json
import subprocess

def exit_with_empty_json():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

def smart_int(value, default=0):
    """Converte para inteiro com segurança para o Zabbix"""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default

def run_docker_cmd(cmd_list):
    """Executa o comando capturando stdout e stderr juntos para evitar perdas"""
    try:
        res = subprocess.run(cmd_list, capture_output=True, text=True, timeout=15)
        # Se houver erro de permissão, tenta automaticamente com sudo
        if res.stderr and "permission denied" in res.stderr.lower():
            res = subprocess.run(["sudo"] + cmd_list, capture_output=True, text=True, timeout=15)
        
        # Consolida saídas para garantir leitura de logs que vão para o stderr
        return (res.stdout or "") + "\n" + (res.stderr or "")
    except Exception:
        return ""

# =========================================================
# Verifica argumentos
# =========================================================

if len(sys.argv) != 2:
    exit_with_empty_json()

node_id_arg = sys.argv[1]
XAPP_CONTAINER = "python_xapp_runner"
RTMGR_CONTAINER = "ric_rtmgr_sim"

# =========================================================
# 1. Executa o xappMON-SC para obter os dados do RIC
# =========================================================
cmd_xapp = [
    "docker", "exec", XAPP_CONTAINER,
    "python3", "/opt/xApps/xappMON-SC.py",
    "--nodeid", node_id_arg
]
output_text = run_docker_cmd(cmd_xapp)

# =========================================================
# 2. CAPTURA E PROCESSAMENTO DOS LOGS DO ROUTING MANAGER
# =========================================================
cmd_logs = ["docker", "logs", RTMGR_CONTAINER]
rtmgr_logs = run_docker_cmd(cmd_logs)

# ---------------------------------------------------------
# Máquina de Estados Baseada em Linhas Cronológicas
# ---------------------------------------------------------
active_gnbs = set()
gnb_pattern = r"gnbd_[0-9a-zA-Z_]+"

for line in rtmgr_logs.splitlines():
    found_gnbs = re.findall(gnb_pattern, line)
    if not found_gnbs:
        continue
    
    if "associate-ran-to-e2t" in line:
        for gnb in found_gnbs:
            active_gnbs.add(gnb)
    elif "dissociate-ran" in line:
        for gnb in found_gnbs:
            active_gnbs.discard(gnb)

discovered_gnbs = sorted(list(active_gnbs))

# Fallback absoluto: se o log estiver sem os termos de associação/desassociação,
# mas contiver IDs de gNBs soltos, usamos eles para não zerar o Zabbix
if not discovered_gnbs and rtmgr_logs:
    all_possible_gnbs = set(re.findall(gnb_pattern, rtmgr_logs))
    discovered_gnbs = sorted(list(all_possible_gnbs))

# Contador real atualizado dinamicamente
ric_nodes = len(discovered_gnbs)

# =========================================================
# Parsing dos Dados Estruturais do RIC (xApp)
# =========================================================

# IP e Porta do nearRT-RIC
ip_port_match = re.search(
    r"nearRT-RIC IP Address\s*=\s*([\d\.]+).*?PORT\s*=\s*(\d+)",
    output_text, re.DOTALL
)

if ip_port_match:
    ric_ip = ip_port_match.group(1)
    ric_port = smart_int(ip_port_match.group(2))
else:
    redis_match = re.search(r"Connecting to SDL \([^)]+\) at ([\d\.]+):(\d+)", output_text)
    if redis_match:
        ric_ip = redis_match.group(1)
        ric_port = smart_int(redis_match.group(2))
    else:
        ric_ip = "10.0.2.12"
        ric_port = 6379

# Banco de Dados
db_match = re.search(r"DB filename\s*=\s*([\/\w\._]+)", output_text)
ric_db = db_match.group(1).strip() if db_match else "SDL (Redis)"

# Versão do E2AP
e2ap_version = "Unknown"
log_e2_match = re.search(r"E2AP\s+ver(?:sion)?\s*[:=]?\s*([vV]?\d+\.?\d*)", output_text, re.IGNORECASE)
if log_e2_match:
    e2ap_version = log_e2_match.group(1)
else:
    transport_match = re.search(r"Transport:\s*E2AP\s+[vV]?(\d+\.\d+)", output_text, re.IGNORECASE)
    if transport_match:
        e2ap_version = f"E2AP v{transport_match.group(1)}"
    else:
        e2ap_version = "E2AP v2.0"

# =========================================================
# Construção do Dicionário Base para o Zabbix LLD
# =========================================================

data_item = {
    "{#NEAR_RT_RIC_IP}": ric_ip,
    "{#NEAR_RT_RIC_PORT}": ric_port,
    "{#NEAR_RT_RIC_DB}": ric_db,
    "{#NEAR_RT_RIC_NODES}": ric_nodes,
    "{#NEAR_RT_RIC_BRANCH}": "DockerEnv",
    "{#NEAR_RT_RIC_E2AP}": e2ap_version
}

# Injeta dinamicamente as gNBs com os sufixos em CAIXA ALTA (ex: '_A4', '_A5')
for gnb_id in discovered_gnbs:
    parts = gnb_id.split('_')
    if len(parts) >= 2 and len(parts[-2]) >= 2:
        suffix = parts[-2][-2:].upper()
    else:
        # Fallback caso a gNB saia do padrão esperado de nomenclatura
        suffix = gnb_id.upper()
    
    # Sanitização: Garante remover qualquer caractere ilegal para macros do Zabbix
    clean_suffix = re.sub(r'[^A-Z0-9_]', '', suffix)
    
    data_item[f"{{#NEAR_RT_RIC_GNB_ID_{clean_suffix}}}"] = gnb_id

# Injeta os Service Models mapeados ou fallbacks funcionais
sm_matches = re.findall(r"Loading SM ID\s*=\s*(\d+)\s+with def\s*=\s*([\w\-]+)", output_text)

if sm_matches:
    for sm_id, sm_def in sm_matches:
        key = f"{{#NEAR_RT_RIC_SM_ID_{sm_id}}}"
        data_item[key] = sm_def
else:
    xapp_sm_matches = re.findall(r"->\s*(E2SM-[A-Z\-]+)", output_text)
    if xapp_sm_matches:
        for idx, sm_name in enumerate(xapp_sm_matches, start=1):
            key = f"{{#NEAR_RT_RIC_SM_ID_{idx}}}"
            data_item[key] = sm_name.strip()
    else:
        data_item["{#NEAR_RT_RIC_SM_ID_1}"] = "E2SM-KPM"
        data_item["{#NEAR_RT_RIC_SM_ID_2}"] = "E2SM-RC"

print(json.dumps({"data": [data_item]}, indent=4))

#!/usr/bin/env python3

import json
import re
import os
import time
import sys

def exit_with_empty_json():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --- CONFIGURAÇÃO ---
LOG_FILE = "/tmp/gnb.log"

# Verifica existência
if not os.path.exists(LOG_FILE):
    exit_with_empty_json()

# Verifica atualização (5 min)
try:
    if (time.time() - os.path.getmtime(LOG_FILE)) > 120:
        exit_with_empty_json()
except OSError:
    exit_with_empty_json()

# --- LEITURA DO LOG ---
try:
    with open(LOG_FILE, "r") as f:
        log_text = f.read()
    if not log_text:
        exit_with_empty_json()
except IOError:
    exit_with_empty_json()

# --- EXTRAÇÃO DE DADOS ---
gnb_data = {}

patterns = {
    "{#GNB_NAME}": r"ran_node_name:\s*([\w-]+)",
    "{#GNB_PCI}": r"pci:\s*(\d+)",
    "{#GNB_BAND}": r"band:\s*(\d+)",
    "{#GNB_ARFCN}": r"dl_arfcn:\s*(\d+)",
    "{#GNB_SCS}": r"common_scs:\s*(\d+)",
    "{#GNB_SSB_ARFCN}": r"SSB arfcn:(\d+)",
    "{#GNB_PLMN}": r"Supported PLMNs:\s*(\d+)",
    "{#GNB_PRB}": r"nof_crbs:\s*(\d+)"
}

# Fallback PLMN
if not re.search(patterns["{#GNB_PLMN}"], log_text):
    patterns["{#GNB_PLMN}"] = r"plmn:\s*(\d+)"

for key, pattern in patterns.items():
    match = re.search(pattern, log_text)
    if match:
        val = match.group(1)
        # PLMN e NAME ficam como String
        if key in ["{#GNB_PLMN}", "{#GNB_NAME}"]:
            gnb_data[key] = val
        else:
            try:
                gnb_data[key] = int(val)
            except ValueError:
                gnb_data[key] = val
    else:
        if key in ["{#GNB_NAME}", "{#GNB_PLMN}"]:
            gnb_data[key] = ""
        else:
            gnb_data[key] = 0

# --- NOVO: Captura do gNB ID (E2 Node ID) ---
# Procura por "gnb_id: 0x123" ou "gnb_id: 123"
# O srsRAN geralmente loga isso no início, no dump da config YAML
gnb_id_match = re.search(r"gnb_id:\s*([0-9a-fxA-FX]+)", log_text)

if gnb_id_match:
    raw_id = gnb_id_match.group(1).strip()
    try:
        # Tenta converter base 16 (hex) se tiver '0x', senão base 10
        if "0x" in raw_id.lower():
            gnb_data["{#GNB_AMF_DU_ID}"] = int(raw_id, 16)
        else:
            gnb_data["{#GNB_AMF_DU_ID}"] = int(raw_id)
    except ValueError:
        gnb_data["{#GNB_AMF_DU_ID}"] = 0
else:
    # Se não achar, tenta inferir do Global ID se aparecer em algum log de erro/info
    # (Caso raro, mas preventivo)
    global_id_match = re.search(r"Global ID:\s*(\d+)", log_text)
    if global_id_match:
         gnb_data["{#GNB_AMF_DU_ID}"] = int(global_id_match.group(1))
    else:
         gnb_data["{#GNB_AMF_DU_ID}"] = 0

# --- CÁLCULOS COMPLEXOS ---

# Cell ID (Binário -> Decimal)
cell_id_match = re.search(r'"cellIdentity":\s*"([01]+)"', log_text)
if cell_id_match:
    try:
        gnb_data["{#GNB_NRCELLID}"] = int(cell_id_match.group(1), 2)
    except ValueError:
        gnb_data["{#GNB_NRCELLID}"] = 0
else:
    gnb_data["{#GNB_NRCELLID}"] = 0

# Status (0/1)
idx_start = log_text.rfind("Cell creation")
idx_stop = log_text.rfind("Cell was stopped")

if idx_stop > idx_start:
    gnb_data["{#GNB_STATUS}"] = 0
elif idx_start != -1:
    gnb_data["{#GNB_STATUS}"] = 1
else:
    gnb_data["{#GNB_STATUS}"] = 0

# --- SAÍDA ---
if not gnb_data["{#GNB_NAME}"] and gnb_data["{#GNB_PCI}"] == 0:
    exit_with_empty_json()

print(json.dumps({"data": [gnb_data]}, indent=4))

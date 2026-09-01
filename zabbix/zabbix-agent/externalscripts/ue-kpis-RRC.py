#!/usr/bin/env python3

import sys
import re

from zbx_common import (
    fail,
    validate_file,
    check_file_timeout,
    read_last_lines,
    smart_convert
)

# =========================================================
# Verifica argumentos
# =========================================================

if len(sys.argv) != 2:
    fail()

file_path = sys.argv[1]

# =========================================================
# Validação do arquivo
# =========================================================

validate_file(file_path)
check_file_timeout(file_path, 120)

# =========================================================
# Leitura otimizada do log
# =========================================================

log_text = read_last_lines(file_path, 1000)

# =========================================================
# Verifica conteúdo
# =========================================================

if not log_text:
    fail()

# =========================================================
# Expressões regulares das métricas UE
# =========================================================

patterns = {

    "{#RRC_ACTIVITY}": r"last RRC activity:\s+(\d+)",
    "{#PDU_ID}": r"PDU session\s+(\d+)",
    "{#RSRP}": r"RSRP (-?[\d\.]+) dBm",
    "{#RSRQ}": r"RSRQ (-?[\d\.]+) dB",
    "{#SINR}": r"SINR ([\d\.]+) dB",
    "{#PDU_UE_ID}": r"PDU session\s+\d+\s+ID\s+(\d+)",
    "{#TYPE_DU}": r"associated DU:\s+\((.*?)\)",
    "{#CU_UE_ID}": r"CU UE ID (\d+)",
    "{#RNTI}": r"RNTI ([0-9a-fA-F]+)",
    "{#DU_UE_ID}": r"DU UE ID (\d+)"
}

# =========================================================
# Regex para blocos de UE
# =========================================================

ue_block_pattern = re.compile(
    r"UE \d+ CU UE ID.*?(?:\n\s+.*)+",
    re.MULTILINE
)

# =========================================================
# Lista final de UEs
# =========================================================

all_ues_data = []

# =========================================================
# Itera sobre blocos UE
# =========================================================

for match in ue_block_pattern.finditer(log_text):

    block_text = match.group(0)

    ue_data = {

        "{#RSRP}": None,
        "{#RSRQ}": None,
        "{#SINR}": None
    }

    # =====================================================
    # Extração das métricas da UE
    # =====================================================

    for key, pattern in patterns.items():

        value_match = re.search(pattern, block_text)

        if value_match:

            value = smart_convert(
                value_match.group(1)
            )

            ue_data[key] = value

    # =====================================================
    # Adiciona apenas UEs válidas
    # =====================================================

    if ue_data.get("{#RNTI}"):

        all_ues_data.append(ue_data)

# =========================================================
# Verifica descoberta válida
# =========================================================

if not all_ues_data:
    fail()

# =========================================================
# JSON final
# =========================================================

json_data = {
    "data": all_ues_data
}

# =========================================================
# Impressão final
# =========================================================

import json

print(json.dumps(json_data, indent=4))

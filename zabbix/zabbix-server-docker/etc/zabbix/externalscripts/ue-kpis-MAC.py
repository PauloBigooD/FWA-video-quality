#!/usr/bin/env python3

import sys
import re

from zbx_common import (
    fail,
    validate_file,
    check_file_timeout,
    read_last_lines,
    build_lld_json
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

# Aumentado para 1 hora; ajuste conforme necessário
check_file_timeout(file_path, 3600)

# =========================================================
# Leitura otimizada do log
# =========================================================

# 10 UEs x ~5 linhas cada -> 300 linhas é mais do que suficiente
log_text = read_last_lines(file_path, 300)

# =========================================================
# Divide o log em blocos por UE
# Cada bloco começa com:
#   UE RNTI <rnti> CU-UE-ID ...
# e termina antes do próximo "UE RNTI" ou EOF
# =========================================================

block_pattern = re.compile(
    r"(UE RNTI\s+[0-9a-fA-F]+\s+CU-UE-ID.*?)(?=^UE RNTI\s+[0-9a-fA-F]+\s+CU-UE-ID|\Z)",
    re.MULTILINE | re.DOTALL
)

blocks = block_pattern.findall(log_text)

# Lista final para LLD
lld_data = []

# =========================================================
# Processa cada UE individualmente
# =========================================================

for block in blocks:
    ue = {}

    # -----------------------------------------------------
    # Cabeçalho principal
    # -----------------------------------------------------
    m = re.search(
        r"UE RNTI\s+([0-9a-fA-F]+)\s+CU-UE-ID\s+(\d+).*?"
        r"PH\s+(\d+)\s+dB\s+PCMAX\s+(\d+)\s+dBm,\s+"
        r"average RSRP\s+(-?\d+)",
        block,
        re.DOTALL
    )

    if not m:
        continue

    ue["{#MAC_UE_RNTI}"] = m.group(1).lower()
    ue["{#MAC_CU_UE_ID}"] = int(m.group(2))
    ue["{#MAC_PH}"] = int(m.group(3))
    ue["{#MAC_PCMAX}"] = int(m.group(4))
    ue["{#MAC_AVG_RSRP}"] = int(m.group(5))

    # -----------------------------------------------------
    # DL metrics
    # -----------------------------------------------------
    m = re.search(
        r"dlsch_rounds\s+([\d/]+),\s+"
        r"dlsch_errors\s+(\d+),\s+"
        r"pucch0_DTX\s+(\d+).*?"
        r"BLER\s+([\d\.]+)",
        block,
        re.DOTALL
    )

    if m:
        ue["{#MAC_DLSCH_ROUNDS}"] = m.group(1)
        ue["{#MAC_DLSCH_ERRORS}"] = int(m.group(2))
        ue["{#MAC_PUCCH0_DTX}"] = int(m.group(3))
        ue["{#MAC_DL_BLER}"] = float(m.group(4))

    # -----------------------------------------------------
    # UL metrics
    # -----------------------------------------------------
    m = re.search(
        r"ulsch_rounds\s+([\d/]+),\s+"
        r"ulsch_errors\s+(\d+),\s+"
        r"ulsch_DTX\s+(\d+),\s+"
        r"BLER\s+([\d\.]+).*?"
        r"\(Qm\s+(\d+)\s+deltaMCS\s+(-?\d+)\s+dB\)\s+"
        r"NPRB\s+(\d+)",
        block,
        re.DOTALL
    )

    if m:
        ue["{#MAC_ULSCH_ROUNDS}"] = m.group(1)
        ue["{#MAC_ULSCH_ERRORS}"] = int(m.group(2))
        ue["{#MAC_ULSCH_DTX}"] = int(m.group(3))
        ue["{#MAC_UL_BLER}"] = float(m.group(4))
        ue["{#MAC_QM}"] = int(m.group(5))
        ue["{#MAC_DELTA_MCS}"] = int(m.group(6))
        ue["{#MAC_NPRB}"] = int(m.group(7))

    # -----------------------------------------------------
    # MAC TX/RX
    # -----------------------------------------------------
    m = re.search(
        r"MAC:\s*TX\s*(\d+)\s*RX\s*(\d+)\s*bytes",
        block
    )

    if m:
        ue["{#MAC_MAC_TX}"] = int(m.group(1))
        ue["{#MAC_MAC_RX}"] = int(m.group(2))

    # -----------------------------------------------------
    # LCIDs (1, 2, 4)
    # -----------------------------------------------------
    for lcid in [1, 2, 4]:
        m = re.search(
            fr"LCID {lcid}:\s*TX\s*(\d+)\s*RX\s*(\d+)",
            block
        )

        if m:
            ue[f"{{#MAC_LCID_{lcid}_TX}}"] = int(m.group(1))
            ue[f"{{#MAC_LCID_{lcid}_RX}}"] = int(m.group(2))

    # -----------------------------------------------------
    # SNR (primeiro valor numérico após "SNR")
    # Ex.: SNR 22.4 (+2.4) dB
    # -----------------------------------------------------
    m = re.search(r"SNR\s+([\d\.]+)", block)

    if m:
        ue["{#MAC_SNR}"] = float(m.group(1))

    # Adiciona UE à lista final
    if ue:
        lld_data.append(ue)

# =========================================================
# Geração do JSON final
# =========================================================

# build_lld_json espera um dicionário (1 item).
# Para múltiplos UEs, chamamos diretamente o formato LLD.
import json
print(json.dumps({"data": lld_data}, indent=4))

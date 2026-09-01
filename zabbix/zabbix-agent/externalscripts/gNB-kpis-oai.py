#!/usr/bin/env python3

import sys

from zbx_common import (
    fail,
    validate_file,
    check_file_timeout,
    read_last_lines,
    parse_patterns,
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
check_file_timeout(file_path, 120)

# =========================================================
# Leitura otimizada do log
# =========================================================

log_text = read_last_lines(file_path, 200)

# =========================================================
# Expressões regulares
# =========================================================

patterns = {

    "{#GNB_NRCELLID}": r"nrCellID\s+(\d+)",
    "{#GNB_PCI}": r"PCI\s+(\d+)",
    "{#GNB_SSB_ARFCN}": r"SSB ARFCN\s+(\d+)",
    "{#GNB_BAND}": r"band\s+(\d+)",
    "{#GNB_ARFCN}": r"ARFCN\s+(\d+)",
    "{#GNB_SCS}": r"SCS\s+(\d+)",
    "{#GNB_PRB}": r"PRB\s+(\d+)",
    "{#GNB_AMF_DU_ID}": r"DU ID\s+(\d+)",

    "{#GNB_NAME}": r"\[\d+\] DU ID \d+ \((.*?)\)",

    "{#GNB_TOTAL_CONECTED}": r"(\d+) connected DUs"
}

# =========================================================
# Extração das métricas
# =========================================================

data = parse_patterns(log_text, patterns)

# =========================================================
# JSON final
# =========================================================

build_lld_json(data)

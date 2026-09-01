#!/usr/bin/env python3

import sys
import re

from zbx_common import (
    fail,
    validate_file,
    check_file_timeout,
    read_last_lines,
    smart_convert,
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

check_file_timeout(
    file_path,
    120
)

# =========================================================
# Leitura otimizada do log
# =========================================================

log_text = read_last_lines(
    file_path,
    1500
)

if not log_text:
    fail()

# =========================================================
# Estrutura principal
# =========================================================

data = {}

# =========================================================
# Métricas globais L1
# =========================================================

global_metrics = {}

# =========================================================
# PRBs Blacklist
# =========================================================

blacklist_match = re.search(
    r"Blacklisted PRBs\s+(\d+)/(\d+)",
    log_text
)

if blacklist_match:

    global_metrics["{#L1_BLACKLISTED_PRBS}"] = int(
        blacklist_match.group(1)
    )

    global_metrics["{#L1_TOTAL_PRBS}"] = int(
        blacklist_match.group(2)
    )

# =========================================================
# I0 metrics
# =========================================================

i0_match = re.search(
    r"max_IO\s*=\s*(\d+).*?"
    r"min_I0\s*=\s*(\d+).*?"
    r"avg_I0\s*=\s*(\d+)\s*dB",
    log_text
)

if i0_match:

    global_metrics["{#L1_MAX_I0}"] = int(
        i0_match.group(1)
    )

    global_metrics["{#L1_MIN_I0}"] = int(
        i0_match.group(2)
    )

    global_metrics["{#L1_AVG_I0}"] = int(
        i0_match.group(3)
    )

# =========================================================
# PRACH I0
# =========================================================

prach_match = re.search(
    r"PRACH I0\s*=\s*([\d\.]+)\s*dB",
    log_text
)

if prach_match:

    global_metrics["{#L1_PRACH_I0}"] = float(
        prach_match.group(1)
    )

# =========================================================
# DLSCH parsing
# =========================================================

dlsch_pattern = re.compile(

    r"DLSCH RNTI (?P<RNTI>[0-9a-fA-F]+):"
    r".*?current_Qm (?P<QM>\d+),"
    r"\s*current_RI (?P<RI>\d+),"
    r"\s*total_bytes TX (?P<TX>\d+)"
)

# =========================================================
# ULSCH parsing
# =========================================================

ulsch_pattern = re.compile(

    r"ULSCH RNTI (?P<RNTI>[0-9a-fA-F]+),"
    r".*?ulsch_power\[0\]\s*(?P<POWER>[\d\.,]+)"
    r"\s*ulsch_noise_power\[0\]\s*(?P<NOISE>[\d\.,]+),"
    r"\s*sync_pos\s*(?P<SYNC>-?\d+)"
)

# =========================================================
# HARQ / DTX parsing
# =========================================================

harq_pattern = re.compile(

    r"round_trials\s*"
    r"(?P<R0>\d+).*?:"
    r"(?P<R1>\d+).*?:"
    r"(?P<R2>\d+).*?:"
    r"(?P<R3>\d+),"
    r"\s*DTX\s*(?P<DTX>\d+),"
    r"\s*current_Qm\s*(?P<UL_QM>\d+),"
    r"\s*current_RI\s*(?P<UL_RI>\d+),"
    r"\s*total_bytes RX/SCHED\s*"
    r"(?P<RX>\d+)/(?P<SCHED>\d+)"
)

# =========================================================
# DLSCH metrics
# =========================================================

for match in dlsch_pattern.finditer(log_text):

    rnti = match.group("RNTI")

    if rnti not in data:
        data[rnti] = {}

    data[rnti]["{#RNTI}"] = rnti

    data[rnti]["{#L1_DL_QM}"] = int(
        match.group("QM")
    )

    data[rnti]["{#L1_DL_RI}"] = int(
        match.group("RI")
    )

    data[rnti]["{#L1_DL_BYTES_TX}"] = int(
        match.group("TX")
    )

# =========================================================
# ULSCH metrics
# =========================================================

for match in ulsch_pattern.finditer(log_text):

    rnti = match.group("RNTI")

    if rnti not in data:
        data[rnti] = {}

    data[rnti]["{#RNTI}"] = rnti

    data[rnti]["{#L1_UL_POWER}"] = float(
        match.group("POWER").replace(",", ".")
    )

    data[rnti]["{#L1_UL_NOISE}"] = float(
        match.group("NOISE").replace(",", ".")
    )

    data[rnti]["{#L1_SYNC_POS}"] = int(
        match.group("SYNC")
    )

# =========================================================
# HARQ metrics
# =========================================================

harq_matches = list(
    harq_pattern.finditer(log_text)
)

for index, match in enumerate(harq_matches):

    if index >= len(data):
        break

    rnti = list(data.keys())[index]

    data[rnti]["{#L1_HARQ_R0}"] = int(
        match.group("R0")
    )

    data[rnti]["{#L1_HARQ_R1}"] = int(
        match.group("R1")
    )

    data[rnti]["{#L1_HARQ_R2}"] = int(
        match.group("R2")
    )

    data[rnti]["{#L1_HARQ_R3}"] = int(
        match.group("R3")
    )

    data[rnti]["{#L1_DTX}"] = int(
        match.group("DTX")
    )

    data[rnti]["{#L1_UL_QM}"] = int(
        match.group("UL_QM")
    )

    data[rnti]["{#L1_UL_RI}"] = int(
        match.group("UL_RI")
    )

    data[rnti]["{#L1_UL_BYTES_RX}"] = int(
        match.group("RX")
    )

    data[rnti]["{#L1_UL_SCHED_BYTES}"] = int(
        match.group("SCHED")
    )

# =========================================================
# Adiciona métricas globais
# =========================================================

for rnti in data:

    data[rnti].update(global_metrics)

# =========================================================
# Verifica dados válidos
# =========================================================

if not data:
    fail()

# =========================================================
# JSON final
# =========================================================

json_data = {
    "data": list(data.values())
}

build_lld_json(
    json_data["data"]
)

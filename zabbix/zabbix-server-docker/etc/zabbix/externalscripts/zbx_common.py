#!/usr/bin/env python3

import json
import os
import re
import time
from collections import deque

# =========================================================
# Retorno padrão vazio para LLD
# =========================================================


def fail():
    print(json.dumps({"data": []}, indent=4))
    exit(0)

# =========================================================
# Verifica existência do arquivo
# =========================================================


def validate_file(file_path):

    if not file_path:
        fail()

    if not os.path.isfile(file_path):
        fail()

# =========================================================
# Verifica atualização recente do arquivo
# =========================================================


def check_file_timeout(file_path, timeout=120):

    try:
        last_modified = os.path.getmtime(file_path)
        current_time = time.time()
        elapsed_time = current_time - last_modified

        if elapsed_time > timeout:
            fail()

    except Exception:
        fail()

# =========================================================
# Leitura completa do arquivo
# =========================================================


def read_log_file(log_file):

    try:
        with open(log_file, "r") as f:
            return f.read()

    except Exception:
        fail()

# =========================================================
# Leitura otimizada das últimas linhas
# =========================================================


def read_last_lines(log_file, num_lines=200):

    try:
        with open(log_file, "r") as f:
            lines = deque(f, maxlen=num_lines)

        return ''.join(lines)

    except Exception:
        fail()

# =========================================================
# Conversão segura de valores
# =========================================================


def smart_convert(value):

    if value is None:
        return None

    # Valores compostos como 0/0/0
    if "/" in value:
        return value

    # Inteiro
    if value.isdigit():
        return int(value)

    # Float positivo
    if re.match(r"^\d+\.\d+$", value):
        return float(value)

    # Float negativo
    if re.match(r"^-\d+\.\d+$", value):
        return float(value)

    # Inteiro negativo
    if re.match(r"^-\d+$", value):
        return int(value)

    return value

# =========================================================
# Parser genérico de regex
# =========================================================


def parse_patterns(log_text, patterns):

    data = {}

    for key, pattern in patterns.items():

        match = re.search(pattern, log_text)

        if match:
            data[key] = smart_convert(match.group(1))

    return data

# =========================================================
# Adiciona valores TX/RX
# =========================================================


def parse_tx_rx_block(log_text, block_name, tx_key, rx_key, data):

    pattern = rf"{block_name}:\s*TX\s*(\d+)\s*RX\s*(\d+)"

    match = re.search(pattern, log_text)

    if match:
        data[tx_key] = int(match.group(1))
        data[rx_key] = int(match.group(2))

# =========================================================
# Monta JSON final do Zabbix
# =========================================================

def build_lld_json(data):

    import json

    # =====================================================
    # Caso seja lista
    # =====================================================

    if isinstance(data, list):

        cleaned_data = []

        for item in data:

            cleaned_item = {
                k: v
                for k, v in item.items()
                if v is not None
            }

            cleaned_data.append(cleaned_item)

        print(json.dumps({
            "data": cleaned_data
        }, indent=4))

        return

    # =====================================================
    # Caso seja dicionário único
    # =====================================================

    cleaned_data = {
        k: v
        for k, v in data.items()
        if v is not None
    }

    print(json.dumps({
        "data": [cleaned_data]
    }, indent=4))


# =========================================================
# Debug opcional
# =========================================================


def debug(message, enabled=False):

    if enabled:
        print(f"[DEBUG] {message}")

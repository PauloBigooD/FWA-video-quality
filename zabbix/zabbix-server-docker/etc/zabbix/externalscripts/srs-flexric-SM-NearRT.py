#!/usr/bin/env python3

import sys
import os
import re
import json
import subprocess

from zbx_common import (
    fail,
    smart_convert,
    build_lld_json
)

# =========================================================
# Verifica argumentos
# =========================================================

if len(sys.argv) != 2:
    fail()

xapp_path = sys.argv[1]

# =========================================================
# Verifica existência do executável
# =========================================================

if not os.path.isfile(xapp_path):
    fail()

# =========================================================
# Inicialização de metadados
# =========================================================

branch_name = "Unknown"
e2ap_version = "Unknown"

# =========================================================
# Descobre diretórios do projeto
# =========================================================

project_root = None
build_dir = None

if "/build" in xapp_path:

    base_path_parts = xapp_path.split("/build")

    project_root = base_path_parts[0]

    build_dir = project_root + "/build"

# =========================================================
# Descoberta da branch Git
# =========================================================

if project_root:

    git_head_path = os.path.join(
        project_root,
        ".git",
        "HEAD"
    )

    try:

        if os.path.exists(git_head_path):

            with open(git_head_path, "r") as f:

                head_content = f.read().strip()

                # Branch normal
                if head_content.startswith("ref:"):

                    branch_name = (
                        head_content.split("/")[-1]
                    )

                # Detached HEAD
                else:

                    branch_name = (
                        head_content[:7]
                    )

        else:

            branch_name = "NoGit"

    except PermissionError:

        branch_name = "PermissionDenied"

    except Exception:

        branch_name = "ReadError"

# =========================================================
# Descoberta da versão E2AP
# =========================================================

if build_dir:

    cmake_cache_path = os.path.join(
        build_dir,
        "CMakeCache.txt"
    )

    if os.path.exists(cmake_cache_path):

        try:

            with open(
                cmake_cache_path,
                "r",
                errors="ignore"
            ) as f:

                cache_content = f.read()

                match_e2 = re.search(
                    r"E2AP_VERSION:STRING=([\w_]+)",
                    cache_content
                )

                if match_e2:

                    e2ap_version = (
                        match_e2.group(1)
                    )

                else:

                    if "E2AP_V3" in cache_content:
                        e2ap_version = "E2AP_V3"

                    elif "E2AP_V2" in cache_content:
                        e2ap_version = "E2AP_V2"

                    elif "E2AP_V1" in cache_content:
                        e2ap_version = "E2AP_V1"

        except Exception:
            pass

# =========================================================
# Executa xApp
# =========================================================

try:

    result = subprocess.run(
        [xapp_path],
        capture_output=True,
        text=True,
        timeout=5
    )

    output_text = result.stdout

except Exception:
    fail()

# =========================================================
# Verifica saída
# =========================================================

if not output_text:
    fail()

# =========================================================
# Regex principais
# =========================================================

ip_port_match = re.search(
    r"nearRT-RIC IP Address\s*=\s*([\d\.]+).*?PORT\s*=\s*(\d+)",
    output_text
)

db_match = re.search(
    r"DB filename\s*=\s*([\/\w\._]+)",
    output_text
)

nodes_match = re.search(
    r"Registered E2 Nodes\s*=\s*(\d+)",
    output_text
)

sm_matches = re.findall(
    r"Loading SM ID\s*=\s*(\d+)\s+with def\s*=\s*([\w\-]+)",
    output_text
)

# =========================================================
# Fallback E2AP via logs
# =========================================================

if e2ap_version == "Unknown":

    log_e2_match = re.search(
        r"E2AP\s+ver(?:sion)?\s*[:=]?\s*([vV]?\d+\.?\d*)",
        output_text,
        re.IGNORECASE
    )

    if log_e2_match:

        e2ap_version = (
            log_e2_match.group(1)
        )

# =========================================================
# Dicionário principal
# =========================================================

data_item = {

    "{#NEAR_RT_RIC_IP}":
        ip_port_match.group(1)
        if ip_port_match else "0.0.0.0",
    "{#NEAR_RT_RIC_PORT}":
        smart_convert(
            ip_port_match.group(2)
        ) if ip_port_match else 0,
    "{#NEAR_RT_RIC_DB}":
        db_match.group(1).strip()
        if db_match else "None",
    "{#NEAR_RT_RIC_NODES}":
        smart_convert(
            nodes_match.group(1)
        ) if nodes_match else 0,
    "{#NEAR_RT_RIC_BRANCH}":
        branch_name,
    "{#NEAR_RT_RIC_E2AP}":
        e2ap_version
}

# =========================================================
# Adiciona Service Models
# =========================================================

for sm_id, sm_def in sm_matches:
    key = f"{{#NEAR_RT_RIC_SM_ID_{sm_id}}}"
    data_item[key] = sm_def

# =========================================================
# JSON final
# =========================================================

build_lld_json(data_item)

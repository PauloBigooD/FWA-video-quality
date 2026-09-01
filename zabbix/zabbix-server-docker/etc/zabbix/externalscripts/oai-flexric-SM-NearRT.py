#!/usr/bin/env python3

import subprocess
import json
import re
import sys
import os

def exit_with_empty_json():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --- CONFIGURAÇÃO ---
cmd_find = "find /home /opt -type f -wholename '*/flexric/build/examples/xApp/c/monitor/xappMON' 2>/dev/null"

try:
    # Passo 1: Encontrar o executável
    file_path_res = subprocess.run(cmd_find, shell=True, capture_output=True, text=True, timeout=10)
    file_path = file_path_res.stdout.strip().split('\n')[0]
    
    if not file_path:
        exit_with_empty_json()

    # --- INÍCIO DA DESCOBERTA DE METADADOS ---
    branch_name = "Unknown"
    e2ap_version = "Unknown"
    
    if "/build" in file_path:
        base_path_parts = file_path.split("/build")
        project_root = base_path_parts[0] 
        build_dir = project_root + "/build"
        
        # A) Busca Branch LENDO O ARQUIVO .git/HEAD (Sem usar comando git)
        # Isso evita o erro de Dubious Ownership
        git_head_path = os.path.join(project_root, ".git", "HEAD")
        
        try:
            if os.path.exists(git_head_path):
                with open(git_head_path, "r") as f:
                    head_content = f.read().strip()
                    
                    # Se for branch: "ref: refs/heads/master"
                    if head_content.startswith("ref:"):
                        branch_name = head_content.split("/")[-1]
                    # Se for detached head (commit hash): "37e85a00..."
                    else:
                        branch_name = f"{head_content[:7]}"
            else:
                branch_name = "No .git dir found"
        except PermissionError:
            branch_name = "Linux Permission Denied (Check chmod)"
        except Exception as e:
            branch_name = f"File Read Error: {str(e)}"

        # B) Busca Versão E2AP
        cmake_cache_path = os.path.join(build_dir, "CMakeCache.txt")
        if os.path.exists(cmake_cache_path):
            try:
                with open(cmake_cache_path, "r", errors="ignore") as f:
                    cache_content = f.read()
                    match_e2 = re.search(r"E2AP_VERSION:STRING=([\w_]+)", cache_content)
                    if match_e2:
                        e2ap_version = match_e2.group(1)
                    else:
                        if "E2AP_V3" in cache_content: e2ap_version = "E2AP_V3"
                        elif "E2AP_V2" in cache_content: e2ap_version = "E2AP_V2"
                        elif "E2AP_V1" in cache_content: e2ap_version = "E2AP_V1"
            except:
                pass 

    # Passo 2: Executar o xApp
    result = subprocess.run([file_path], capture_output=True, text=True, timeout=5)
    output_text = result.stdout

    if not output_text:
        exit_with_empty_json()

except Exception:
    if 'output_text' not in locals(): exit_with_empty_json()

# --- PARSING ---
data_item = {}

ip_port_match = re.search(r"nearRT-RIC IP Address\s*=\s*([\d\.]+).*?PORT\s*=\s*(\d+)", output_text)
db_match = re.search(r"DB filename\s*=\s*([\/\w\._]+)", output_text)
nodes_match = re.search(r"Registered E2 Nodes\s*=\s*(\d+)", output_text)
sm_matches = re.findall(r"Loading SM ID\s*=\s*(\d+)\s+with def\s*=\s*([\w\-]+)", output_text)

if e2ap_version == "Unknown":
    log_e2_match = re.search(r"E2AP\s+ver(?:sion)?\s*[:=]?\s*([vV]?\d+\.?\d*)", output_text, re.IGNORECASE)
    if log_e2_match: e2ap_version = log_e2_match.group(1)

data_item["{#NEAR_RT_RIC_IP}"] = ip_port_match.group(1) if ip_port_match else "0.0.0.0"
data_item["{#NEAR_RT_RIC_PORT}"] = int(ip_port_match.group(2)) if ip_port_match else 0
data_item["{#NEAR_RT_RIC_DB}"] = db_match.group(1).strip() if db_match else "None"
data_item["{#NEAR_RT_RIC_NODES}"] = int(nodes_match.group(1)) if nodes_match else 0
data_item["{#NEAR_RT_RIC_BRANCH}"] = branch_name
data_item["{#NEAR_RT_RIC_E2AP}"] = e2ap_version

for sm_id, sm_def in sm_matches:
    key = f"{{#NEAR_RT_RIC_SM_ID_{sm_id}}}"
    data_item[key] = sm_def

print(json.dumps({"data": [data_item]}, indent=4))

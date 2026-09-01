#!/usr/bin/env python3

import subprocess
import json
import re
import sys
import os

def exit_with_empty_json():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --- CONFIGURAÇÃO DA BUSCA DINÂMICA ---
# Procura em /home e /opt pelo binário específico
CMD_FIND = "find /home/lancetelecom/lsu-oai-advanced -type f -name 'xappMON_srs' 2>/dev/null | head -n 1"
try:
    # Passo 1: Procurar o arquivo dinamicamente
    find_res = subprocess.run(CMD_FIND, shell=True, capture_output=True, text=True, timeout=10)
    file_path = find_res.stdout.strip().split('\n')[0]
    
    # Fallback se não achar pelo nome novo
    if not file_path:
        fallback_cmd = "find /home /opt -type f -name 'xappMON' 2>/dev/null | head -n 1"
        find_res_fallback = subprocess.run(fallback_cmd, shell=True, capture_output=True, text=True, timeout=10)
        file_path = find_res_fallback.stdout.strip().split('\n')[0]

    if not file_path:
        exit_with_empty_json()

    # Passo 2: Executar o xApp
    result = subprocess.run([file_path], capture_output=True, text=True, timeout=5)
    output_text = result.stdout

    if not output_text:
        exit_with_empty_json()

except subprocess.TimeoutExpired as e:
    output_text = e.stdout.decode('utf-8') if e.stdout else ""
except Exception:
    exit_with_empty_json()

# --- PARSING E FORMATAÇÃO ---
data_list = []
node_blocks = re.split(r'\[NODE \d+\] Analysis', output_text)

# Ignora o primeiro bloco (cabeçalhos gerais)
for block in node_blocks[1:]:
    node_item = {}

    # =========================================================
    # 1. DADOS BÁSICOS DO NÓ
    # =========================================================
    type_match = re.search(r"Type:\s*([\w\-]+)", block)
    mcc_match = re.search(r"MCC:\s*(\d+)", block)
    mnc_match = re.search(r"MNC:\s*(\d+)", block)
    id_match = re.search(r"Global ID:\s*(\d+)", block)
    ran_func_match = re.search(r"Supported RAN Functions:\s*(\d+)", block)

    node_item["{#E2_NODE_TYPE}"] = type_match.group(1) if type_match else "Unknown"
    node_item["{#E2_NODE_MCC}"] = int(mcc_match.group(1)) if mcc_match else 0
    node_item["{#E2_NODE_MNC}"] = int(mnc_match.group(1)) if mnc_match else 0
    node_item["{#E2_NODE_ID}"] = int(id_match.group(1)) if id_match else 0
    node_item["{#E2_NODE_E2SM_SUP}"] = int(ran_func_match.group(1)) if ran_func_match else 0

    # =========================================================
    # 2. PROCESSAMENTO: SERVICE MODEL LIST
    # =========================================================
    sm_section = re.search(r"\[\+\] Service Model List:(.*?)(?:\[\+\]|\[INFO\]|$)", block, re.DOTALL)
    
    if sm_section:
        sm_content = sm_section.group(1)
        raw_models = sm_content.split("->")

        for raw_model in raw_models:
            raw_model = raw_model.strip()
            if not raw_model: continue
            
            name_match = re.search(r"\[(.*?)\]", raw_model)
            details_match = re.search(r"ID:\s*(\d+).*?OID:\s*([\d\.]+)", raw_model, re.DOTALL)

            if name_match and details_match:
                sm_name = name_match.group(1).strip()
                sm_id = details_match.group(1).strip()
                sm_oid = details_match.group(2).strip()

                node_item[f"{{#E2_NODE_SM_NAME_{sm_id}}}"] = sm_name
                node_item[f"{{#E2_NODE_SM_ID_{sm_id}}}"] = int(sm_id)
                node_item[f"{{#E2_NODE_SM_OID_{sm_id}}}"] = sm_oid

    # =========================================================
    # 3. PROCESSAMENTO KPM
    # =========================================================
    kpm_section = re.search(r"DEEP DIVE: E2SM-KPM Capabilities(.*?)(DEEP DIVE|\[INFO\]|$)", block, re.DOTALL)
    if kpm_section:
        content = kpm_section.group(1)
        
        count_match = re.search(r"Report Styles:\s*(\d+)", content)
        style_count = int(count_match.group(1)) if count_match else 0
        node_item["{#E2_NODE_KPM_STYLES}"] = style_count

        if style_count > 0:
            node_item["{#E2_NODE_KPM_SERVICE}"] = "REPORT"
        else:
            node_item["{#E2_NODE_KPM_SERVICE}"] = "NONE"

        styles = re.split(r"Style Type:\s*", content)[1:]
        all_types = []
        for i, style_text in enumerate(styles, 1):
            suffix = f"_{i}"
            header_match = re.match(r"(\d+)\s*\|\s*ID:\s*\d+\s*\|\s*Name:\s*(.+?)\n", style_text)
            
            # --- AJUSTE 1: Converter Style Type para Inteiro ---
            style_type = int(header_match.group(1).strip()) if header_match else 0
            # ---------------------------------------------------
            
            style_name = header_match.group(2).strip() if header_match else "Unknown"
            all_types.append(style_type)
            
            node_item[f"{{#E2_NODE_KPM_STYLE_TYPE{suffix}}}"] = style_type
            node_item[f"{{#E2_NODE_KPM_STYLE_NAME{suffix}}}"] = style_name
            meas_matches = re.findall(r"-\s*([\w\.]+)", style_text)
            node_item[f"{{#E2_NODE_KPM_MEAS_LIST{suffix}}}"] = ", ".join(meas_matches) if meas_matches else "None"
        
        if len(all_types) == 1:
            node_item["{#E2_NODE_KPM_STYLE_TYPE}"] = all_types[0]

    # =========================================================
    # 4. PROCESSAMENTO RC
    # =========================================================
    rc_section = re.search(r"DEEP DIVE: E2SM-RC Capabilities(.*?)(DEEP DIVE|\[INFO\]|$)", block, re.DOTALL)
    if rc_section:
        rc_content = rc_section.group(1)
        rc_services = {"Control": "CTL", "Report": "RPT", "Query": "QRY", "Policy": "PLY", "Insert": "INS"}
        
        for svc_name, svc_abbr in rc_services.items():
            node_item[f"{{#E2_NODE_RC_{svc_abbr}_STYLES_COUNT}}"] = 0
            
        for svc_name, svc_abbr in rc_services.items():
            svc_pattern = r"-> " + svc_name + r" Styles:\s*(\d+)(.*?)(?=->|$)"
            svc_match = re.search(svc_pattern, rc_content, re.DOTALL)
            if svc_match:
                count = int(svc_match.group(1))
                svc_text = svc_match.group(2)
                node_item[f"{{#E2_NODE_RC_{svc_abbr}_STYLES_COUNT}}"] = count
                if count > 0:
                    node_item[f"{{#E2_NODE_RC_{svc_abbr}_SERVICE}}"] = svc_name.upper()
                    rc_styles = re.split(r"Style Type:\s*", svc_text)[1:]
                    
                    for i, style_text in enumerate(rc_styles, 1):
                        style_suffix = f"_{i}"
                        header_match = re.match(r"(\d+)\s*\|\s*ID:\s*\d+\s*\|\s*Name:\s*(.+?)\n", style_text)
                        
                        if header_match:
                            # --- AJUSTE 1: Converter Style Type para Inteiro ---
                            current_style_type = int(header_match.group(1).strip())
                            # ---------------------------------------------------
                            
                            node_item[f"{{#E2_NODE_RC_{svc_abbr}_STYLE_TYPE{style_suffix}}}"] = current_style_type
                            node_item[f"{{#E2_NODE_RC_{svc_abbr}_STYLE_NAME{style_suffix}}}"] = header_match.group(2).strip()
                        
                            # --- AJUSTE 2: Agrupar Actions usando o Style Type como chave ---
                            actions_parts = re.split(r">\s*Action ID:\s*", style_text)
                            action_list_ids = []
                            action_list_names = []
                            action_list_params = []

                            for action_part in actions_parts[1:]:
                                act_head_match = re.match(r"(\d+)\s*\|\s*Name:\s*(.+?)\n", action_part)
                                if act_head_match:
                                    action_id = act_head_match.group(1)
                                    action_name = act_head_match.group(2).strip()
                                    
                                    action_list_ids.append(action_id)
                                    action_list_names.append(action_name)
                                    
                                    params_matches = re.findall(r">> Param ID:.*?Name:\s*(.+?)\n", action_part)
                                    params_str = ", ".join(params_matches) if params_matches else "None"
                                    action_list_params.append(f"{params_str}")
                            
                            node_item[f"{{#E2_NODE_RC_{svc_abbr}_ACTION_LIST_ID{style_suffix}}}"] = ", ".join(action_list_ids)
                            
                            # AQUI ESTÁ A MUDANÇA SOLICITADA: Usar current_style_type na chave
                            if action_list_names:
                                node_item[f"{{#E2_NODE_RC_{svc_abbr}_ACTION_NAME_{current_style_type}}}"] = ", ".join(action_list_names)
                                node_item[f"{{#E2_NODE_RC_{svc_abbr}_ACTION_PRM_NAME_{current_style_type}}}"] = "; ".join(action_list_params)

    data_list.append(node_item)

print(json.dumps({"data": data_list}, indent=4))

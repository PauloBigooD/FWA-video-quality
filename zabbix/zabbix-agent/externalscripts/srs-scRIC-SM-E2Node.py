#!/usr/bin/env python3

import subprocess
import json
import re
import sys

def exit_with_empty_json():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# =========================================================
# Verifica argumentos
# =========================================================

if len(sys.argv) != 2:
    exit_with_empty_json()

node_id = sys.argv[1]

# =========================================================
# Executa xappMON-SC dentro do container
# =========================================================
try:
    cmd = [
        "docker",
        "exec",
        "python_xapp_runner",
        "python3",
        "/opt/xApps/xappMON-SC.py",
        "--nodeid",
        node_id
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=20
    )

    output_text = result.stdout

    if not output_text:
        exit_with_empty_json()

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    exit_with_empty_json()

# =========================================================
# Parsing
# =========================================================

data_list = []

# Separa os blocos por NODE
node_blocks = re.split(
    r"\[NODE\s+\d+\]",
    output_text
)

for block in node_blocks[1:]:
    node_item = {}

    # =====================================================
    # Compatibilidade FlexRIC
    # =====================================================
    node_item["{#E2_NODE_TYPE}"] = "gNB-DU"
    node_item["{#E2_NODE_MCC}"] = 0
    node_item["{#E2_NODE_MNC}"] = 0
    node_item["{#E2_NODE_ID}"] = node_id

    # =====================================================
    # Service Models
    # =====================================================
    sm_matches = re.findall(
        r"->\s*(E2SM-[A-Z]+).*?OID:\s*([\d\.]+)",
        block,
        re.DOTALL
    )

    node_item["{#E2_NODE_E2SM_SUP}"] = len(sm_matches)

    for sm_name, sm_oid in sm_matches:
        clean_oid = sm_oid.strip()
        
        try:
            sm_id = int(clean_oid.split('.')[-1])
        except (ValueError, IndexError):
            continue

        node_item[f"{{#E2_NODE_SM_NAME_{sm_id}}}"] = sm_name.strip()
        node_item[f"{{#E2_NODE_SM_ID_{sm_id}}}"] = sm_id
        node_item[f"{{#E2_NODE_SM_OID_{sm_id}}}"] = clean_oid

    # =====================================================
    # KPM (CORRIGIDO: Delimitador Dinâmico Opcional)
    # =====================================================
    # O (?:...) é um grupo de não-captura que aceita E2SM-RC OU a linha final OU o fim do bloco
    kpm_match = re.search(
        r"DEEP DIVE: E2SM-KPM Capabilities(.*?)(?:DEEP DIVE: E2SM-RC|------------------------------------------------------------|$)",
        block,
        re.DOTALL
    )

    if kpm_match:
        kpm_content = kpm_match.group(1)

        styles = re.findall(
            r"Style Type:\s*(\d+)\s*\|\s*Name:\s*(.*?)(?=Style Type:|$)",
            kpm_content,
            re.DOTALL
        )

        node_item["{#E2_NODE_KPM_STYLES}"] = len(styles)
        node_item["{#E2_NODE_KPM_SERVICE}"] = "REPORT"

        style_blocks = re.split(
            r"Style Type:\s*",
            kpm_content
        )[1:]

        for idx, style_block in enumerate(style_blocks, start=1):
            header = re.match(
                r"(\d+)\s*\|\s*Name:\s*(.*?)\n",
                style_block
            )

            if not header:
                continue

            style_type = int(header.group(1))
            style_name = header.group(2).strip()

            node_item[f"{{#E2_NODE_KPM_STYLE_TYPE_{idx}}}"] = style_type
            node_item[f"{{#E2_NODE_KPM_STYLE_NAME_{idx}}}"] = style_name

            meas = re.findall(
                r"-\s*([A-Za-z0-9\._\-]+)",
                style_block
            )

            node_item[f"{{#E2_NODE_KPM_MEAS_LIST_{idx}}}"] = ", ".join(meas)

    # =====================================================
    # RC
    # =====================================================
    rc_match = re.search(
        r"DEEP DIVE: E2SM-RC Capabilities(.*)",
        block,
        re.DOTALL
    )

    if rc_match:
        rc_content = rc_match.group(1)

        node_item["{#E2_NODE_RC_CTL_STYLES_COUNT}"] = 0
        node_item["{#E2_NODE_RC_RPT_STYLES_COUNT}"] = 0
        node_item["{#E2_NODE_RC_QRY_STYLES_COUNT}"] = 0
        node_item["{#E2_NODE_RC_PLY_STYLES_COUNT}"] = 0
        node_item["{#E2_NODE_RC_INS_STYLES_COUNT}"] = 0

        ctl_match = re.search(
            r"Control Style:\s*(\d+)\s*\((.*?)\)",
            rc_content
        )

        if ctl_match:
            style_type = int(ctl_match.group(1))

            node_item["{#E2_NODE_RC_CTL_STYLES_COUNT}"] = 1
            node_item["{#E2_NODE_RC_CTL_SERVICE}"] = "CONTROL"

            node_item["{#E2_NODE_RC_CTL_STYLE_TYPE_1}"] = style_type
            node_item["{#E2_NODE_RC_CTL_STYLE_NAME_1}"] = ctl_match.group(2).strip()

            actions_section = re.search(
                r"\[Supported Actions\](.*?)\[Control Parameters\]",
                rc_content,
                re.DOTALL
            )

            params_section = re.search(
                r"\[Control Parameters\](.*)",
                rc_content,
                re.DOTALL
            )

            action_names = []
            param_names = []

            if actions_section:
                action_names = re.findall(
                    r">\s*(.*?)\n",
                    actions_section.group(1)
                )

            if params_section:
                param_names = re.findall(
                    r">>\s*(.*?)\n",
                    params_section.group(1)
                )

            node_item["{#E2_NODE_RC_CTL_ACTION_LIST_ID_1}"] = "1"

            node_item[
                f"{{#E2_NODE_RC_CTL_ACTION_NAME_{style_type}}}"
            ] = ", ".join(action_names)

            node_item[
                f"{{#E2_NODE_RC_CTL_ACTION_PRM_NAME_{style_type}}}"
            ] = ", ".join(param_names)

    data_list.append(node_item)

print(json.dumps({"data": data_list}, indent=4))

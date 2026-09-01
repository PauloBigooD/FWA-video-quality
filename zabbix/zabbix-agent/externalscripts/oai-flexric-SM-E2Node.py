#!/usr/bin/env python3

import subprocess
import json
import re
import sys

# --------------------------------------------------
# JSON vazio padrão para exceções
# --------------------------------------------------

def print_empty_json_and_exit():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --------------------------------------------------
# CONFIGURAÇÃO
# --------------------------------------------------

cmd_find = "find /home /opt -type f -wholename '*/flexric/build/examples/xApp/c/monitor/xappMON' 2>/dev/null"

try:
    file_path = subprocess.run(
        cmd_find,
        shell=True,
        capture_output=True,
        text=True,
        timeout=10
    ).stdout.strip().split('\n')[0]

    if not file_path:
        print_empty_json_and_exit()

    result = subprocess.run(
        [file_path],
        capture_output=True,
        text=True,
        timeout=30
    )

    output_text = result.stdout
    if not output_text:
        print_empty_json_and_exit()

except Exception:
    print_empty_json_and_exit()

# --------------------------------------------------
# PARSING
# --------------------------------------------------

nodes_output = []

raw_nodes = re.split(r'\[NODE', output_text)
if len(raw_nodes) > 1:
    raw_nodes = raw_nodes[1:]
else:
    print_empty_json_and_exit()

for raw_node in raw_nodes:
    raw_node = "[NODE" + raw_node
    node_data = {}

    # --------------------------------------------------
    # 1. HEADER (Dados Básicos)
    # --------------------------------------------------

    header_match = re.search(
        r"\[NODE\s+(\d+)\].*?"
        r"Type:\s+(.*?)\s+\|.*?"
        r"MCC:\s+(\d+).*?"
        r"MNC:\s+(\d+).*?"
        r"Global ID:\s+(\d+).*?"
        r"Supported RAN Functions:\s+(\d+)",
        raw_node,
        re.DOTALL
    )

    if not header_match:
        continue

    node_data["{#E2_NODE_ID}"] = int(header_match.group(5))
    node_data["{#E2_NODE_MCC}"] = int(header_match.group(3))
    node_data["{#E2_NODE_MNC}"] = int(header_match.group(4))
    node_data["{#E2_NODE_TYPE}"] = header_match.group(2).strip()
    node_data["{#E2_NODE_E2SM_SUP}"] = int(header_match.group(6))

    # --------------------------------------------------
    # 2. SERVICE MODELS
    # --------------------------------------------------

    id_to_name_map = {
        2: "ORAN-E2SM-KPM",
        3: "ORAN-E2SM-RC",
        142: "MAC_STATS_V0",
        143: "RLC_STATS_V0",
        144: "PDCP_STATS_V0",
        145: "SLICE_STATS_V0",
        146: "TC_STATS_V0",
        148: "GTP_STATS_V0"
    }

    sm_pattern = (
        r"-> ranFunction-Name: (.*?)\n"
        r"\s+ranFunctionID: (\d+).*?"
        r"ranFunctionOID: ([\d\.]+)"
    )

    for sm_name, sm_id, sm_oid in re.findall(sm_pattern, raw_node, re.DOTALL):
        sm_id_int = int(sm_id)
        current_name = sm_name.strip()

        if sm_id_int in id_to_name_map:
            if "Unknown" in current_name or "Proprietary" in current_name:
                current_name = id_to_name_map[sm_id_int]

        node_data[f"{{#E2_NODE_SM_OID_{sm_id_int}}}"] = sm_oid.strip()
        node_data[f"{{#E2_NODE_SM_NAME_{sm_id_int}}}"] = current_name
        node_data[f"{{#E2_NODE_SM_ID_{sm_id_int}}}"] = sm_id_int

    # --------------------------------------------------
    # 3. KPM CAPABILITIES
    # --------------------------------------------------

    kpm_block = re.search(
        r"\[\+\] DEEP DIVE: E2SM-KPM Capabilities(.*?)(?=\[\+\]|\[INFO\]|$)",
        raw_node,
        re.DOTALL
    )

    if kpm_block:
        content = kpm_block.group(1)

        styles = re.findall(
            r"(?:Style_Type|ID): (\d+) \| (?:Style_Name|Name): (.*?)\n",
            content
        )
        meas_list = re.findall(r"-\s+([a-zA-Z0-9\._]+)", content)

        node_data["{#E2_NODE_KPM_STYLES}"] = len(styles)
        node_data["{#E2_NODE_KPM_SERVICE}"] = "REPORT"
        node_data["{#E2_NODE_KPM_STYLE_TYPE}"] = ", ".join([s[0] for s in styles]) if styles else "None"
        node_data["{#E2_NODE_KPM_STYLE_NAME}"] = " | ".join([s[1].strip() for s in styles]) if styles else "None"
        node_data["{#E2_NODE_KPM_MEAS_LIST}"] = ", ".join(meas_list) if meas_list else "None"
    else:
        node_data["{#E2_NODE_KPM_STYLES}"] = 0

    # --------------------------------------------------
    # 4. RC CAPABILITIES
    # --------------------------------------------------

    rc_block = re.search(
        r"\[\+\] DEEP DIVE: E2SM-RC Capabilities(.*?)(?=\[\+\]|\[INFO\]|$)",
        raw_node,
        re.DOTALL
    )

    if rc_block:
        rc_content = rc_block.group(1)

        parts = re.split(r"Control Styles:", rc_content)
        report_text = parts[0]
        control_text = parts[1] if len(parts) > 1 else ""

        r_styles = re.findall(
            r"(?:Style_Type|ID): (\d+) \| (?:Style_Name|Name): (.*?)\n",
            report_text
        )
        node_data["{#E2_NODE_RC_RPT_STYLES_COUNT}"] = len(r_styles)

        if r_styles:
            node_data["{#E2_NODE_RC_RPT_SERVICE}"] = "REPORT"
            node_data["{#E2_NODE_RC_RPT_STYLE_TYPE}"] = int(r_styles[0][0])
            node_data["{#E2_NODE_RC_RPT_STYLE_NAME}"] = r_styles[0][1].strip()

            r_params = re.findall(
                r"- Param ID: (\d+) \| Name: (.*?)\n",
                report_text
            )
            if r_params:
                node_data["{#E2_NODE_RC_RPT_ACTION_LIST_ID}"] = int(r_params[0][0])
                node_data["{#E2_NODE_RC_RPT_ACTION_NAME}"] = r_params[0][1].strip()

        c_styles_matches = list(re.finditer(
            r"(?:Style_Type|ID): (\d+) \| (?:Style_Name|Name): (.*?)\n",
            control_text
        ))
        node_data["{#E2_NODE_RC_CTL_STYLES_COUNT}"] = len(c_styles_matches)

        if c_styles_matches:
            style_id = int(c_styles_matches[0].group(1))
            style_name = c_styles_matches[0].group(2).strip()

            node_data["{#E2_NODE_RC_CTL_SERVICE}"] = "CONTROL"
            node_data["{#E2_NODE_RC_CTL_STYLE_TYPE}"] = style_id
            node_data["{#E2_NODE_RC_CTL_STYLE_NAME}"] = style_name

            actions = re.findall(
                r"> Action ID: (\d+) \| Name: (.*?)\n",
                control_text
            )

            if actions:
                act_id = int(actions[0][0])
                act_name = actions[0][1].strip()

                node_data["{#E2_NODE_RC_CTL_ACTION_LIST_ID}"] = act_id
                node_data["{#E2_NODE_RC_CTL_ACTION_NAME}"] = act_name

                act_chunk = re.search(
                    fr"> Action ID: {act_id}.*?(?=> Action ID|Style_Type|$)",
                    control_text,
                    re.DOTALL
                )
                if act_chunk:
                    chunk_txt = act_chunk.group(0)
                    params = re.findall(
                        r">> Param ID: \d+ \| Name: (.*?)(?=\[|$|\n)",
                        chunk_txt
                    )
                    items = re.findall(
                        r"-> Item ID: \d+ \| Name: (.*?)\n",
                        chunk_txt
                    )

                    node_data[f"{{#E2_NODE_RC_ACTION_{act_id}_PRM_NAME}}"] = ", ".join(p.strip() for p in params)
                    node_data[f"{{#E2_NODE_RC_ACTION_{act_id}_PRM_ITEM_NAME}}"] = ", ".join(i.strip() for i in items)

    else:
        node_data["{#E2_NODE_RC_RPT_STYLES_COUNT}"] = 0
        node_data["{#E2_NODE_RC_CTL_STYLES_COUNT}"] = 0

    nodes_output.append(node_data)

# --------------------------------------------------
# OUTPUT (LLD-safe)
# --------------------------------------------------

if not nodes_output:
    print_empty_json_and_exit()

print(json.dumps({"data": nodes_output}, indent=4))

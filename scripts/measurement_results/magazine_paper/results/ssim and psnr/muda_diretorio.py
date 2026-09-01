import os
import re
import shutil

# Caminho base onde estão as pastas JobX
caminho_base = "./SISO"  # ou "./MIMO"

# Define 'mimo' ou 'siso' com base no nome da pasta principal
modo_transmissao = os.path.basename(caminho_base).lower()

# Regex
padrao_5g = re.compile(r"tput5g_(64|256)qam_(mimo|siso)_([135])user_JOB\d+(.*)", re.IGNORECASE)
padrao_fwa = re.compile(r"tput_FWA_(64|256)qam_([135])user_JOB\d+(.*)", re.IGNORECASE)
padrao_vmaf = re.compile(r"(64|256)[-_]QAM[_-](MIMO|SISO)[_-]usr[_-]([135])[_-]job[_-]\d+[_-]vmaf\.xml", re.IGNORECASE)
padrao_psnr = re.compile(r"(64|256)[-_]QAM[_-](MIMO|SISO)[_-]usr[_-]([135])[_-]job[_-]\d+[_-]psnr\.csv", re.IGNORECASE)
padrao_ssim = re.compile(r"(64|256)[-_]QAM[_-](MIMO|SISO)[_-]usr[_-]([135])[_-]job[_-]\d+[_-]ssim\.csv", re.IGNORECASE)

# Corrige o nome das pastas Jobx → JOBx
for item in os.listdir(caminho_base):
    caminho_item = os.path.join(caminho_base, item)
    if os.path.isdir(caminho_item) and (re.match(r"^Job\d$", item) or re.match(r"^job\d$", item)):
        novo_nome = item.upper()
        os.rename(caminho_item, os.path.join(caminho_base, novo_nome))
        print(f"[RENOMEAR PASTA] {item} → {novo_nome}")

# Processa pastas JOBx
for item in os.listdir(caminho_base):
    if not re.match(r"^JOB\d+$", item):
        continue

    pasta_job = os.path.join(caminho_base, item)

    # Parte 1: renomear arquivos VMAF diretamente em JOBx/
    for nome_antigo in os.listdir(pasta_job):
        caminho_antigo = os.path.join(pasta_job, nome_antigo)
        if not os.path.isfile(caminho_antigo):
            continue

        match_vmaf = padrao_vmaf.match(nome_antigo)
        if match_vmaf:
            mod = match_vmaf.group(1)
            modo = match_vmaf.group(2).lower()
            user = match_vmaf.group(3)
            novo_nome = f"vmaf_{mod}qam_{modo}_{user}user.xml"
            caminho_novo = os.path.join(pasta_job, novo_nome)
            shutil.move(caminho_antigo, caminho_novo)
            print(f"[VMAF] Movido: {nome_antigo} → {novo_nome}")
            
        match_psnr = padrao_psnr.match(nome_antigo)
        if match_psnr:
            mod = match_psnr.group(1)
            modo = match_psnr.group(2).lower()
            user = match_psnr.group(3)
            novo_nome = f"psnr_{mod}qam_{modo}_{user}user.csv"
            caminho_novo = os.path.join(pasta_job, novo_nome)
            shutil.move(caminho_antigo, caminho_novo)
            print(f"[PSNR] Movido: {nome_antigo} → {novo_nome}")
            continue

        match_ssim = padrao_ssim.match(nome_antigo)
        if match_ssim:
            mod = match_ssim.group(1)
            modo = match_ssim.group(2).lower()
            user = match_ssim.group(3)
            novo_nome = f"ssim_{mod}qam_{modo}_{user}user.csv"
            caminho_novo = os.path.join(pasta_job, novo_nome)
            shutil.move(caminho_antigo, caminho_novo)
            print(f"[SSIM] Movido: {nome_antigo} → {novo_nome}")
            continue

    # Parte 2: processamento opcional de arquivos dentro de subpastas 64QAM/256QAM
    for modulation in ["64QAM", "256QAM"]:
        pasta_mod = os.path.join(pasta_job, modulation)
        if not os.path.isdir(pasta_mod):
            continue

        for nome_antigo in os.listdir(pasta_mod):
            caminho_antigo = os.path.join(pasta_mod, nome_antigo)
            if not os.path.isfile(caminho_antigo):
                continue

            print(f"[DEBUG] Verificando: {nome_antigo}")

            # 5G
            match_5g = padrao_5g.match(nome_antigo)
            if match_5g:
                x = match_5g.group(1)
                y = match_5g.group(3)
                ext = os.path.splitext(nome_antigo)[1].lower()
                novo_nome = f"tput5g_{x}qam_{modo_transmissao}_{y}user{ext}"
                caminho_novo = os.path.join(pasta_job, novo_nome)
                shutil.move(caminho_antigo, caminho_novo)
                print(f"[5G] Movido: {nome_antigo} → {novo_nome}")
                continue

            # FWA
            match_fwa = padrao_fwa.match(nome_antigo)
            if match_fwa:
                x = match_fwa.group(1)
                y = match_fwa.group(2)
                ext = os.path.splitext(nome_antigo)[1].lower()
                novo_nome = f"tputFWA_{x}qam_{modo_transmissao}_{y}user{ext}"
                caminho_novo = os.path.join(pasta_job, novo_nome)
                shutil.move(caminho_antigo, caminho_novo)
                print(f"[FWA] Movido: {nome_antigo} → {novo_nome}")

        # Remoção da pasta de modulação se estiver vazia
        try:
            os.rmdir(pasta_mod)
            print(f"[LIMPEZA] Removida: {pasta_mod}")
        except OSError:
            print(f"[LIMPEZA] Não vazia: {pasta_mod}")


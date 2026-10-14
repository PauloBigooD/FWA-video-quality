#!/usr/bin/env python3

import os
import re

diretorio_csvs = "segments_csv"

# Expressão regular para extrair resolução, bitrate e número do segmento
# Exemplo de URL: .../segment_bbb_sunflower_640x360_1.8M120.m4s
pattern = re.compile(r"segment_bbb_sunflower_(\d+x\d+)_([0-9\.]+M)(\d+)\.m4s")

print("Iniciando extração do log de qualidade por segmento...\n")

for arquivo in os.listdir(diretorio_csvs):
    # Processa apenas os CSVs originais do HAR
    if arquivo.endswith(".csv") and not any(kw in arquivo.lower() for kw in ["psnr", "ssim", "vmaf", "quality", "metrics"]):
        nome_experimento = os.path.splitext(arquivo)[0]
        caminho_csv_input = os.path.join(diretorio_csvs, arquivo)
        arquivo_saida_quality = os.path.join(diretorio_csvs, f"quality_{nome_experimento}.csv")
        
        registros = {}
        
        with open(caminho_csv_input, "r") as f:
            for linha in f:
                match = pattern.search(linha.strip())
                if match:
                    resolucao = match.group(1)   # Ex: 640x360
                    bitrate = match.group(2)     # Ex: 1.8M
                    segmento = int(match.group(3)) # Ex: 120
                    
                    # Evita duplicatas garantindo um registro por número de segmento
                    registros[segmento] = f"{segmento} {bitrate} {resolucao}"
        
        # Grava os registros ordenados numericamente pelo número do segmento
        if registros:
            with open(arquivo_saida_quality, "w") as f_out:
                for seg_id in sorted(registros.keys()):
                    f_out.write(f"{registros[seg_id]}\n")
            
            print(f"✅ Log de qualidade gerado: {arquivo_saida_quality}")

print("\nProcessamento do log de qualidade concluído!")

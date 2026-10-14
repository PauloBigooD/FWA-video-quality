#!/usr/bin/env python3
import os
import subprocess

diretorio = "/home/paulobigood/har_logs"
diretorio_saida = "segments_csv"
os.makedirs(diretorio_saida, exist_ok=True)

comando_jq = "jq -r '.log.entries[] | select(.request.url | contains(\"http://172.31.0.54:8080/video-dash/segment_bbb_sunflower\")) | .request.url' '{input_file}' > '{output_file}'"
comando_insert_column_name = "sed -i '1i Request URI' '{output_file}'"
comando_rm = "rm -rf downloaded_segments"
comando_concat = "python3 concat_filter_2.py '{output_file}'"

# 1. Extração do HAR para CSV
for arquivo in os.listdir(diretorio):
    if arquivo.endswith(".har"):
        caminho_arquivo = os.path.join(diretorio, arquivo)
        arquivo_saida = arquivo.replace(".har", ".csv")
        caminho_saida = os.path.join(diretorio_saida, arquivo_saida)
        
        comando1 = comando_jq.format(input_file=caminho_arquivo, output_file=caminho_saida)
        comando2 = comando_insert_column_name.format(output_file=caminho_saida)
        
        try:
            subprocess.run(comando1, shell=True, check=True)
            subprocess.run(comando2, shell=True, check=True)
            print(f"URIs extraídas: {arquivo_saida}")
        except subprocess.CalledProcessError as e:
            print(f"Erro no HAR {arquivo}: {e}")

print("\n✅ Extração concluída!")

# 2. Concatenação e renomeação do vídeo de saída por experimento
for arquivo_2 in os.listdir(diretorio_saida):
    if arquivo_2.endswith(".csv") and not ("_psnr" in arquivo_2 or "_ssim" in arquivo_2 or "_metrics" in arquivo_2):
        nome_exp = os.path.splitext(arquivo_2)[0]
        saida_csv = os.path.join(diretorio_saida, arquivo_2)
        video_experimento = f"saida_{nome_exp}.mp4"
        
        comando5 = comando_concat.format(output_file=saida_csv)
        
        try:
            subprocess.run(comando_rm, shell=True, check=True)
            subprocess.run(comando5, shell=True, check=True)
            
            # Renomeia saida.mp4 para o nome único do experimento
            if os.path.exists("saida.mp4"):
                os.rename("saida.mp4", video_experimento)
                print(f"✅ Vídeo gerado: {video_experimento}\n")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao concatenar {arquivo_2}: {e}\n")

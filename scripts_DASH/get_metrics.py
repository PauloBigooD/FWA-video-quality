#!/usr/bin/env python3

import os
import subprocess

diretorio_csvs = "segments_csv"
video_referencia = "video/bbb_sunflower_2160p_60fps_normal.mp4"

if not os.path.exists(video_referencia):
    print(f"❌ Erro: Vídeo de referência '{video_referencia}' não encontrado.")
    exit(1)

# Comandos base do FFmpeg para PSNR, SSIM e VMAF
get_psnr = 'ffmpeg -i {ref} -i {dis} -lavfi psnr="{output_file}" -f null -'
get_ssim = 'ffmpeg -i {ref} -i {dis} -lavfi ssim="{output_file}" -f null -'
get_vmaf = 'ffmpeg -i {ref} -i {dis} -lavfi libvmaf="log_fmt=xml:log_path={output_file}" -f null -'

print("Iniciando cálculo de métricas (PSNR, SSIM e VMAF) para todos os experimentos...\n")

for arquivo in os.listdir(diretorio_csvs):
    # Ignores seguros: processa apenas os CSVs originais do HAR
    if arquivo.endswith(".csv") and not any(kw in arquivo.lower() for kw in ["psnr", "ssim", "vmaf", "quality", "metrics"]):
        nome_experimento = os.path.splitext(arquivo)[0]
        video_reconstruido = f"saida_{nome_experimento}.mp4"
        
        if not os.path.exists(video_reconstruido):
            print(f"⚠️ Vídeo '{video_reconstruido}' não encontrado. Pulando...")
            continue

        arquivo_saida_psnr = os.path.join(diretorio_csvs, f"psnr_{nome_experimento}.csv")
        arquivo_saida_ssim = os.path.join(diretorio_csvs, f"ssim_{nome_experimento}.csv")
        arquivo_saida_vmaf = os.path.join(diretorio_csvs, f"vmaf_{nome_experimento}.xml")

        cmd_psnr = get_psnr.format(ref=video_referencia, dis=video_reconstruido, output_file=arquivo_saida_psnr)
        cmd_ssim = get_ssim.format(ref=video_referencia, dis=video_reconstruido, output_file=arquivo_saida_ssim)
        cmd_vmaf = get_vmaf.format(ref=video_referencia, dis=video_reconstruido, output_file=arquivo_saida_vmaf)

        try:
            # 1. Gerar PSNR
            print(f"📊 Gerando PSNR para: {nome_experimento}")
            subprocess.run(cmd_psnr, shell=True, check=True)
            print(f"✅ PSNR salvo em: {arquivo_saida_psnr}\n")

            # 2. Gerar SSIM
            print(f"📊 Gerando SSIM para: {nome_experimento}")
            subprocess.run(cmd_ssim, shell=True, check=True)
            print(f"✅ SSIM salvo em: {arquivo_saida_ssim}\n")

            # 3. Gerar VMAF (XML)
            print(f"📊 Gerando VMAF (XML) para: {nome_experimento}")
            subprocess.run(cmd_vmaf, shell=True, check=True)
            print(f"✅ VMAF salvo em: {arquivo_saida_vmaf}\n")

        except subprocess.CalledProcessError as e:
            print(f"❌ Erro ao calcular métricas para {nome_experimento}: {e}")

print("Processamento de métricas concluído!")

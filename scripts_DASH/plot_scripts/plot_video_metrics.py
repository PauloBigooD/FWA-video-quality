#!/usr/bin/env python3

import os
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

# ==========================================
# 1. Configurações Globais e de Fonte
# ==========================================
SEGMENTS_DIR = "../segments_csv"
RESULTS_PATH = "plot_results"

# Configuração de Fonte com fallback seguro
FONT_DIR = '/usr/share/fonts/truetype/msttcorefonts/'
TTF_PATH = os.path.join(FONT_DIR, 'Times_New_Roman.ttf')

if os.path.exists(TTF_PATH):
    fm.fontManager.addfont(TTF_PATH)
    plt.rcParams['font.family'] = 'Times New Roman'
else:
    plt.rcParams['font.family'] = 'serif'

FONT_SIZE = 20
FONT_SIZE_LEG = 14
FIG_SIZE = (12, 7)
CMAP = plt.get_cmap("tab10")
plt.rc('font', size=FONT_SIZE)


# ==========================================
# 2. Funções de Parsing de Arquivos FFmpeg
# ==========================================
def carregar_psnr(filepath):
    """Lê log de PSNR do FFmpeg em formato chave:valor ou CSV."""
    registros = []
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if ':' in line:
                    d = {}
                    for item in line.strip().split():
                        if ':' in item:
                            k, v = item.split(':', 1)
                            d[k] = float(v) if v.replace('.', '', 1).isdigit() else v
                    registros.append(d)
        if registros:
            df = pd.DataFrame(registros)
            col_avg = [c for c in df.columns if 'psnr_avg' in c or 'average' in c or 'All' in c]
            col_n = [c for c in df.columns if c in ['n', 'frame', 'Frame']]
            if col_avg and col_n:
                return df[[col_n[0], col_avg[0]]].rename(columns={col_n[0]: 'frame', col_avg[0]: 'psnr'})
    except Exception as e:
        print(f"⚠️ Erro ao ler PSNR {filepath}: {e}")
    return None

def carregar_ssim(filepath):
    """Lê log de SSIM do FFmpeg em formato chave:valor ou CSV."""
    registros = []
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if ':' in line:
                    d = {}
                    for item in line.strip().split():
                        if ':' in item:
                            k, v = item.split(':', 1)
                            # Remove parênteses do valor se houver (ex: All:0.999 (30.12))
                            v_clean = v.split('(')[0].strip()
                            try:
                                d[k] = float(v_clean)
                            except ValueError:
                                d[k] = v_clean
                    registros.append(d)
        if registros:
            df = pd.DataFrame(registros)
            col_all = [c for c in df.columns if 'All' in c or 'ssim' in c]
            col_n = [c for c in df.columns if c in ['n', 'frame', 'Frame']]
            if col_all and col_n:
                return df[[col_n[0], col_all[0]]].rename(columns={col_n[0]: 'frame', col_all[0]: 'ssim'})
    except Exception as e:
        print(f"⚠️ Erro ao ler SSIM {filepath}: {e}")
    return None

def carregar_vmaf(filepath):
    """Lê o relatório VMAF em formato XML gerado pelo FFmpeg."""
    try:
        df = pd.read_xml(filepath, xpath=".//frame")
        col_vmaf = [c for c in df.columns if 'vmaf' in c.lower()]
        col_frame = [c for c in df.columns if 'frame' in c.lower()]
        if col_vmaf and col_frame:
            return df[[col_frame[0], col_vmaf[0]]].rename(columns={col_frame[0]: 'frame', col_vmaf[0]: 'vmaf'})
    except Exception as e:
        print(f"⚠️ Erro ao ler VMAF XML {filepath}: {e}")
    return None


# ==========================================
# 3. Geração dos Gráficos de Vídeo (QoE)
# ==========================================
def plot_psnr(dados_psnr):
    plt.figure(figsize=FIG_SIZE)
    for i, (exp_label, df) in enumerate(dados_psnr.items()):
        x = df['frame'].values
        y = df['psnr'].values
        
        # Média calculada corretamente no domínio linear
        y_linear = 10 ** (y / 10)
        mean_linear = np.mean(y_linear[y_linear < 1e6])
        mean_db = 10 * np.log10(mean_linear)

        color = CMAP(i % 10)
        plt.plot(x, y, linestyle='-', linewidth=1.2, color=color, alpha=0.8, label=f'{exp_label}')
        plt.axhline(mean_db, color=color, linestyle='--', linewidth=1.5, label=f'Média ({exp_label}): {mean_db:.2f} dB')

    plt.xlabel('Frames', fontsize=FONT_SIZE)
    plt.ylabel('PSNR (dB)', fontsize=FONT_SIZE)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(fontsize=FONT_SIZE_LEG, loc='lower right')
    plt.tight_layout()

    out_path = os.path.join(RESULTS_PATH, "psnr_series.png")
    plt.savefig(out_path, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()
    print(f"✅ Gráfico PSNR salvo em: {out_path}")

def plot_ssim(dados_ssim):
    plt.figure(figsize=FIG_SIZE)
    for i, (exp_label, df) in enumerate(dados_ssim.items()):
        x = df['frame'].values
        y = df['ssim'].values
        mean_ssim = np.mean(y)

        color = CMAP(i % 10)
        plt.plot(x, y, linestyle='-', linewidth=1.2, color=color, alpha=0.8, label=f'{exp_label}')
        plt.axhline(mean_ssim, color=color, linestyle='--', linewidth=1.5, label=f'Média ({exp_label}): {mean_ssim:.4f}')

    plt.xlabel('Frames', fontsize=FONT_SIZE)
    plt.ylabel('SSIM', fontsize=FONT_SIZE)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(fontsize=FONT_SIZE_LEG, loc='lower right')
    plt.tight_layout()

    out_path = os.path.join(RESULTS_PATH, "ssim_series.png")
    plt.savefig(out_path, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()
    print(f"✅ Gráfico SSIM salvo em: {out_path}")

def plot_vmaf(dados_vmaf):
    plt.figure(figsize=FIG_SIZE)
    for i, (exp_label, df) in enumerate(dados_vmaf.items()):
        x = df['frame'].values
        y = df['vmaf'].values
        mean_vmaf = np.mean(y)

        color = CMAP(i % 10)
        plt.plot(x, y, linestyle='-', linewidth=1.2, color=color, alpha=0.8, label=f'{exp_label}')
        plt.axhline(mean_vmaf, color=color, linestyle='--', linewidth=1.5, label=f'Média ({exp_label}): {mean_vmaf:.2f}%')

    plt.xlabel('Frames', fontsize=FONT_SIZE)
    plt.ylabel('VMAF Score', fontsize=FONT_SIZE)
    plt.ylim(0, 105)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(fontsize=FONT_SIZE_LEG, loc='lower right')
    plt.tight_layout()

    out_path = os.path.join(RESULTS_PATH, "vmaf_series.png")
    plt.savefig(out_path, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()
    print(f"✅ Gráfico VMAF salvo em: {out_path}")


# ==========================================
# 4. Execução Principal
# ==========================================
def main():
    os.makedirs(RESULTS_PATH, exist_ok=True)
    
    dados_psnr = {}
    dados_ssim = {}
    dados_vmaf = {}

    if not os.path.exists(SEGMENTS_DIR):
        print(f"❌ Pasta '{SEGMENTS_DIR}' não encontrada.")
        return

    for f in os.listdir(SEGMENTS_DIR):
        caminho = os.path.join(SEGMENTS_DIR, f)
        
        # Identificação PSNR
        if f.startswith("psnr_") and f.endswith(".csv"):
            exp_id = f.replace("psnr_", "").replace(".csv", "")
            df = carregar_psnr(caminho)
            if df is not None:
                dados_psnr[exp_id] = df

        # Identificação SSIM
        elif f.startswith("ssim_") and f.endswith(".csv"):
            exp_id = f.replace("ssim_", "").replace(".csv", "")
            df = carregar_ssim(caminho)
            if df is not None:
                dados_ssim[exp_id] = df

        # Identificação VMAF (XML)
        elif f.startswith("vmaf_") and f.endswith(".xml"):
            exp_id = f.replace("vmaf_", "").replace(".xml", "")
            df = carregar_vmaf(caminho)
            if df is not None:
                dados_vmaf[exp_id] = df

    if dados_psnr:
        plot_psnr(dados_psnr)
    if dados_ssim:
        plot_ssim(dados_ssim)
    if dados_vmaf:
        plot_vmaf(dados_vmaf)

    if not (dados_psnr or dados_ssim or dados_vmaf):
        print("⚠️ Nenhum arquivo de métrica de vídeo encontrado em 'segments_csv/'.")

if __name__ == "__main__":
    main()

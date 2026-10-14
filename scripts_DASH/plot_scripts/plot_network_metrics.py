#!/usr/bin/env python3

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.lines import Line2D

# ==========================================
# 1. Configurações Globais e de Fonte
# ==========================================
SEGMENTS_DIR = "segments_csv"
RESULTS_PATH = "plot_results"

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
# 2. Leitura de Métricas de Rede / UE
# ==========================================
def carregar_metricas_rede(filepath):
    """
    Carrega métricas de throughput/bitrate em CSV.
    Suporta colunas como 'bitrate_bps', 'downlink_Mbps', 'time_s', 'tempo_s'.
    """
    try:
        df = pd.read_csv(filepath)
        col_t = [c for c in df.columns if 'time' in c.lower() or 'tempo' in c.lower()]
        col_tp = [c for c in df.columns if 'bitrate' in c.lower() or 'downlink' in c.lower() or 'tput' in c.lower()]

        if col_t and col_tp:
            df_out = pd.DataFrame()
            df_out['tempo_s'] = pd.to_numeric(df[col_t[0]], errors='coerce')
            
            # Converte bps para Mbps caso os valores sejam elevados
            val_tp = pd.to_numeric(df[col_tp[0]], errors='coerce')
            if val_tp.max() > 10000:
                df_out['throughput_mbps'] = val_tp / 1_000_000
            else:
                df_out['throughput_mbps'] = val_tp
                
            return df_out.dropna()
    except Exception as e:
        print(f"⚠️ Erro ao carregar métricas de rede de {filepath}: {e}")
    return None


# ==========================================
# 3. Geração dos Gráficos de Rede e CDF
# ==========================================
def plot_throughput_series(dados_rede):
    plt.figure(figsize=FIG_SIZE)
    for i, (exp_label, df) in enumerate(dados_rede.items()):
        x = df['tempo_s'].values
        y = df['throughput_mbps'].values
        mean_tp = np.mean(y)

        color = CMAP(i % 10)
        plt.plot(x, y, linestyle='-', linewidth=1.5, color=color, alpha=0.85, label=f'{exp_label}')
        plt.axhline(mean_tp, color=color, linestyle='--', linewidth=1.5, label=f'Média ({exp_label}): {mean_tp:.2f} Mbps')

    plt.xlabel('Time (s)', fontsize=FONT_SIZE)
    plt.ylabel('Throughput / Bitrate (Mbps)', fontsize=FONT_SIZE)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.ylim(bottom=0)
    plt.legend(fontsize=FONT_SIZE_LEG, loc='upper right')
    plt.tight_layout()

    out_path = os.path.join(RESULTS_PATH, "throughput_series.png")
    plt.savefig(out_path, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()
    print(f"✅ Gráfico de Série Temporal de Throughput salvo em: {out_path}")

def plot_throughput_cdf(dados_rede):
    fig, ax = plt.subplots(figsize=FIG_SIZE)
    legend_handles = []

    for i, (exp_label, df) in enumerate(dados_rede.items()):
        data = df['throughput_mbps'].values
        sorted_data = np.sort(data)
        cdf = np.linspace(0, 1, len(sorted_data))

        color = CMAP(i % 10)
        # Linha principal contínua
        ax.plot(sorted_data, cdf, linestyle='-', linewidth=1.8, color=color)

        # Marcadores espaçados ao longo da curva
        step = max(1, len(sorted_data) // 15)
        marker_indices = np.arange(0, len(sorted_data), step)
        ax.plot(sorted_data[marker_indices], cdf[marker_indices], linestyle='None',
                marker='*', markersize=7, color=color)

        # Legenda com marcador personalizado
        handle = Line2D([], [], linestyle='-', marker='*', color=color,
                       markersize=7, linewidth=1.8, label=f'{exp_label}')
        legend_handles.append(handle)

    ax.set_xlabel('Throughput / Bitrate (Mbps)', fontsize=FONT_SIZE)
    ax.set_ylabel('CDF', fontsize=FONT_SIZE)
    ax.set_ylim(0, 1.02)
    ax.grid(True, linestyle='--', alpha=0.6)
    ax.legend(handles=legend_handles, fontsize=FONT_SIZE_LEG, loc='lower right')
    plt.tight_layout()

    out_path = os.path.join(RESULTS_PATH, "throughput_cdf.png")
    plt.savefig(out_path, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()
    print(f"✅ Gráfico de CDF de Throughput salvo em: {out_path}")


# ==========================================
# 4. Execução Principal
# ==========================================
def main():
    os.makedirs(RESULTS_PATH, exist_ok=True)
    dados_rede = {}

    if not os.path.exists(SEGMENTS_DIR):
        print(f"❌ Pasta '{SEGMENTS_DIR}' não encontrada.")
        return

    for f in os.listdir(SEGMENTS_DIR):
        if f.endswith(".csv") and any(kw in f.lower() for kw in ["metrics", "tput", "quality"]):
            exp_id = f.replace("_metrics.csv", "").replace("quality_", "").replace("tput_", "").replace(".csv", "")
            caminho = os.path.join(SEGMENTS_DIR, f)
            df = carregar_metricas_rede(caminho)
            if df is not None and not df.empty:
                dados_rede[exp_id] = df

    if dados_rede:
        plot_throughput_series(dados_rede)
        plot_throughput_cdf(dados_rede)
    else:
        print("⚠️ Nenhum arquivo de métricas de rede encontrado em 'segments_csv/'.")

if __name__ == "__main__":
    main()

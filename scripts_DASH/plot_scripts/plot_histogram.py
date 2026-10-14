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
SEGMETS_DIR = "../segments_csv"
RESULTS_PATH = "plot_results"

# Configuração de Fonte com fallback seguro
FONT_DIR = '/usr/share/fonts/truetype/msttcorefonts/'
TTF_PATH = os.path.join(FONT_DIR, 'Times_New_Roman.ttf')

if os.path.exists(TTF_PATH):
    fm.fontManager.addfont(TTF_PATH)
    plt.rcParams['font.family'] = 'Times New Roman'
else:
    plt.rcParams['font.family'] = 'serif'

# Estética dos Gráficos
FONT_SIZE = 20
FONT_SIZE_LEG = 14
FIG_SIZE = (12, 7)
HATCHES = ['\\\\\\\\', 'x', 'O', '//', '..', '**']
CMAP = plt.get_cmap("tab10")
plt.rc('font', size=FONT_SIZE)


# ==========================================
# 2. Função de Leitura Dinâmica do Log
# ==========================================
def carregar_log_qualidade(filepath):
    """
    Lê o arquivo de qualidade gerado pelo get_quality_log.py (ex: '120 1.8M 640x360')
    ou em formato CSV com cabeçalho.
    """
    try:
        # Tenta formato delimitado por espaço: <segmento> <bitrate> <resolução>
        df = pd.read_csv(filepath, sep=r'\s+', header=None, names=['segmento', 'bitrate', 'resolucao'])
        if 'resolucao' in df.columns:
            # Extrai a altura da resolução (ex: 640x360 -> 360)
            df['altura'] = df['resolucao'].astype(str).str.extract(r'x(\d+)', expand=False)
            df['altura'] = pd.to_numeric(df['altura'], errors='coerce')
            return df.dropna(subset=['altura'])
    except Exception:
        pass

    try:
        # Fallback: Tenta formato CSV padrão
        df = pd.read_csv(filepath)
        col_res = [c for c in df.columns if 'res' in c.lower() or 'resolu' in c.lower()]
        if col_res:
            df['altura'] = df[col_res[0]].astype(str).str.extract(r'x(\d+)', expand=False)
            df['altura'] = pd.to_numeric(df['altura'], errors='coerce')
            return df.dropna(subset=['altura'])
    except Exception as e:
        print(f"⚠️ Erro ao ler {filepath}: {e}")
        
    return None


# ==========================================
# 3. Geração dos Gráficos
# ==========================================
def gerar_histograma():
    if not os.path.exists(SEGMETS_DIR):
        print(f"❌ Erro: O diretório '{SEGMETS_DIR}' não foi encontrado.")
        return

    # Busca dinâmica por arquivos quality_*.csv
    arquivos_qualidade = [
        f for f in os.listdir(SEGMETS_DIR) 
        if f.startswith("quality_") and f.endswith(".csv")
    ]

    if not arquivos_qualidade:
        print(f"⚠️ Nenhum arquivo 'quality_*.csv' encontrado em '{SEGMETS_DIR}/'.")
        print("Execute o script './get_quality_log.py' primeiro para gerar os logs.")
        return

    print(f"📂 Encontrados {len(arquivos_qualidade)} arquivo(s) de qualidade para processamento.\n")

    dados_experimentos = {}

    for arq in arquivos_qualidade:
        # Extrai o ID do experimento removendo o prefixo 'quality_' e a extensão '.csv'
        nome_exp = arq.replace("quality_", "").replace(".csv", "")
        
        # Simplifica o rótulo da legenda caso seja o padrão timestamp paulobigood
        rotulo_legenda = nome_exp
        if "paulobigood_" in nome_exp:
            timestamp = nome_exp.replace("paulobigood_", "")
            rotulo_legenda = f"Run ({timestamp[:10]} {timestamp[11:19]})"

        filepath = os.path.join(SEGMETS_DIR, arq)
        df = carregar_log_qualidade(filepath)

        if df is not None and not df.empty:
            dados_experimentos[rotulo_legenda] = df['altura'].value_counts()
            print(f"✅ Dados carregados para: {nome_exp}")

    if not dados_experimentos:
        print("❌ Nenhum dado válido pôde ser extraído dos arquivos.")
        return

    # Descobre todas as resoluções únicas presentes (360, 480, 720, 1080, 2160)
    todas_resolucoes = sorted(set().union(*[counts.index for counts in dados_experimentos.values()]))

    # Constrói o DataFrame unificado
    df_counts = pd.DataFrame(index=todas_resolucoes)
    for exp_label, counts in dados_experimentos.items():
        df_counts[exp_label] = counts.reindex(todas_resolucoes, fill_value=0)

    # Configuração da Plotagem
    num_exps = len(dados_experimentos)
    largura = 0.8 / num_exps
    ind = np.arange(len(todas_resolucoes))

    plt.figure(figsize=FIG_SIZE)

    for i, exp_label in enumerate(dados_experimentos.keys()):
        posicoes = ind + (i * largura) - (largura * (num_exps - 1) / 2)
        hatch_style = HATCHES[i % len(HATCHES)]
        
        barras = plt.bar(
            posicoes,
            df_counts[exp_label],
            largura,
            label=exp_label,
            color=CMAP(i % 10),
            alpha=0.85,
            edgecolor='black',
            hatch=hatch_style
        )

        # Rótulos contadores no topo de cada barra
        max_y = df_counts.values.max() if df_counts.values.max() > 0 else 1
        for x, y in zip(posicoes, df_counts[exp_label]):
            if y > 0:
                texto = f'{y/1000:.1f}k' if y >= 1000 else f'{int(y)}'
                plt.text(
                    x,
                    y + (max_y * 0.015),
                    texto,
                    ha='center',
                    va='bottom',
                    fontsize=FONT_SIZE - 4,
                    rotation=90,
                    color=CMAP(i % 10)
                )

    # Rótulos do Eixo X
    label_map = {
        360: 'Low\n(360p)',
        480: 'SD\n(480p)',
        720: 'HD\n(720p)',
        1080: 'FHD\n(1080p)',
        2160: '4K\n(2160p)'
    }
    xtick_labels = [label_map.get(int(r), str(r)) for r in todas_resolucoes]

    plt.xlabel('Video Quality Representation', fontsize=FONT_SIZE, labelpad=10)
    plt.ylabel('Frequency (segments/frames)', fontsize=FONT_SIZE)
    plt.xticks(ind, xtick_labels)
    
    # Ajuste dinâmico de escala Y para evitar sobreposição da legenda
    plt.ylim(0, max_y * 1.25)
    plt.grid(axis='y', linestyle='--', alpha=0.6)
    plt.legend(fontsize=FONT_SIZE_LEG, loc='upper right')
    plt.tight_layout()

    # Salva a imagem
    os.makedirs(RESULTS_PATH, exist_ok=True)
    caminho_saida = os.path.join(RESULTS_PATH, "quality_histogram.png")
    plt.savefig(caminho_saida, dpi=600, bbox_inches='tight', transparent=True)
    plt.close()

    print(f"\n✅ Histograma salvo com sucesso em: {caminho_saida}")


# ==========================================
# 4. Execução Principal
# ==========================================
if __name__ == "__main__":
    print("📊 Gerando histograma de qualidade por experimento...\n")
    gerar_histograma()

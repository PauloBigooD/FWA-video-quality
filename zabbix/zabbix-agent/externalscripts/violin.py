#!/usr/bin/env python3

import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================
CSV_PATH = "/tmp/xapp_benchmark_results.csv"
OUTPUT_IMAGE = "/tmp/xapp_violin_plots.png"

if not os.path.exists(CSV_PATH):
    print(f"[!] Error: CSV file not found at '{CSV_PATH}'. Execute temporizador.py first.")
    exit(1)

df = pd.read_csv(CSV_PATH)

# Configura o tema do Seaborn aplicando a fonte Times New Roman
sns.set_theme(
    style="whitegrid",
    rc={
        "font.family": "serif",
        "font.serif": ["Times New Roman", "DejaVu Serif", "Liberation Serif"]
    }
)

# Layout Vertical: 3 linhas x 1 coluna (ideal para artigos)
fig, axes = plt.subplots(3, 1, figsize=(6.5, 11))

# Cores padrão do Seaborn (Azul e Laranja/Terracota)
palette = ["#4c72b0", "#dd8452"]

# ------------------------------------------------------------------------------
# PANEL 1: E2 Query Latency
# ------------------------------------------------------------------------------
sns.violinplot(
    ax=axes[0],
    y=df["E2 Query (ms)"],
    inner="box",
    fill=False,
    color=palette[0],
    linewidth=1.6,
    cut=0
)
axes[0].set_title("A. E2 Query Latency", fontsize=12, fontweight="bold", pad=10)
axes[0].set_ylabel("Time (ms)", fontsize=11)
mean_e2 = df["E2 Query (ms)"].mean()
axes[0].set_xlabel(f"Mean: {mean_e2:.3f} ms", fontsize=11, fontweight="bold", labelpad=8)

# ------------------------------------------------------------------------------
# PANEL 2: Zabbix Ingestion Latency
# ------------------------------------------------------------------------------
df_zbx_clean = df[df["Zabbix Update (ms)"] < 50]

sns.violinplot(
    ax=axes[1],
    y=df_zbx_clean["Zabbix Update (ms)"],
    inner="box",
    fill=False,
    color=palette[1],
    linewidth=1.6,
    cut=0
)
axes[1].set_title("B. Zabbix Trapper Ingestion Latency", fontsize=12, fontweight="bold", pad=10)
axes[1].set_ylabel("Time (ms)", fontsize=11)
mean_zbx = df_zbx_clean["Zabbix Update (ms)"].mean()
axes[1].set_xlabel(f"Mean: {mean_zbx:.2f} ms", fontsize=11, fontweight="bold", labelpad=8)

# ------------------------------------------------------------------------------
# PANEL 3: End-to-End Pipeline Latency
# ------------------------------------------------------------------------------
df_macro = df_zbx_clean.melt(
    id_vars=["Sample"],
    value_vars=["xAppMON Total (ms)", "Pipeline Total (ms)"],
    var_name="Phase",
    value_name="Time (ms)"
)

sns.violinplot(
    ax=axes[2],
    x="Phase",
    y="Time (ms)",
    data=df_macro,
    hue="Phase",
    inner="box",
    fill=False,
    palette=palette,
    linewidth=1.6,
    cut=0
)
axes[2].set_title("C. End-to-End Pipeline Latency", fontsize=12, fontweight="bold", pad=10)
axes[2].set_ylabel("Time (ms)", fontsize=11)
axes[2].set_xlabel("")

mean_xapp = df["xAppMON Total (ms)"].mean()
mean_pip  = df_zbx_clean["Pipeline Total (ms)"].mean()
axes[2].text(
    0.5, -0.22, 
    f"Mean xAppMON: {mean_xapp:.1f} ms | Mean Pipeline: {mean_pip:.1f} ms", 
    transform=axes[2].transAxes, 
    ha="center", 
    fontsize=10, 
    fontweight="bold"
)

# Ajuste fino das margens para não cortar rótulos
plt.tight_layout()
plt.savefig(OUTPUT_IMAGE, dpi=300, bbox_inches="tight")

print(f"[+] Violin plots successfully updated!")
print(f"[+] Image saved at: '{OUTPUT_IMAGE}'")


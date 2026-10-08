#!/usr/bin/env python3
import json
import os
import re
import sys
from collections import defaultdict
import pandas as pd


def parse_segment_number(uri):
    """Extrai o tipo (áudio/vídeo) e o número do segmento da URI."""
    if not uri or not isinstance(uri, str):
        return None, None

    if 'audio' in uri and '.m4s' in uri:
        match = re.search(r'(\d+)\.m4s', uri)
        if match:
            return 'audio', int(match.group(1))

    elif ('sunflower' in uri or 'video' in uri) and '.m4s' in uri:
        match = re.search(r'(\d+)\.m4s', uri)
        if match:
            return 'video', int(match.group(1))

    elif '.m4s' in uri:
        match = re.search(r'(\d+)\.m4s', uri)
        if match:
            return 'outro', int(match.group(1))

    return None, None


def load_uris_from_har(filepath):
    """Lê um arquivo HAR (JSON) e retorna as URIs das requisições HTTP 200 contendo .m4s."""
    with open(filepath, 'r', encoding='utf-8') as f:
        har_data = json.load(f)

    uris = []
    entries = har_data.get('log', {}).get('entries', [])
    for entry in entries:
        status = entry.get('response', {}).get('status')
        url = entry.get('request', {}).get('url', '')
        if status == 200 and '.m4s' in url:
            uris.append(url)
    return uris


def load_uris_from_csv(filepath):
    """Lê um arquivo CSV (Wireshark/tshark) e retorna as URIs com HTTP 200 contendo .m4s."""
    df = pd.read_csv(filepath, sep=None, engine='python')
    df.columns = df.columns.str.strip()

    # Identifica coluna de URI
    uri_col = None
    for col in ['Request URI', 'URI', 'URL', 'url', 'request.uri']:
        if col in df.columns:
            uri_col = col
            break

    if not uri_col:
        for col in df.columns:
            if df[col].astype(str).str.contains(r'\.m4s').any():
                uri_col = col
                break

    if not uri_col:
        raise KeyError(f"Não foi possível encontrar a coluna de URIs no CSV. Colunas disponíveis: {df.columns.tolist()}")

    # Identifica coluna de Status/Info
    info_col = None
    for col in ['Info', 'Status', 'status', 'HTTP / Info', 'http.response.code']:
        if col in df.columns:
            info_col = col
            break

    if info_col:
        mask = df[info_col].astype(str).str.contains('200') & df[uri_col].astype(str).str.contains(r'\.m4s')
    else:
        mask = df[uri_col].astype(str).str.contains(r'\.m4s')

    return df[mask][uri_col].dropna().tolist()


def check_segments(file_path):
    if not os.path.exists(file_path):
        print(f"Erro: O arquivo '{file_path}' não foi encontrado.")
        return

    print(f"Analisando arquivo: {file_path}")

    # Processa dependendo da extensão do arquivo
    try:
        if file_path.endswith('.har'):
            uris = load_uris_from_har(file_path)
        else:
            uris = load_uris_from_csv(file_path)
    except Exception as e:
        print(f"Erro ao ler o arquivo: {e}")
        return

    segments = defaultdict(set)
    for uri in uris:
        media_type, seq_num = parse_segment_number(uri)
        if media_type and seq_num is not None:
            segments[media_type].add(seq_num)

    if not segments:
        print("Nenhum segmento .m4s válido (HTTP 200) foi localizado no log.")
        return

    # Verifica continuidade dos segmentos
    missing_segments = {}
    for media_type in sorted(segments.keys()):
        seq_nums = sorted(segments[media_type])
        if seq_nums:
            min_seq = min(seq_nums)
            max_seq = max(seq_nums)
            expected_seq = set(range(min_seq, max_seq + 1))
            missing = expected_seq - segments[media_type]
            if missing:
                missing_segments[media_type] = sorted(missing)

    # Relatório de resultados
    if missing_segments:
        print("\n⚠️ Segmentos faltantes (não apareceram em nenhuma qualidade):")
        for media_type, missing in missing_segments.items():
            for seq in missing:
                print(f"  - {media_type} segmento {seq}")
    else:
        print("\n✅ Todos os segmentos esperados apareceram sequencialmente sem falhas.")

    print("\n📊 Segmentos encontrados:")
    for media_type, seq_nums in segments.items():
        print(f"  - {media_type}: {len(seq_nums)} segmentos (do {min(seq_nums)} ao {max(seq_nums)})")


if __name__ == "__main__":
    # Permite passar o caminho do arquivo via terminal ou usa o arquivo padrão
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        input_file = "maxwell_2026-10-07T16-27-22-747Z.har"

    check_segments(input_file)

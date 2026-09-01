import pandas as pd
import re
from collections import defaultdict

def parse_segment_number(uri):
    """Extrai o número do segmento da URI, independentemente do tipo ou qualidade."""
    # Para áudio: segment_audio_128kX.m4s
    if 'audio' in uri:
        match = re.search(r'segment_audio_128k(\d+)\.m4s', uri)
        if match:
            return 'audio', int(match.group(1))
    # Para vídeo: segment_bbb_sunflower_QUALQUER_RESOLUCAO_X.m4s
    elif 'sunflower' in uri and uri.endswith('.m4s'):
        match = re.search(r'segment_bbb_sunflower_\d+x\d+_\d+\.?\d*M(\d+)\.m4s', uri)
        if match:
            return 'video', int(match.group(1))
    return None, None

def check_segments(csv_file):
    # Lê o CSV
    df = pd.read_csv(csv_file)
    
    # Filtra apenas requisições HTTP 200 OK e segmentos .m4s
    df = df[df['Info'].str.contains('200 OK') & df['Request URI'].str.contains('\.m4s')]
    
    # Dicionário para armazenar números de segmentos por tipo (áudio/vídeo)
    segments = defaultdict(set)
    
    # Processa cada URI
    for uri in df['Request URI']:
        media_type, seq_num = parse_segment_number(uri)
        if media_type and seq_num is not None:
            segments[media_type].add(seq_num)
    
    # Verifica continuidade dos segmentos
    missing_segments = {}
    for media_type in ['audio', 'video']:
        if media_type in segments:
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
        print("Segmentos faltantes (não apareceram em nenhuma qualidade):")
        for media_type, missing in missing_segments.items():
            for seq in missing:
                print(f"  - {media_type} segmento {seq}")
    else:
        print("Todos os segmentos esperados apareceram pelo menos uma vez.")
    
    # Lista os segmentos encontrados
    print("\nSegmentos encontrados:")
    for media_type, seq_nums in segments.items():
        print(f"  - {media_type}: {len(seq_nums)} segmentos (de {min(seq_nums)} a {max(seq_nums)})")

if __name__ == "__main__":
    csv_file = "172.31.0.51_64qam_1x1_3user_filtered.csv"  # Substitua pelo caminho do seu arquivo CSV
    check_segments(csv_file)

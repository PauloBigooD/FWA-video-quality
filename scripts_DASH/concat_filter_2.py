import csv
import wget
import os
import subprocess
import re
from collections import defaultdict

# Caminho do arquivo CSV
csv_file = '172.31.0.51_filtrados.csv'

all_init_files = {('640x360', '1.8M'): ['downloaded_segments/segment_bbb_sunflower_640x360_1.8Minit.mp4'], ('640x360', '2M'): ['downloaded_segments/segment_bbb_sunflower_640x360_2Minit.mp4'], ('640x360', '2.5M'): ['downloaded_segments/segment_bbb_sunflower_640x360_2.5Minit.mp4'], ('854x480', '3M'): ['downloaded_segments/segment_bbb_sunflower_854x480_3Minit.mp4'], ('854x480', '4M'): ['downloaded_segments/segment_bbb_sunflower_854x480_4Minit.mp4'], ('854x480', '5M'): ['downloaded_segments/segment_bbb_sunflower_854x480_5Minit.mp4'], ('1280x720', '6M'): ['downloaded_segments/segment_bbb_sunflower_1280x720_6Minit.mp4'], ('1280x720', '8M'): ['downloaded_segments/segment_bbb_sunflower_1280x720_8Minit.mp4'], ('1920x1080' , '10M'): ['downloaded_segments/segment_bbb_sunflower_1920x1080_10Minit.mp4'], ('1920x1080' , '12M'): ['downloaded_segments/segment_bbb_sunflower_1920x1080_12Minit.mp4'], ('3840x2160' , '14M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_14Minit.mp4'], ('3840x2160' , '16M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_16Minit.mp4'], ('3840x2160' , '18M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_18Minit.mp4']}


# Diretório para salvar os arquivos baixados e concatenados
output_dir = 'downloaded_segments'
os.makedirs(output_dir, exist_ok=True)

# Função para extrair a resolução, bitrate e número do segmento do nome do arquivo
def extract_resolution_bitrate_segment(filename):
    # Aceita arquivos .m4s e init.mp4
    if not (filename.endswith('.m4s') or filename.endswith('init.mp4')):
        return None, None, None
    # Extrai resolução, bitrate e número do segmento (ex.: 89 em ...89.m4s)
    match = re.search(r'bbb_sunflower_(\d+x\d+)_(\d+\.?\d*M?)(\d*)\.m4s|bbb_sunflower_(\d+x\d+)_(\d+\.?\d*M?)init\.mp4', filename)
    if match:
        if filename.endswith('.m4s'):
            resolution, bitrate, segment_num = match.group(1), match.group(2), match.group(3)
            return resolution, bitrate, segment_num if segment_num else None
        else:  # init.mp4
            resolution, bitrate = match.group(4), match.group(5)
            return resolution, bitrate, None
    return None, None, None

# Função para calcular a qualidade de um segmento (resolução e bitrate)
def calculate_quality(resolution, bitrate):
    # Calcula a área da resolução (ex.: 1280x720 -> 921600 pixels)
    width, height = map(int, resolution.split('x'))
    resolution_area = width * height
    # Converte bitrate para número (ex.: "2.5M" -> 2500000, "6M" -> 6000000)
    bitrate_value = float(bitrate.replace('M', '')) * 1000000
    # Retorna uma tupla para comparação (resolução tem maior peso, bitrate é desempate)
    return (resolution_area, bitrate_value)

# Abre o arquivo CSV
with open(csv_file, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)

    # Lista as colunas disponíveis
    print("Colunas disponíveis:")
    for col in reader.fieldnames:
        print(f"- {col}")

    # Armazena todos os segmentos antes da filtragem
    all_segments = []
    init_files = defaultdict(list)  # Dicionário para armazenar arquivos init por grupo
    current_resolution = None
    current_bitrate = None
    segment_group = 0

    # Usa a coluna "Info" diretamente, pois contém as URLs
    coluna_desejada = "Request URI"

    if coluna_desejada not in reader.fieldnames:
        print("Coluna 'Info' não encontrada.")
    else:
        print(f"\nProcessando valores da coluna '{coluna_desejada}':")
        for linha in reader:
            info = linha[coluna_desejada]
            
            # Filtra requisições GET de segmentos de vídeo (.m4s ou init.mp4)
            if "http://172.31.0.51/video-dash/segment_bbb_sunflower" not in info:
                continue
            if not ('.m4s' in info or 'init.mp4' in info):
                continue
              
            # Extrai a URL do segmento
            match = re.search(r'http://172.31.0.51/video-dash/([^\s]+)', info)
            if not match:
                continue
            segment_path = match.group(1)
            dash_srv_ip = "http://172.31.0.51"
            dl = f"{dash_srv_ip}/video-dash/{segment_path}"

            # Extrai resolução, bitrate e número do segmento
            resolution, bitrate, segment_num = extract_resolution_bitrate_segment(segment_path)
            if not resolution:
                print(f"Resolução não identificada para {dl}")
                continue

            # Baixa o segmento
            filename = os.path.join(output_dir, os.path.basename(segment_path))
            if (filename[-6:][0]) == "M":
                filename = re.sub(r'(\D)(\d+)(\.m4s)$', lambda m: f"{m.group(1)}{int(m.group(2)):02d}{m.group(3)}", filename)
                print (filename)
            try:
                wget.download(dl, out=filename)
                print(f"\nDownloaded video: {filename}")
            except Exception as e:
                print(f"\nErro ao baixar {dl}: {e}")
                continue

            # Verifica se o arquivo foi realmente baixado
            if not os.path.exists(filename):
                print(f"Arquivo {filename} não foi baixado corretamente.")
                continue

            # Verifica mudança de resolução ou bitrate
            if (resolution, bitrate) != (current_resolution, current_bitrate):
                if current_resolution is not None:
                    segment_group += 1
                current_resolution, current_bitrate = resolution, bitrate

            # Adiciona o segmento à lista de todos os segmentos
            key = (resolution, bitrate, segment_group)
            if 'init' in segment_path:
                init_files[key].append(filename)
            else:
                all_segments.append({
                    'filename': filename,
                    'resolution': resolution,
                    'bitrate': bitrate,
                    'segment_num': segment_num,
                    'group_key': key
                })

# Agrupa segmentos por número para filtragem de repetidos
segment_by_number = defaultdict(list)
for segment in all_segments:
    segment_by_number[segment['segment_num']].append(segment)

# Filtra segmentos repetidos, mantendo o de maior qualidade
filtered_segments = []
for segment_num, segments in sorted(segment_by_number.items(), key=lambda x: int(x[0]) if x[0] else 0):
    if len(segments) > 1:
        # Ordena por qualidade (resolução e bitrate)
        sorted_segments = sorted(
            segments,
            key=lambda s: calculate_quality(s['resolution'], s['bitrate']),
            reverse=True
        )
        # Mantém apenas o segmento de maior qualidade
        best_segment = sorted_segments[0]
        filtered_segments.append(best_segment)
        print(f"Segmento {segment_num}: Escolhido {best_segment['filename']} ({best_segment['resolution']}, {best_segment['bitrate']})")
    else:
        # Segmento não repetido, adiciona diretamente
        filtered_segments.append(segments[0])

# Reconstroi video_segments com base na ordem dos segmentos filtrados
video_segments = defaultdict(list)
current_group = None
current_resolution = None
current_bitrate = None
group_counter = 0

for segment in sorted(filtered_segments, key=lambda x: int(x['segment_num']) if x['segment_num'] else 0):
    resolution = segment['resolution']
    bitrate = segment['bitrate']
    
    # Se houver mudança de resolução ou bitrate, cria novo grupo
    if (resolution, bitrate) != (current_resolution, current_bitrate):
        group_counter += 1
        current_resolution = resolution
        current_bitrate = bitrate
        current_group = (resolution, bitrate, group_counter)
    
    video_segments[current_group].append(segment['filename'])

# Debug: Exibe video_segments
print("\nvideo_segments após filtragem e agrupamento:")
for key, segments in video_segments.items():
    print(f"Grupo {key}: {segments}")


output_videos=[]
# Concatena os segmentos de vídeo por grupo de resolução e bitrate
for (resolution, bitrate, group), segments in video_segments.items():
    if segments:
        # Cria a string no formato concat:init.mp4|segment1.m4s|segment2.m4s|...
        concat_files = []
        key = (resolution, bitrate, group)
        key2 = (resolution, bitrate)
        if key2 in all_init_files and all_init_files[key2]:
            for init_file in all_init_files[key2]:
                print (init_file)
                concat_files.append(output_dir + "/" + os.path.basename(init_file))
        for segment in sorted(segments):  # Ordena por nome para manter sequência
            concat_files.append(output_dir + "/" + os.path.basename(segment))
        
        # Verifica se há arquivos para concatenar
        if not concat_files:
            print(f"Nenhum arquivo para concatenar no grupo {resolution}_{bitrate}_group_{group}")
            continue

        # Constrói a string concat
        concat_string = "'concat:" + "|".join(concat_files) + "'"
        
        # Nome do vídeo de saída
        output_video = os.path.join(output_dir, f"{group}_output_{resolution}_{bitrate}_group.mp4")
        output_video_upscaled = os.path.join(output_dir, f"{group}_output_{resolution}_{bitrate}_group_upscaled.mp4")        
        output_videos.append(output_video_upscaled)
        
        # Comando ffmpeg para concatenar usando o protocolo concat
        cmd = 'ffmpeg' + ' ' + '-y' + ' ' + '-i' + ' ' + concat_string + ' ' + '-c' + ' ' + 'copy' + ' ' + output_video
        print (cmd)
        try:
            # Executa o comando no diretório output_dir para resolver caminhos relativos
            result = subprocess.run(cmd, shell=True)
            print(f"Generated video: {output_video}")
            cmd2 = 'ffmpeg' + ' ' + '-y' + ' ' + '-i' + ' ' + output_video + ' ' + '-vf' + ' ' + 'scale=3840:2160' + ' ' + '-c:a' + ' ' + 'copy' + ' ' + output_video_upscaled
            result2 = subprocess.run(cmd2, shell=True)
            print(f"Upscaled video to 4K: {output_video}")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao concatenar {output_video}: {e}")
            print(f"FFmpeg stderr: {e.stderr}")
            
print (output_videos)
concatenate_video_pieces = "ffmpeg -i 'concat:"
for name_video_piece in output_videos:
    print (name_video_piece)
    with open('entrada.txt', 'a') as f:
         f.write(f"file '{name_video_piece}'\n")
         
cmd3 = "ffmpeg" + " " + "-y" + " " + "-f" + " " + "concat" + " " + "-safe" + " " + "0" + " " + "-i" + " " + "entrada.txt" + " " + "-c" + " " + "copy" + " " +  "saida.mp4"
result3 = subprocess.run(cmd3, shell=True)

remove_list_video_file= subprocess.run("rm entrada.txt", shell=True)

print("\nConcatenação concluída.")

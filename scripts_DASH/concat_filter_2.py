#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import wget
from collections import defaultdict

# Arquivo de entrada (ponte para o arquivo .har ou .csv com as requisições de rede)
input_file = 'maxwell_2026-10-07T16-27-22-747Z.har'

all_init_files = {
    ('640x360', '1.8M'): ['downloaded_segments/segment_bbb_sunflower_640x360_1.8Minit.mp4'],
    ('640x360', '2M'): ['downloaded_segments/segment_bbb_sunflower_640x360_2Minit.mp4'],
    ('640x360', '2.5M'): ['downloaded_segments/segment_bbb_sunflower_640x360_2.5Minit.mp4'],
    ('854x480', '3M'): ['downloaded_segments/segment_bbb_sunflower_854x480_3Minit.mp4'],
    ('854x480', '4M'): ['downloaded_segments/segment_bbb_sunflower_854x480_4Minit.mp4'],
    ('854x480', '5M'): ['downloaded_segments/segment_bbb_sunflower_854x480_5Minit.mp4'],
    ('1280x720', '6M'): ['downloaded_segments/segment_bbb_sunflower_1280x720_6Minit.mp4'],
    ('1280x720', '8M'): ['downloaded_segments/segment_bbb_sunflower_1280x720_8Minit.mp4'],
    ('1920x1080', '10M'): ['downloaded_segments/segment_bbb_sunflower_1920x1080_10Minit.mp4'],
    ('1920x1080', '12M'): ['downloaded_segments/segment_bbb_sunflower_1280x720_12Minit.mp4'],
    ('3840x2160', '14M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_14Minit.mp4'],
    ('3840x2160', '16M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_16Minit.mp4'],
    ('3840x2160', '18M'): ['downloaded_segments/segment_bbb_sunflower_3840x2160_18Minit.mp4']
}

output_dir = 'downloaded_segments'
os.makedirs(output_dir, exist_ok=True)

if os.path.exists('entrada.txt'):
    os.remove('entrada.txt')


def extract_resolution_bitrate_segment(filename):
    if not (filename.endswith('.m4s') or filename.endswith('init.mp4')):
        return None, None, None
    match = re.search(r'bbb_sunflower_(\d+x\d+)_(\d+\.?\d*M?)(\d*)\.m4s|bbb_sunflower_(\d+x\d+)_(\d+\.?\d*M?)init\.mp4', filename)
    if match:
        if filename.endswith('.m4s'):
            resolution, bitrate, segment_num = match.group(1), match.group(2), match.group(3)
            return resolution, bitrate, segment_num if segment_num else None
        else:
            resolution, bitrate = match.group(4), match.group(5)
            return resolution, bitrate, None
    return None, None, None


def calculate_quality(resolution, bitrate):
    width, height = map(int, resolution.split('x'))
    resolution_area = width * height
    bitrate_value = float(bitrate.replace('M', '')) * 1000000
    return (resolution_area, bitrate_value)


def get_urls_from_file(file_path):
    urls = []
    if file_path.endswith('.har'):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            entries = data.get('log', {}).get('entries', [])
            for entry in entries:
                url = entry.get('request', {}).get('url', '')
                if 'segment_bbb_sunflower' in url and ('.m4s' in url or 'init.mp4' in url):
                    urls.append(url)
    else:
        import csv
        with open(file_path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            col = 'Request URI' if 'Request URI' in reader.fieldnames else None
            if not col:
                for c in reader.fieldnames:
                    if 'uri' in c.lower() or 'url' in c.lower() or 'info' in c.lower():
                        col = c
                        break
            if col:
                for row in reader:
                    val = row[col]
                    if 'segment_bbb_sunflower' in val and ('.m4s' in val or 'init.mp4' in val):
                        urls.append(val)
    return urls


# Carrega URLs
if len(sys.argv) > 1:
    input_file = sys.argv[1]

if not os.path.exists(input_file):
    print(f"Erro: Arquivo '{input_file}' não encontrado.")
    sys.exit(1)

print(f"Extraindo requisições de: {input_file}")
segment_urls = get_urls_from_file(input_file)

all_segments = []
init_files = defaultdict(list)
current_resolution = None
current_bitrate = None
segment_group = 0

for dl in segment_urls:
    match = re.search(r'segment_bbb_sunflower_[^\s]+', dl)
    if not match:
        continue
    segment_path = match.group(0)

    resolution, bitrate, segment_num = extract_resolution_bitrate_segment(segment_path)
    if not resolution:
        continue

    filename = os.path.join(output_dir, os.path.basename(segment_path))
    if filename[-6:][0] == "M":
        filename = re.sub(r'(\D)(\d+)(\.m4s)$', lambda m: f"{m.group(1)}{int(m.group(2)):02d}{m.group(3)}", filename)

    if not os.path.exists(filename):
        try:
            wget.download(dl, out=filename)
            print(f"\nBaixado: {filename}")
        except Exception as e:
            print(f"\nErro ao baixar {dl}: {e}")
            continue

    if (resolution, bitrate) != (current_resolution, current_bitrate):
        if current_resolution is not None:
            segment_group += 1
        current_resolution, current_bitrate = resolution, bitrate

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

# Agrupa e filtra por qualidade
segment_by_number = defaultdict(list)
for segment in all_segments:
    segment_by_number[segment['segment_num']].append(segment)

filtered_segments = []
for segment_num, segments in sorted(segment_by_number.items(), key=lambda x: int(x[0]) if x[0] else 0):
    if len(segments) > 1:
        sorted_segments = sorted(
            segments,
            key=lambda s: calculate_quality(s['resolution'], s['bitrate']),
            reverse=True
        )
        best_segment = sorted_segments[0]
        filtered_segments.append(best_segment)
    else:
        filtered_segments.append(segments[0])

video_segments = defaultdict(list)
current_group = None
current_resolution = None
current_bitrate = None
group_counter = 0

for segment in sorted(filtered_segments, key=lambda x: int(x['segment_num']) if x['segment_num'] else 0):
    resolution = segment['resolution']
    bitrate = segment['bitrate']

    if (resolution, bitrate) != (current_resolution, current_bitrate):
        group_counter += 1
        current_resolution = resolution
        current_bitrate = bitrate
        current_group = (resolution, bitrate, group_counter)

    video_segments[current_group].append(segment['filename'])

output_videos = []
for (resolution, bitrate, group), segments in video_segments.items():
    if segments:
        concat_files = []
        key2 = (resolution, bitrate)
        if key2 in all_init_files and all_init_files[key2]:
            for init_file in all_init_files[key2]:
                concat_files.append(init_file)
        for segment in sorted(segments):
            concat_files.append(segment)

        concat_string = "concat:" + "|".join(concat_files)
        output_video = os.path.join(output_dir, f"{group}_output_{resolution}_{bitrate}_group.mp4")
        output_video_upscaled = os.path.join(output_dir, f"{group}_output_{resolution}_{bitrate}_group_upscaled.mp4")
        output_videos.append(output_video_upscaled)

        cmd = f'ffmpeg -y -i "{concat_string}" -c copy "{output_video}"'
        print(f"\nExecutando: {cmd}")
        subprocess.run(cmd, shell=True)

        cmd2 = f'ffmpeg -y -i "{output_video}" -vf scale=3840:2160 -c:a copy "{output_video_upscaled}"'
        subprocess.run(cmd2, shell=True)

if output_videos:
    with open('entrada.txt', 'w', encoding='utf-8') as f:
        for name_video_piece in output_videos:
            f.write(f"file '{name_video_piece}'\n")

    cmd3 = "ffmpeg -y -f concat -safe 0 -i entrada.txt -c copy saida.mp4"
    subprocess.run(cmd3, shell=True)

    if os.path.exists('entrada.txt'):
        os.remove('entrada.txt')

    print("\n✅ Concatenação e upscale para 4K concluídos com sucesso! Arquivo gerado: saida.mp4")
else:
    print("\n⚠️ Nenhum segmento foi processado.")

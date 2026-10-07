#!/bin/bash

# Arquivo de entrada
input_file="./video/bbb_sunflower_2160p_60fps_normal.mp4"

# Diretório de saída
output_dir="./video-dash"

# Verifica se o arquivo de entrada existe
if [ ! -f "$input_file" ]; then
    echo "Erro: O arquivo $input_file não foi encontrado."
    exit 1
fi

# Criar o diretório de saída se não existir
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

# Taxas de bits desejadas para cada resolução
bitrates_4k=(18 16 14)
bitrates_fhd=(12 10)
bitrates_hd=(8 6)
bitrates_sd=(5 4 3)
bitrates_low=(2.5 2 1.8)

# Resoluções desejadas
resolutions=("3840x2160" "1920x1080" "1280x720" "854x480" "640x360")

# Determinar a duração exata do vídeo (em segundos)
duration=$(ffprobe -i "$input_file" -show_entries format=duration -v quiet -of csv="p=0" | cut -d'.' -f1)
echo "Duração do vídeo: $duration segundos"

# 1. Codificar o áudio em AAC com a mesma duração do vídeo
audio_file="${output_dir}/audio_128k.m4a"
if [ ! -f "$audio_file" ]; then
    echo "Codificando áudio..."
    ffmpeg -i "$input_file" -map 0:a -c:a aac -b:a 128k -vn -t "$duration" "$audio_file"
    if [ $? -eq 0 ]; then
        echo "Áudio codificado: $audio_file"
    else
        echo "Falha ao codificar o áudio!"
        exit 1
    fi
fi

# 2. Codificar o vídeo em múltiplas resoluções e taxas de bits
for resolution in "${resolutions[@]}"; do
    if [ "$resolution" == "3840x2160" ]; then
        bitrates=("${bitrates_4k[@]}")
    elif [ "$resolution" == "1920x1080" ]; then
        bitrates=("${bitrates_fhd[@]}")
    elif [ "$resolution" == "1280x720" ]; then
        bitrates=("${bitrates_hd[@]}")
    elif [ "$resolution" == "854x480" ]; then
        bitrates=("${bitrates_sd[@]}")
    else
        bitrates=("${bitrates_low[@]}")
    fi

    for bitrate in "${bitrates[@]}"; do
        output_file="${output_dir}/bbb_sunflower_${resolution}_${bitrate}M.mp4"
        echo "Codificando vídeo em ${resolution} a ${bitrate}Mbps -> $output_file"
        
        ffmpeg -i "$input_file" \
            -vf "scale=${resolution}" \
            -c:v libx264 \
            -b:v "${bitrate}M" \
            -maxrate "${bitrate}M" \
            -bufsize "$(echo "$bitrate * 2" | bc)M" \
            -g 120 \
            -keyint_min 120 \
            -sc_threshold 0 \
            -preset fast \
            -an \
            -t "$duration" \
            -f mp4 "$output_file"
        
        if [ $? -ne 0 ]; then
            echo "Erro ao codificar $output_file"
            exit 1
        fi
    done
done

# 3. Preparar lista de inputs para o MP4Box
dash_inputs=()
for resolution in "${resolutions[@]}"; do
    if [ "$resolution" == "3840x2160" ]; then
        bitrates=("${bitrates_4k[@]}")
    elif [ "$resolution" == "1920x1080" ]; then
        bitrates=("${bitrates_fhd[@]}")
    elif [ "$resolution" == "1280x720" ]; then
        bitrates=("${bitrates_hd[@]}")
    elif [ "$resolution" == "854x480" ]; then
        bitrates=("${bitrates_sd[@]}")
    else
        bitrates=("${bitrates_low[@]}")
    fi
    
    for bitrate in "${bitrates[@]}"; do
        dash_inputs+=("${output_dir}/bbb_sunflower_${resolution}_${bitrate}M.mp4")
    done
done

dash_inputs+=("$audio_file")

# 4. Gerar manifesto DASH com ajustes
echo "Gerando manifesto DASH..."
MP4Box -dash 2000 -frag 2000 \
    -profile dashavc264:live \
    -segment-name "segment_%s" \
    -out "${output_dir}/manifest.mpd" \
    "${dash_inputs[@]}"

# Verificação final
if [ -f "${output_dir}/manifest.mpd" ]; then
    echo "Concluído! Manifesto DASH gerado em:"
    echo "   ${output_dir}/manifest.mpd"
    echo "Estrutura de arquivos:"
    ls -lh "$output_dir"
else
    echo "Falha ao gerar o manifesto DASH!"
    exit 1
fi

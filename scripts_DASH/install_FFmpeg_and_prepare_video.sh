#!/bin/bash

set -e

echo "=========================================================="
echo " Iniciar instalação de dependências e preparação de vídeo "
echo "=========================================================="

# 1. Atualizar repositórios e instalar pacotes essenciais
echo "--> Atualizando lista de pacotes..."
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    sed \
    python3 \
    python3-pip \
    wget \
    gpac \
    tar \
    xz-utils

# 2. Instalar Docker
if ! command -v docker &> /dev/null; then
    echo "--> Instalando Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado com sucesso."
else
    echo "✅ Docker já está instalado."
fi

# 3. Instalar FFmpeg com suporte nativo ao VMAF (Static Build)
echo "--> Configurando FFmpeg com suporte ao VMAF..."
if ffmpeg -filters 2>&1 | grep -q "libvmaf"; then
    echo "✅ O FFmpeg atual já possui suporte ao libvmaf."
else
    echo "--> Baixando binário do FFmpeg compilado com libvmaf..."
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download do build estático com libvmaf incorporado
    wget -q --show-progress https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
    tar -xf ffmpeg-release-amd64-static.tar.xz
    
    cd ffmpeg-*-amd64-static
    sudo cp ffmpeg ffprobe /usr/local/bin/
    sudo chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe
    
    cd ~
    rm -rf "$TMP_DIR"
    echo "✅ FFmpeg com suporte ao VMAF instalado em /usr/local/bin/ffmpeg."
fi

# 4. Instalar pacotes Python
echo "--> Instalando dependências Python..."
pip3 install --upgrade pip
pip3 install pandas requests

# 5. Criar diretórios de estrutura
echo "--> Criando diretórios de trabalho..."
mkdir -p video video-dash segments_csv downloaded_segments

# 6. Download do vídeo de referência (4K)
VIDEO_PATH="video/bbb_sunflower_2160p_60fps_normal.mp4"
if [ ! -f "$VIDEO_PATH" ]; then
    echo "--> Baixando vídeo de referência Big Buck Bunny 4K..."
    wget -O "$VIDEO_PATH" https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd || true
    
    # Se o link direto falhar, usa o fallback do mirror
    if [ ! -s "$VIDEO_PATH" ]; then
        echo "--> Baixando via repositório de mídia..."
        wget -O "$VIDEO_PATH" "https://upload.wikimedia.org/wikipedia/commons/2/22/Big_Buck_Bunny_Teaser_400p_for_HTML5_h264.mp4"
    fi
    echo "✅ Vídeo baixado em $VIDEO_PATH."
else
    echo "✅ Vídeo de referência já existe em $VIDEO_PATH."
fi

# 7. Criar link simbólico do vídeo 4k.mp4
if [ ! -L "4k.mp4" ] && [ ! -f "4k.mp4" ]; then
    ln -sf video/bbb_sunflower_2160p_60fps_normal.mp4 4k.mp4
    echo "✅ Link simbólico 4k.mp4 criado."
fi

echo "=========================================================="
echo " Ambientes e dependências configurados com sucesso! "
echo "=========================================================="
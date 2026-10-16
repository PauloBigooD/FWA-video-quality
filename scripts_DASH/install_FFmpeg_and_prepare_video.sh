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

# 4. Instalar pacotes Python (incluindo gdown para o Google Drive)
echo "--> Instalando dependências Python..."
pip3 install --upgrade pip
pip3 install pandas requests gdown

# 5. Criar diretórios de trabalho
echo "--> Criando diretórios de trabalho..."
mkdir -p video video-dash segments_csv downloaded_segments plot_results

# 6. Download do vídeo de referência 4K a partir do Google Drive
VIDEO_PATH="video/bbb_sunflower_2160p_60fps_normal.mp4"
GDRIVE_ID="1X9iPbrGkkO1EwN1hVC9Hgii6uENZUkCQ"

if [ ! -f "$VIDEO_PATH" ] || [ ! -s "$VIDEO_PATH" ]; then
    echo "--> Baixando vídeo de referência do Google Drive (ID: $GDRIVE_ID)..."
    gdown "https://drive.google.com/uc?id=${GDRIVE_ID}" -O "$VIDEO_PATH"
    echo "✅ Vídeo baixado em $VIDEO_PATH."
else
    echo "✅ Vídeo de referência já existe e não está vazio em $VIDEO_PATH."
fi

# 7. Criar link simbólico do vídeo de referência para 4k.mp4
if [ ! -L "4k.mp4" ] && [ ! -f "4k.mp4" ]; then
    ln -sf "$VIDEO_PATH" 4k.mp4
    echo "✅ Link simbólico 4k.mp4 criado."
fi

echo "=========================================================="
echo " Ambientes e dependências configurados com sucesso! "
echo "=========================================================="
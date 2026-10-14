# Processamento, Reconstrução e Avaliação de Vídeo MPEG-DASH

Este repositório contém o conjunto de ferramentas e scripts em Bash e Python para automatizar o pipeline de testes com vídeo MPEG-DASH. O fluxo contempla desde a preparação do ambiente e codificação DASH até a reconstrução de vídeos a partir de capturas HAR e o cálculo de métricas de qualidade quadro a quadro (**PSNR** e **SSIM**).

---

## 🏗️ Visão Geral do Fluxo

```
[ Vídeo Bruto (4K) ]
         │
         ▼ (1. generate_dash_manifest.sh)
[ Servidor MPEG-DASH ] ───(Transmissão/Navegador)───► [ Arquivo .har ]
                                                             │
                                                             ▼ (2. get_segments.py)
                                                     [ Extração CSV URIs ]
                                                             │
                                                             ▼ (3. concat_filter_2.py)
                                                     [ Download + Upscaling 4K ]
                                                             │
                                                             ▼
                                                    [ Vídeo Reconstruído ]
                                                             │
                                                             ▼ (4. get_metrics_origin.py)
                                                     [ Relatórios PSNR e SSIM ]
```

---

## 🛠️ Scripts do Repositório

### 1. `install_docker_and_prepare_video.sh`
Prepara o ambiente do sistema operacional (Ubuntu/Debian) instalando pacotes fundamentais.

* **Ações:**
  * Configura o repositório oficial e instala o **Docker**.
  * Cria as pastas padrão `video/` e `video-dash/`.
  * Baixa o vídeo de referência em 4K (**Big Buck Bunny** - 2160p 60fps).
  * Instala `ffmpeg` (processamento de vídeo), `gpac`/`MP4Box` (manipulação DASH) e `jq` (leitura de JSON/HAR).
* **Uso:**
  ```bash
  cd scripts_DASH
  sudo ./install_docker_and_prepare_video.sh
  ```

---

### 2. `generate_dash_manifest.sh`
Codifica o vídeo de referência em múltiplas representações de taxa de bits (bitrates) e gera o manifesto DASH (`manifest.mpd`).

* **Ações:**
  * Converte a faixa de áudio em AAC (128 kbps).
  * Gera representações de vídeo em taxas de bits configuráveis (ex: 18M até 1.8M).
  * Fragmenta o vídeo em segmentos `.m4s` e gera o manifesto com o `MP4Box`.
* **Uso:**
  ```bash
  ./generate_dash_manifest.sh
  ```
* ⚠️ **Campos para Ajustar no Script:**
  * `input_file`: Caminho do vídeo original de entrada (padrão: `video/bbb_sunflower_2160p_60fps_normal.mp4`).
  * `output_dir`: Pasta de destino dos segmentos DASH (padrão: `video-dash`).
  * `bitrates`: Lista de bitrates para codificação (ex: `("18M" "16M" "14M" ...)`).
* **Iniciar Servidor Dash:**
  ```bash
  docker compose up -d
  ```
---

### 3. Iniciar captura do vídeo DASH
Automação para execução e captura de métricas do vídeo DASH gerando um arquivo `.har` e outro `.csv` contendo as métricas de interesse.

* **Ações:**
  * Inicializa o navegador Google Chrome em modo oculto.
  * Inicia o player do vídeo.
  * Realiza a coleta e construção dos arquivos `.har` e `.csv`.
  * As ações são realizadas em segundo plano com logs em tela.

* **Iniciar npm:**
  ```bash
  cd ../npm_fwa
  npm install
  xvfb-run npm start
  ```
---

### 4. `get_segments.py`
Script orquestrador das capturas de rede. Lê arquivos `.har` gerados durante as sessões de streaming no navegador, extrai as requisições dos segmentos e invoca a reconstrução.

* **Ações:**
  * Converte cada `.har` da pasta de logs em um arquivo `.csv` na pasta `segments_csv/`.
  * Chama o `concat_filter_2.py` para processar cada experimento.
  * Renomeia o vídeo final gerado para `saida_<nome_do_experimento>.mp4`.
* **Uso:**
  ```bash
  ./get_segments.py
  ```
* ⚠️ **Campos para Ajustar no Script:**
  * `diretorio`: Caminho onde estão salvos os logs `.har` do navegador (ex: `"/home/usuario/har_logs"`).
  * `comando_jq`: Filtro de IP/URL do servidor MPEG-DASH nas requisições.
    ```python
    # Altere o IP e a porta para o endereço do seu servidor
    "http://172.31.0.54:8080/video-dash/segment_bbb_sunflower"
    ```

---

### 5. `concat_filter_2.py`
Processa as URIs do experimento, baixa os segmentos e realiza a montagem do vídeo degradado final.

* **Ações:**
  * Baixa os arquivos de inicialização (`init`) e os segmentos `.m4s` recebidos.
  * Agrupa segmentos sequenciais de mesma resolução/qualidade.
  * Aplica filtro de **upscaling** via FFmpeg para equalizar todos os blocos na resolução de referência ($3840 \times 2160$).
  * Concatena todos os blocos convertidos em um único arquivo de saída `saida.mp4`.
* **Uso:**
  Invocado automaticamente pelo `get_segments.py` ou manualmente via:
  ```bash
  ./concat_filter_2.py segments_csv/<experimento>.csv
  ```

---

### 6. `get_metrics.py`
Calcula as métricas de qualidade de vídeo comparando o vídeo reconstruído de cada experimento com o vídeo original de referência.

* **Ações:**
  * Executa os filtros de avaliação `psnr` e `ssim` do FFmpeg em paralelo quadro a quadro.
  * Gera os arquivos `psnr_<experimento>.csv` e `ssim_<experimento>.csv` na pasta `segments_csv/`.
  * Cada relatório contém $N$ linhas correspondentes ao total de quadros do vídeo ($\text{Duração} \times \text{FPS}$, ex: $180\text{s} \times 60\text{fps} = 10.800\text{ linhas}$).
* **Uso:**
  ```bash
  ./get_metrics.py
  ```
* ⚠️ **Campos para Ajustar no Script:**
  * `video_referencia`: Caminho para o vídeo de referência em alta qualidade (padrão: `video/bbb_sunflower_2160p_60fps_normal.mp4`).
  * `diretorio_csvs`: Diretório onde estão os relatórios e saídas (padrão: `segments_csv`).

---

### 7. `verify_segments.py` (Utilitário)
Verifica se existem falhas ou lacunas de segmentos na sequência do `.csv` capturado e realiza o preenchimento automático copiando a qualidade vizinha para manter a continuidade temporal do vídeo.

* **Uso:**
  ```bash
  ./verify_segments.py
  ```

---

## 📋 Passo a Passo de Execução (Workflow Completo)

1. **Preparar o Ambiente e Obter o Vídeo Bruto:**
   ```bash
   sudo ./install_docker_and_prepare_video.sh
   ```

2. **Gerar os Segmentos e Manifesto DASH:**
   ```bash
   ./generate_dash_manifest.sh
   ```
   `⚠️ O procedimento de gerar os segmentos DASH pode ser um pouco demorado ~ 30 min`

3. **Iniciar o servidor DASH**
   ```bash
   docker compose up -d
   ```

4. **Realizar o Experimento de Streaming:**
   ```bash
   cd ../npm_fwa
   npm install
   xvfb-run npm start
   ```
   `⚠️ Confira os arquivos de log gerados em /home/username/har_logs .csv e .har`

5. **Reconstruir os Vídeos dos Experimentos:**
   ```bash
   ./get_segments.py
   ```
   *Isto gerará os vídeos `saida_<nome_do_experimento>.mp4`.*

6. **Calcular Métricas de Qualidade (PSNR, SSIM, VMAF e Quality):**
   ```bash
   ./get_metrics.py
   ./get_quality_log.py
   ```
   *Isto gerará os arquivos de métricas `psnr_<experimento>.csv`, `ssim_<experimento>.csv`, `vmaf_<experimento>.csv` e  `quality_<experimento>.csv`  em `segments_csv/`.*

---

## 💡 Observações Importantes

* **Espaço em Disco:** Certifique-se de possuir pelo menos 15-20 GB livres para armazenar os segmentos baixados, vídeos intermediários e os arquivos de saída em 4K.
* **Compatibilidade de FPS/Resolução:** Certifique-se de que o vídeo reconstruído e o vídeo de referência possuem exatamente o mesmo número de quadros e taxa de FPS para evitar divergências nos cálculos de PSNR/SSIM.
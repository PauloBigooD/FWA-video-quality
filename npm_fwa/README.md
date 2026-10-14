# fwa — Experimento DASH (QUIC/HTTP3) + Monitoramento WiFi

Conjunto de scripts que roda em **notebooks clientes** para coletar métricas de um
experimento de streaming DASH sobre QUIC/HTTP3, em conjunto com o monitoramento de
throughput/latência da interface WiFi durante o teste.

## Arquitetura

```
┌───────────────────────────── Notebook cliente (nb4, nb5, ...) ─────────────────────────────┐
│                                                                                             │
│  crontab (nb4.crontab)                                                                      │
│       │ agenda as rodadas (fase 5_clientes)                                                 │
│       ▼                                                                                     │
│  run-phase.sh ──▶ wifi-monitor.py ──▶ POST métricas ──────────────┐                        │
│       │            (throughput WiFi, RTT, jitter)                 │                        │
│       │                                                           ▼                        │
│       ▼                                                    wifi-collector                                               │
│  index.js (npm start) ──▶ Chrome/Puppeteer ──▶ HAR + CSV ──▶ http://192.168.110.41:9999/upload │
│       │            abre o player DASH via QUIC/HTTP3                                       │
│       │                                                                                    │
│  wifi-route.sh (@reboot): conecta no SSID "video" + rota estática                          │
└─────────────────────────────────────────────────────────────────────────────────────────────┘

                                │  WiFi (SSID "video")
                                ▼
                  Servidor DASH: https://172.31.0.220
```

- **Servidor DASH** (`172.31.0.220`): entrega o stream de vídeo. `https` é obrigatório
  para negociar QUIC/HTTP3 (em `http` o Chrome cai em HTTP/1.1).
- **Servidor coletor** (`192.168.110.41`): recebe os HARs/CSVs do player (porta `9999/upload`)
  e as métricas de rede (porta `8888/metrics`).
- **Notebooks clientes**: cada um roda os scripts via cron, com um `CLIENT_ID` próprio
  (ex.: `nb4`, `nb5`).

## Os scripts

### `wifi-route.sh`
> Conexão WiFi + rota estática. Deve rodar no `@reboot` de cada notebook.

- Detecta automaticamente a interface WiFi (checa `/sys/class/net/<iface>/wireless`,
  `/phy80211`, `iw dev`, com fallback para interfaces `wl*`).
- Conecta no SSID **`video`** (senha padrão `fwa12345` — configurável via env vars
  `WIFI_SSID`/`WIFI_PASS`).
- É **idempotente**: se já estiver conectado no SSID certo, pula a conexão.
- Adiciona uma **rota estática** para o servidor DASH (`172.31.0.220`) via o gateway do
  WiFi — assim o tráfego do experimento sempre sai pelo WiFi, independente da rede cabeada.
- Ao final, testa a conectividade com o servidor via `curl` e mostra o status.

Uso:
```bash
bash wifi-route.sh            # conecta + adiciona rota + teste
bash wifi-route.sh --status   # mostra estado atual (WiFi + rota)
bash wifi-route.sh --cron     # imprime a linha @reboot para o crontab
```

> ⚠️ Requer `sudo` sem senha (NOPASSWD) para `nmcli`, `ip` e `rfkill` — em cron não há TTY
> para digitar senha. O script avisa se o sudo estiver pedindo senha.

### `run-phase.sh`
> **Orquestrador de uma fase do experimento** (versão canônica — é ele que o cron chama).

Fluxo de uma execução:

1. **Limpa** monitores antigos (`pkill -f wifi-monitor.py`).
2. **Inicia** o `wifi-monitor.py` em background, passando a fase explicitamente
   (`--phase "$PHASE"` — o cron sabe a fase de cada linha).
3. **Executa o experimento DASH** (`npm start` → `index.js`), com `HEADLESS=true` por padrão.
4. **Mata** o monitor ao final da coleta.

Variáveis esperadas (via env, normalmente definidas no crontab):

| Variável    | Padrão                  | Descrição                                    |
|-------------|-------------------------|----------------------------------------------|
| `CLIENT_ID` | `hostname`              | Identificação do cliente (ex.: `nb4`)        |
| `PHASE`     | `?`                     | Fase: `1_cliente` \| `3_clientes` \| `5_clientes` |
| `DASH_URL`  | `https://172.31.0.220`  | URL do servidor DASH (https p/ QUIC/HTTP3)   |
| `FORCE_QUIC`| `false`                 | ⚠️ Temporariamente `false`: UDP 443 bloqueado no WiFi → fallback h2. Voltar para `true` quando o QUIC responder |
| `PING_TARGET` | `172.31.0.220`        | Alvo do ping para RTT/jitter                 |
| `METRICS_URL`| `http://192.168.110.41:8888/metrics` | Endpoint do wifi-collector |

Uso manual:
```bash
PHASE=5_clientes bash run-phase.sh
```

Logs: `/tmp/run-phase-<CLIENT_ID>.log`, `/tmp/wifi-monitor-<CLIENT_ID>.log`, `/tmp/dash-<CLIENT_ID>.log`.

### `wifi-monitor.py`
> Monitor de throughput WiFi + latência (Python 3). Roda em background durante o experimento.

- Detecta a interface WiFi e lê os contadores de bytes de
  `/sys/class/net/<iface>/statistics/{rx_bytes,tx_bytes}`.
- A cada ~1s calcula **throughput** (`wifi_rx_bps` / `wifi_tx_bps`) pela diferença de bytes.
- A cada ~2 ciclos faz **ping** no alvo (`--ping-target`) e reporta **RTT** e **jitter**
  (diferença absoluta entre RTTs consecutivos).
- Envia as métricas em **formato linha** (estilo InfluxDB) via POST para o coletor:
  ```
  wifi_rx_bps,client=nb4,phase=5_clientes value=12345678
  wifi_rtt_ms,client=nb4,phase=5_clientes value=12.34
  wifi_jitter_ms,client=nb4,phase=5_clientes value=0.5
  ```
- Falhas de envio são silenciosas — o monitor nunca derruba o experimento.

Argumentos:

| Argumento      | Descrição                                                              |
|----------------|------------------------------------------------------------------------|
| `--id`         | Client ID (ex.: `nb1`)                                                 |
| `--phase`      | Fase manual (ex.: `5_clientes`). **Caminho correto** — o cron sabe a fase |
| `--auto-phase` | Fallback: detecta a fase pelo minuto local (grade 0/4/8 min em blocos de 12 min: `0`→`1_cliente`, `4`→`3_clientes`, `8`→`5_clientes`) |
| `--ping-target`| IP do alvo para medir latência                                         |
| `--server`     | Endpoint do coletor (padrão `http://192.168.110.41:8888/metrics`)      |
| `--interval`   | Intervalo de coleta em segundos (padrão `1.0`)                         |

Uso direto:
```bash
python3 wifi-monitor.py --id nb1 --phase 5_clientes --ping-target 172.31.0.220
```

### `index.js`
> **Coletor DASH** (Node.js + Puppeteer). É o `npm start` do projeto.

Fluxo da coleta:

1. Abre o Chrome (`/usr/bin/google-chrome-stable`) com flags para:
   - aceitar o **certificado autoassinado** do servidor (`--ignore-certificate-errors`,
     `--ignore-certificate-errors-spki-list=...`);
   - **habilitar QUIC** (`--enable-quic`) e, se `FORCE_QUIC=true`, **forçar** QUIC para
     `172.31.0.220:443` via `--origin-to-force-quic-on` (falha se UDP 443 estiver bloqueado —
     por isso hoje o padrão é `false`);
   - **desabilitar cache** (`--disable-cache`, `--disk-cache-size=0`, `setCacheEnabled(false)`)
     para que cada execução meça a rede real (5G).
2. Inicia a captura **HAR** (`puppeteer-har`) antes do `page.goto`, com **3 tentativas**
   (retry a cada 5s) para sobreviver a flaps transitórios de rede.
3. Lê os **protocolos negociados** via `performance.getEntries()[].nextHopProtocol`
   (`h3` = QUIC/HTTP3, `h2` = HTTP/2, `http/1.1` = fallback TCP).
4. Clica no botão do algoritmo ABR **BOLA** (`#btn-bola`), aguarda o `<video>`, silencia
   e inicia o playback (autoplay habilitado via flag do Chrome).
5. Coleta métricas do player **a cada 2s** a partir dos elementos `m-*` da página:
   `timestamp,time_s,bitrate,buffer_s,switches,stalls,stall_duration,resolution,throughput,abr_algo`
   → salvas em CSV.
6. Aguarda o fim do playback (console log `Playback finalizado`) **ou** um timeout máximo
   (o maior entre 240s e 1,3× `DURATION_SEC` — o que terminar primeiro encerra a captura).
7. Salva HAR + CSV em `~/har_logs/<CLIENT_ID>_<timestamp>.har` (e `_metrics.csv`).
8. Faz **upload** dos dois arquivos (form-data via `curl`) para o coletor
   `http://192.168.110.41:9999/upload` — se falhar, os arquivos ficam salvos localmente.

Variáveis (env):

| Variável        | Padrão                          | Descrição                                  |
|-----------------|---------------------------------|--------------------------------------------|
| `DASH_URL`      | `https://172.31.0.220`          | URL do servidor DASH                       |
| `FORCE_QUIC`    | `true`                          | `true` força QUIC; `false` usa Alt-Svc (fallback TCP possível) |
| `DURATION_SEC`  | `180`                           | Duração máxima da coleta (s)               |
| `CLIENT_ID`     | `hostname`                      | Identificação do cliente                   |
| `COLLECTOR_URL` | `http://192.168.110.41:9999/upload` | Endpoint de upload do HAR/CSV          |
| `HEADLESS`      | `false`                         | `true` roda o Chrome sem interface (cron)  |

> 💡 A duração real da captura é controlada pelo fim do playback ou pelo timeout máximo,
> não diretamente por `DURATION_SEC`.

### `index.js.bkp`
> **Backup** da versão anterior do `index.js`.

Diferenças para a versão atual:
- `page.goto` **sem retry** (uma falha transitória derrubava a fase inteira);
- timeout máximo usa `setTimeout` **sem `clearTimeout`** — um timer fantasma podia segurar
  o processo além do necessário.

Mantido apenas para referência histórica; não é usado por nenhum script.

### `run_dash.sh`
> Wrapper simples do `index.js` (versão antiga, antes do `run-phase.sh`).

Apenas define as env vars com defaults (`DASH_URL`, `DURATION_SEC`, `CLIENT_ID`,
`COLLECTOR_URL`, `HEADLESS`) e executa `npm start`, registrando início/fim em
`~/har_logs/cron.log`. **Não** sobe o `wifi-monitor.py` — quem faz a orquestração completa
(monitor + DASH) é o `run-phase.sh`.

Uso:
```bash
DASH_URL=https://172.31.0.220 DURATION_SEC=180 CLIENT_ID=nb1 bash run_dash.sh
```

### `nb4.crontab`
> Crontab do notebook **nb4** (o mesmo arquivo serve para o nb5, trocando `CLIENT_ID`).

- Define as env vars para todas as linhas: `DISPLAY=:1`, `XAUTHORITY`, `HEADLESS=true`,
  `CLIENT_ID=nb4`, `DASH_URL=https://172.31.0.220`.
- Agenda **5 rodadas da fase `5_clientes`** a cada 12 minutos, das **23:08 às 23:56**
  (08/20/32/44/56 — cada execução cabe no bloco de 12 min antes da próxima):
  ```
  08 23 * * * PHASE=5_clientes bash ~/fwa/run-phase.sh >> /tmp/fwa_nb4.log 2>&1
  20 23 * * * PHASE=5_clientes bash ~/fwa/run-phase.sh >> /tmp/fwa_nb4.log 2>&1
  ... (32, 44, 56)
  ```
- Inclui uma linha comentada de **teste isolado** da fase `1_cliente` (23:23) para
  quando quiser rodar um cliente sozinho.

Aplicar com:
```bash
crontab ~/fwa/nb4.crontab
```

> ⚠️ Antes de aplicar: ajustar `XAUTHORITY=/home/lance/.Xauthority` para o usuário do
> notebook e trocar `CLIENT_ID` se for o nb5.

### `package.json`
> Dependências Node do coletor DASH.

- `puppeteer` — controle do Chrome (abre o player, clica, lê métricas da página);
- `puppeteer-har` — captura do tráfego em formato HAR;
- `mkdirp` — criação do diretório `~/har_logs`.

Instalar com `npm install` e executar com `npm start` (= `node index.js`).

## Fluxo completo de uma rodada (via cron)

```
23:08  cron dispara: PHASE=5_clientes bash run-phase.sh
         │
         ├─ pkill monitor antigo
         ├─ wifi-monitor.py --id nb4 --phase 5_clientes ... &   (background)
         ├─ npm start (index.js)
         │    ├─ Chrome abre https://172.31.0.220 (QUIC/h2)
         │    ├─ clica em BOLA, toca o vídeo, coleta métricas a cada 2s
         │    ├─ salva ~/har_logs/nb4_<ts>.har + _metrics.csv
         │    └─ upload para 192.168.110.41:9999/upload
         └─ kill wifi-monitor.py
```

O WiFi deve estar conectado antes (`wifi-route.sh` no `@reboot` de cada notebook).

## Estado atual / pendências

- **QUIC desabilitado temporariamente** (`FORCE_QUIC=false` no `run-phase.sh`): o UDP 443
  está bloqueado no caminho WiFi, então as coletas estão caindo em HTTP/2 (h2). Quando o
  probe UDP voltar a responder, trocar o default para `true`.
- O `run_dash.sh` é legado — o caminho oficial das rodadas agendadas é o `run-phase.sh`.
